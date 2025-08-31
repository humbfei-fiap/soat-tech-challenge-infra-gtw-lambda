output "api_gateway_invoke_url" {
  description = "URL base para invocar a API de autenticação"
  value       = "${aws_api_gateway_deployment.deployment.invoke_url}${aws_api_gateway_stage.stage.stage_name}"
}

output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.user_pool.id
}

output "cognito_client_id" {
  value = aws_cognito_user_pool_client.client.id
}