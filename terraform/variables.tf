variable "nlb_arn" {
  description = "O ARN (Amazon Resource Name) do Network Load Balancer interno."
  type        = string
}

variable "db_host" {
  description = "O host do banco de dados."
  type        = string
}

variable "db_port" {
  description = "A porta do banco de dados."
  type        = number
  default     = 5432
}

variable "db_name" {
  description = "O nome do banco de dados (dbname)."
  type        = string
}

variable "db_table" {
  description = "O nome da tabela de clientes."
  type        = string
}

variable "db_cpf_column" {
  description = "Nome da coluna que armazena o CPF na tabela de clientes."
  type        = string
}

variable "jwt_secret" {
  description = "Segredo para assinar o token JWT."
  type        = string
  sensitive   = true
}

variable "db_secret_arn" {
  description = "O ARN do segredo no AWS Secrets Manager para as credenciais do banco de dados."
  type        = string
  # Este valor será preenchido pelo output do nosso recurso de segredo.
  default = ""
}

variable "vpc_id" {
  description = "O ID da VPC onde o NLB e o banco de dados residem."
  type        = string
}

variable "private_subnet_ids" {
  description = "Uma lista de IDs de sub-redes privadas para a função Lambda."
  type        = list(string)
}
