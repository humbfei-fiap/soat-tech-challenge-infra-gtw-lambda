locals {
  # Lista de serviços que correspondem aos caminhos no Ingress
  services = toset(["orders", "payments", "products", "customers"])
}

resource "aws_api_gateway_rest_api" "this" {
  name        = "soat-tech-challenge-api"
  description = "API Gateway para os Microsserviços do Tech Challenge SOAT"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# --- Configuração Dinâmica das Rotas dos Serviços ---

# 1. Recurso raiz do serviço (ex: /order)
resource "aws_api_gateway_resource" "service" {
  for_each    = local.services
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = each.key
}

# 2. Método ANY para a raiz do serviço
resource "aws_api_gateway_method" "service_any" {
  for_each      = local.services
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.service[each.key].id
  http_method   = "ANY"
  authorization = "NONE"
}

# 3. Integração para a raiz do serviço
resource "aws_api_gateway_integration" "service_integration" {
  for_each                = local.services
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.service[each.key].id
  http_method             = aws_api_gateway_method.service_any[each.key].http_method
  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  connection_type         = "VPC_LINK"
  connection_id           = aws_api_gateway_vpc_link.this.id
  # Encaminha para o NLB mantendo o caminho (ex: /order)
  uri                     = "http://${data.aws_lb.this.dns_name}/${each.key}"
}

# 4. Recurso {proxy+} filho do serviço (ex: /order/{proxy+})
resource "aws_api_gateway_resource" "service_proxy" {
  for_each    = local.services
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.service[each.key].id
  path_part   = "{proxy+}"
}

# 5. Método ANY para {proxy+}
resource "aws_api_gateway_method" "service_proxy_any" {
  for_each      = local.services
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.service_proxy[each.key].id
  http_method   = "ANY"
  authorization = "NONE"
  request_parameters = {
    "method.request.path.proxy" = true
  }
}

# 6. Integração para {proxy+}
resource "aws_api_gateway_integration" "service_proxy_integration" {
  for_each                = local.services
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.service_proxy[each.key].id
  http_method             = aws_api_gateway_method.service_proxy_any[each.key].http_method
  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  connection_type         = "VPC_LINK"
  connection_id           = aws_api_gateway_vpc_link.this.id
  
  # Encaminha para o NLB com o caminho completo
  uri                     = "http://${data.aws_lb.this.dns_name}/${each.key}/{proxy}"

  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
}

# --- Endpoint de Autenticação (/auth) ---

resource "aws_api_gateway_resource" "auth" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "auth"
}

resource "aws_api_gateway_method" "auth_get" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.auth.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "auth_integration" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.auth.id
  http_method             = aws_api_gateway_method.auth_get.http_method
  integration_http_method = "POST" # Lambda sempre é invocada via POST pelo Gateway, mesmo que a rota seja GET
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.authorizer.invoke_arn
}

resource "aws_lambda_permission" "apigw_invoke_auth" {
  statement_id  = "AllowAPIGatewayInvokeAuth"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.authorizer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/GET/auth"
}

# --- Deploy ---

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  triggers = {
    # Recalcula o hash se as integrações mudarem
    redeployment = sha1(jsonencode({
      service_integrations       = [for k, v in aws_api_gateway_integration.service_integration : v.id],
      service_proxy_integrations = [for k, v in aws_api_gateway_integration.service_proxy_integration : v.id],
      auth_integration           = aws_api_gateway_integration.auth_integration.id
    }))
    timestamp = timestamp()
  }

  lifecycle {
    create_before_destroy = true
  }
  
  depends_on = [
    aws_api_gateway_integration.service_integration,
    aws_api_gateway_integration.service_proxy_integration,
    aws_api_gateway_integration.auth_integration
  ]
}

resource "aws_api_gateway_stage" "this" {
  deployment_id = aws_api_gateway_deployment.this.id
  rest_api_id   = aws_api_gateway_rest_api.this.id
  stage_name    = "v1"
}
