resource "aws_api_gateway_rest_api" "this" {
  name        = "soat-tech-challenge-api"
  description = "API Gateway para o Tech Challenge da SOAT"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# --- Seção de Endpoints Públicos ---

# Recurso para /customers
resource "aws_api_gateway_resource" "customers" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "customers"
}

# Recurso para /customers/create
resource "aws_api_gateway_resource" "customers_create" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.customers.id
  path_part   = "create"
}

# Método POST para /customers/create (público)
resource "aws_api_gateway_method" "post_customers_create" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.customers_create.id
  http_method   = "POST"
  authorization = "NONE" # Sem autorizador
}

# Integração para o método de criação de cliente
resource "aws_api_gateway_integration" "post_customers_create_integration" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.customers_create.id
  http_method             = aws_api_gateway_method.post_customers_create.http_method
  type                    = "HTTP_PROXY"
  integration_http_method = "POST"
  connection_type         = "VPC_LINK"
  connection_id           = "zyeqy0"
  uri                     = "http://${data.aws_lb.this.dns_name}/customers/create"
}

# Recurso para /swagger-ui (simplificado para teste)
resource "aws_api_gateway_resource" "swagger_ui" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "swagger-ui"
}

# Método GET para a rota do Swagger (público)
resource "aws_api_gateway_method" "get_swagger" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.swagger_ui.id
  http_method   = "GET"
  authorization = "NONE" # Sem autorizador
}

# Integração para a rota do Swagger
resource "aws_api_gateway_integration" "get_swagger_integration" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.swagger_ui.id
  http_method             = aws_api_gateway_method.get_swagger.http_method
  type                    = "HTTP_PROXY"
  integration_http_method = "GET"
  connection_type         = "VPC_LINK"
  connection_id           = "zyeqy0"
  uri                     = "http://${data.aws_lb.this.dns_name}/swagger-ui/"
}


# --- Seção de Endpoints Privados (com autorizador) ---

# Define o autorizador customizado que usa a nossa função Lambda
resource "aws_api_gateway_authorizer" "cpf_authorizer" {
  name                   = "soat-cpf-authorizer"
  rest_api_id            = aws_api_gateway_rest_api.this.id
  authorizer_uri         = aws_lambda_function.authorizer.invoke_arn
  authorizer_credentials = aws_iam_role.api_gateway_authorizer_role.arn
  type                   = "TOKEN"
  identity_source        = "method.request.header.cpf" # Onde o API Gateway vai procurar o token (CPF)
  authorizer_result_ttl_in_seconds = 0 # Desabilitar cache para desenvolvimento, aumentar em produção
}

# Role para permitir que o API Gateway invoque a Lambda do autorizador
resource "aws_iam_role" "api_gateway_authorizer_role" {
  name = "soat-api-gateway-authorizer-invocation-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "api_gateway_authorizer_policy" {
  name = "soat-api-gateway-authorizer-invocation-policy"
  role = aws_iam_role.api_gateway_authorizer_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = "lambda:InvokeFunction",
        Effect   = "Allow",
        Resource = aws_lambda_function.authorizer.arn
      }
    ]
  })
}

# Permissão explícita para o API Gateway invocar a função Lambda
resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowAPIGatewayToInvokeAuthorizer"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.authorizer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/authorizers/${aws_api_gateway_authorizer.cpf_authorizer.id}"
}

# Recurso curinga para capturar qualquer outro caminho na URL (ex: /products, /orders)
resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "{proxy+}"
}

# Método ANY para o recurso curinga, aplicando nosso autorizador
resource "aws_api_gateway_method" "proxy_any" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.cpf_authorizer.id

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

# Integração com o NLB via VPC Link para os endpoints privados
resource "aws_api_gateway_integration" "proxy_integration" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.proxy.id
  http_method             = aws_api_gateway_method.proxy_any.http_method
  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  connection_type         = "VPC_LINK"
  connection_id           = "zyeqy0"
  
  uri                     = "http://${data.aws_lb.this.dns_name}/{proxy}" 

  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
}

# Deploy da API para torná-la pública
resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  # Um novo deploy é acionado sempre que a configuração da API muda
  triggers = {
    # Força um novo deploy sempre que a configuração dos recursos mudar
    redeployment = sha1(jsonencode(values({
      proxy_resource = aws_api_gateway_resource.proxy.id,
      proxy_method = aws_api_gateway_method.proxy_any.id,
      proxy_integration = aws_api_gateway_integration.proxy_integration.id,
      authorizer = aws_api_gateway_authorizer.cpf_authorizer.id,
      customers_create_method = aws_api_gateway_method.post_customers_create.id,
      swagger_method = aws_api_gateway_method.get_swagger.id
    })))
    # Adiciona um gatilho de tempo para forçar o deploy em qualquer 'apply'
    timestamp = timestamp()
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Define o estágio de deploy (ex: /v1, /prod)
resource "aws_api_gateway_stage" "this" {
  deployment_id = aws_api_gateway_deployment.this.id
  rest_api_id   = aws_api_gateway_rest_api.this.id
  stage_name    = "v1"
}
