output "api_endpoint" {
  description = "URL base do API Gateway para invocar a função."
  value       = aws_api_gateway_stage.stage.invoke_url
}