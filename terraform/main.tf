provider "aws" {
  region = var.aws_region
}

# --- IAM Role Genérica para as Lambdas ---
# Uma única role que ambas as funções podem usar, permitindo logs no CloudWatch.
resource "aws_iam_role" "lambda_exec_role" {
  name = "${var.prefixo_projeto}-lambda-exec-role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# --- Arquivamento dos códigos fonte ---
# O Terraform irá zipar o conteúdo das pastas 'src' para fazer o upload.
data "archive_file" "validator_cpf_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../src/validator_cpf/"
  output_path = "${path.module}/validator_cpf.zip"
}

data "archive_file" "api_endpoint_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../src/api_endpoint/"
  output_path = "${path.module}/api_endpoint.zip"
}

# --- Definição da Lambda de Validação de CPF ---
resource "aws_lambda_function" "validator_cpf_lambda" {
  function_name = "${var.prefixo_projeto}-validator-cpf"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"

  filename         = data.archive_file.validator_cpf_zip.output_path
  source_code_hash = data.archive_file.validator_cpf_zip.output_base64sha256

  # Depende da role ser criada primeiro
  depends_on = [aws_iam_role_policy_attachment.lambda_policy]

  tags = {
    Project = var.prefixo_projeto
  }
}

# --- Definição da Lambda do Endpoint da API ---
resource "aws_lambda_function" "api_endpoint_lambda" {
  function_name = "${var.prefixo_projeto}-api-endpoint"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"

  filename         = data.archive_file.api_endpoint_zip.output_path
  source_code_hash = data.archive_file.api_endpoint_zip.output_base64sha256

  depends_on = [aws_iam_role_policy_attachment.lambda_policy]

  tags = {
    Project = var.prefixo_projeto
  }
}