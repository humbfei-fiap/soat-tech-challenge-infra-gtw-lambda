output "api_invoke_url" {
  description = "A URL de invocação para o estágio 'v1' do API Gateway."
  value       = aws_api_gateway_stage.this.invoke_url
}
