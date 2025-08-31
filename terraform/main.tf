provider "aws" {
  region = var.aws_region
}

# ------------------------------------------------------------------
# Cognito User Pool e Cliente
# ------------------------------------------------------------------
resource "aws_cognito_user_pool" "user_pool" {
  name = "${var.project_name}-user-pool"
  username_attributes = ["phone_number"] # O login será o número de telefone
  auto_verified_attributes = ["phone_number"]

  # Configuração dos triggers Lambda
  lambda_config {
    define_auth_challenge             = aws_lambda_function.define_auth_challenge.arn
    create_auth_challenge             = aws_lambda_function.create_auth_challenge.arn
    verify_auth_challenge_response    = aws_lambda_function.verify_auth_challenge.arn
  }

  # Adiciona um atributo customizado para o CPF
  schema {
    name                = "cpf"
    attribute_data_type = "String"
    mutable             = true
    required            = false
  }
}

resource "aws_cognito_user_pool_client" "client" {
  name = "${var.project_name}-client"
  user_pool_id = aws_cognito_user_pool.user_pool.id
  explicit_auth_flows = ["CUSTOM_AUTH_FLOW_ONLY"]
  generate_secret = false # Para aplicações web/mobile (SPA)
}

# ------------------------------------------------------------------
# Arquivamento do código fonte das Lambdas
# ------------------------------------------------------------------
data "archive_file" "orchestrator_zip" {
  type        = "zip"
  source_dir  = "../src/orchestrator/"
  output_path = "${path.module}/orchestrator.zip"
}

data "archive_file" "define_auth_zip" {
  type        = "zip"
  source_dir  = "../src/define-auth-challenge/"
  output_path = "${path.module}/define_auth.zip"
}

data "archive_file" "create_auth_zip" {
  type        = "zip"
  source_dir  = "../src/create-auth-challenge/"
  output_path = "${path.module}/create_auth.zip"
}

data "archive_file" "verify_auth_zip" {
  type        = "zip"
  source_dir  = "../src/verify-auth-challenge/"
  output_path = "${path.module}/verify_auth.zip"
}

# ------------------------------------------------------------------
# Funções Lambda e Permissões
# ------------------------------------------------------------------
# --- Lambda Orchestrator (API Gateway) ---
resource "aws_lambda_function" "orchestrator" {
  filename         = data.archive_file.orchestrator_zip.output_path
  function_name    = "${var.project_name}-orchestrator"
  role             = aws_iam_role.orchestrator_lambda_role.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.orchestrator_zip.output_base64sha256
  runtime          = "nodejs20.x"

  environment {
    variables = {
      USER_POOL_ID = aws_cognito_user_pool.user_pool.id
      CLIENT_ID    = aws_cognito_user_pool_client.client.id
    }
  }
}

# --- Lambdas dos Triggers ---
resource "aws_lambda_function" "define_auth_challenge" {
  filename         = data.archive_file.define_auth_zip.output_path
  function_name    = "${var.project_name}-define-auth"
  role             = aws_iam_role.cognito_trigger_lambda_role.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.define_auth_zip.output_base64sha256
  runtime          = "nodejs20.x"
}

resource "aws_lambda_function" "create_auth_challenge" {
  filename         = data.archive_file.create_auth_zip.output_path
  function_name    = "${var.project_name}-create-auth"
  role             = aws_iam_role.cognito_trigger_lambda_role.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.create_auth_zip.output_base64sha256
  runtime          = "nodejs20.x"
}

resource "aws_lambda_function" "verify_auth_challenge" {
  filename         = data.archive_file.verify_auth_zip.output_path
  function_name    = "${var.project_name}-verify-auth"
  role             = aws_iam_role.cognito_trigger_lambda_role.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.verify_auth_zip.output_base64sha256
  runtime          = "nodejs20.x"
}

# --- Permissões para o Cognito invocar os triggers ---
resource "aws_lambda_permission" "allow_cognito_define" {
  statement_id  = "AllowCognitoInvokeDefine"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.define_auth_challenge.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.user_pool.arn
}

resource "aws_lambda_permission" "allow_cognito_create" {
  statement_id  = "AllowCognitoInvokeCreate"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create_auth_challenge.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.user_pool.arn
}

resource "aws_lambda_permission" "allow_cognito_verify" {
  statement_id  = "AllowCognitoInvokeVerify"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.verify_auth_challenge.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.user_pool.arn
}

# ------------------------------------------------------------------
# API Gateway
# ------------------------------------------------------------------
resource "aws_api_gateway_rest_api" "api" {
  name        = "${var.project_name}-api"
  description = "API para o fluxo de autenticação passwordless"
}

resource "aws_api_gateway_resource" "auth_resource" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "auth"
}

resource "aws_api_gateway_method" "auth_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.auth_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "auth_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.auth_resource.id
  http_method             = aws_api_gateway_method.auth_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.orchestrator.invoke_arn
}

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  # Adiciona um trigger para recriar o deployment quando a integração mudar
  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_integration.auth_integration))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "stage" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = "v1"
}

resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.orchestrator.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}