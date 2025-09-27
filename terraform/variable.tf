
variable "aws_region" {
  description = "AWS region to deploy resources."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name, used to name resources."
  type        = string
  default     = "auth-api"
}
