resource "null_resource" "build_lambda" {
  # Dispara a reconstrução se o código da lambda ou as dependências mudarem
  triggers = {
    lambda_code_hash = filebase64sha256("${path.module}/../lambda/authorizer/lambda.py")
    requirements_hash = filebase64sha256("${path.module}/../lambda/authorizer/requirements.txt")
  }

  provisioner "local-exec" {
    command = <<EOT
      mkdir -p "${path.module}/build/lambda"
      pip install --platform manylinux2014_x86_64 --implementation cp --python-version 3.9 --only-binary=:all: -r "${path.module}/../lambda/authorizer/requirements.txt" -t "${path.module}/build/lambda"
      cp "${path.module}/../lambda/authorizer/lambda.py" "${path.module}/build/lambda/"
    EOT
  }
}

# Empacota o diretório de build que agora contém as dependências
data "archive_file" "lambda_authorizer_zip" {
  type        = "zip"
  source_dir  = "${path.module}/build/lambda"
  output_path = "${path.module}/../lambda_authorizer.zip"
  depends_on = [
    null_resource.build_lambda
  ]
}


resource "aws_lambda_function" "authorizer" {
  function_name = "soat-cpf-authorizer"
  handler       = "lambda.lambda_handler"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_authorizer_role.arn

  filename         = data.archive_file.lambda_authorizer_zip.output_path
  source_code_hash = data.archive_file.lambda_authorizer_zip.output_base64sha256

  timeout = 10 # Tempo máximo de execução em segundos

  environment {
    variables = {
      DB_SECRET_NAME = data.aws_secretsmanager_secret.db_credentials.name
      DB_HOST        = var.db_host
      DB_PORT        = var.db_port
      DB_NAME        = var.db_name
      DB_TABLE       = var.db_table
      DB_CPF_COLUMN  = var.db_cpf_column
      JWT_SECRET     = var.jwt_secret
    }
  }

  # Configuração de VPC para que a Lambda possa acessar o banco de dados
  # PREENCHA as variáveis 'private_subnet_ids' e 'vpc_id' no arquivo variables.tf
  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  depends_on = [
    data.archive_file.lambda_authorizer_zip
  ]
}

# Grupo de segurança para a função Lambda
resource "aws_security_group" "lambda" {
  name        = "soat-lambda-sg"
  description = "Security group for the authorizer Lambda function"
  vpc_id      = var.vpc_id

  # A Lambda não precisa de regras de entrada (ingress) para esta configuração
  # As regras de saída (egress) permitem que ela se conecte ao banco de dados

  egress {
    from_port   = 5432 # Porta do PostgreSQL
    to_port     = 5432
    protocol    = "tcp"
    # PREENCHA: Idealmente, restrinja ao IP ou Security Group do seu banco de dados
    cidr_blocks = ["0.0.0.0/0"] 
  }

  egress {
    from_port   = 443 # HTTPS para acessar o Secrets Manager
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
