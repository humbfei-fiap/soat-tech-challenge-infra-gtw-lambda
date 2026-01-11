# --- Lambda de Autenticação (Authorizer / Login) ---

data "archive_file" "lambda_authorizer_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/authorizer"
  output_path = "${path.module}/../lambda_authorizer.zip"
}

resource "aws_iam_role" "lambda_authorizer_role" {
  name = "soat-lambda-authorizer-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_authorizer_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Permissão para acessar VPC (se a Lambda precisar acessar RDS)
resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.lambda_authorizer_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_security_group" "lambda_sg" {
  name        = "soat-lambda-sg"
  description = "Security group for the authorizer Lambda function"
  vpc_id      = "vpc-8ce247f1"

  egress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Em produção, restrinja ao CIDR do RDS
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Para falar com Secrets Manager
  }
}

resource "aws_iam_policy" "secrets_manager_policy" {
  name        = "soat-lambda-secrets-manager-policy"
  description = "Permite que a Lambda leia o segredo do banco de dados."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "secretsmanager:GetSecretValue"
        Effect   = "Allow"
        Resource = "arn:aws:secretsmanager:us-east-1:239409137076:secret:soat/tech-challenge/db-credentials-*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_secrets_manager" {
  role       = aws_iam_role.lambda_authorizer_role.name
  policy_arn = aws_iam_policy.secrets_manager_policy.arn
}

resource "aws_lambda_function" "authorizer" {
  filename      = data.archive_file.lambda_authorizer_zip.output_path
  function_name = "soat-cpf-authorizer"
  role          = aws_iam_role.lambda_authorizer_role.arn
  handler       = "lambda.lambda_handler" # Nome do arquivo (lambda.py) + nome da função
  runtime       = "python3.9"
  source_code_hash = data.archive_file.lambda_authorizer_zip.output_base64sha256

  environment {
    variables = {
      DB_SECRET_NAME = "soat/tech-challenge/db-credentials"
      JWT_SECRET     = "soat-secret-key-change-me" 
      DB_HOST        = "soat-postgres-db.cszqygoyua1z.us-east-1.rds.amazonaws.com"
      DB_NAME        = "fastdb"
      DB_TABLE       = "customers"
      DB_CPF_COLUMN  = "cpf"
    }
  }
  
  # Configuração de VPC
  vpc_config {
    subnet_ids         = ["subnet-8a652684", "subnet-c3f47da5"]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
}
