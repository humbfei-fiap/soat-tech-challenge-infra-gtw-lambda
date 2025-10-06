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
  connection_id           = aws_api_gateway_vpc_link.this.id
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
  connection_id           = aws_api_gateway_vpc_link.this.id
  uri                     = "http://${data.aws_lb.this.dns_name}/swagger-ui/"
}




# Recurso curinga para capturar qualquer outro caminho na URL (ex: /products, /orders)
resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "{proxy+}"
}

# Permissão para o API Gateway invocar a função Lambda de autenticação
resource "aws_lambda_permission" "api_gateway_invoke_auth" {
  statement_id  = "AllowAPIGatewayToInvokeAuthLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.authorizer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}

# Recurso para /auth
resource "aws_api_gateway_resource" "auth" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "auth"
}

# Método GET para /auth
resource "aws_api_gateway_method" "get_auth" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.auth.id
  http_method   = "GET"
  authorization = "NONE"
}

# Integração com a Lambda para a rota /auth
resource "aws_api_gateway_integration" "auth_lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.auth.id
  http_method             = aws_api_gateway_method.get_auth.http_method
  integration_http_method = "POST" # Sempre POST para integração AWS_PROXY
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.authorizer.invoke_arn
}

# Método ANY para o recurso curinga
resource "aws_api_gateway_method" "proxy_any" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE"

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
  connection_id           = aws_api_gateway_vpc_link.this.id
  
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
      customers_create_method = aws_api_gateway_method.post_customers_create.id,
      swagger_method = aws_api_gateway_method.get_swagger.id,
      auth_method = aws_api_gateway_method.get_auth.id
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
