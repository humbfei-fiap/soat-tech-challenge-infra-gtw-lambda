resource "aws_iam_role" "lambda_authorizer_role" {
  name = "soat-lambda-authorizer-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Política para permitir acesso ao segredo do banco de dados
resource "aws_iam_policy" "secrets_manager_policy" {
  name        = "soat-lambda-secrets-manager-policy"
  description = "Permite que a Lambda leia o segredo do banco de dados."

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = "secretsmanager:GetSecretValue",
        Effect   = "Allow",
        Resource = data.aws_secretsmanager_secret.db_credentials.arn
      }
    ]
  })
}

# Anexa a política de acesso ao segredo à role da Lambda
resource "aws_iam_role_policy_attachment" "secrets_manager_attach" {
  role       = aws_iam_role.lambda_authorizer_role.name
  policy_arn = aws_iam_policy.secrets_manager_policy.arn
}

# Anexa a política básica de execução da Lambda (para logs no CloudWatch)
resource "aws_iam_role_policy_attachment" "basic_execution_attach" {
  role       = aws_iam_role.lambda_authorizer_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Anexa a política de acesso à VPC (necessário para a Lambda se conectar a recursos na VPC)
resource "aws_iam_role_policy_attachment" "vpc_access_attach" {
  role       = aws_iam_role.lambda_authorizer_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}
