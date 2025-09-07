variable "aws_region" {
  description = "Região da AWS para implantar os recursos."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome do projeto, usado para nomear recursos."
  type        = string
  default     = "auth-api"
}

variable "cognito_user_pool_id" {
  description = "ID do AWS Cognito User Pool para consultar os usuários."
  type        = string
  # Sensível para não exibir em logs.
  sensitive   = true 
}