variable "aws_region" {
  description = "Região da AWS para a implantação"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome do projeto, usado para nomear recursos"
  type        = string
  default     = "auth-passwordless-cpf"
}