# Política IAM que permite à Lambda escrever logs no CloudWatch
resource "aws_iam_policy" "lambda_logging" {
  name        = "${var.project_name}-lambda-logging-policy"
  description = "Política para logs do CloudWatch"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Política IAM que permite à Lambda consultar o Cognito User Pool
resource "aws_iam_policy" "lambda_cognito_read" {
  name        = "${var.project_name}-lambda-cognito-policy"
  description = "Política para consultar usuários no Cognito"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = ["cognito-idp:ListUsers"],
        Effect   = "Allow",
        # Restringe a permissão apenas ao User Pool específico
        Resource = "arn:aws:cognito-idp:${var.aws_region}:${data.aws_caller_identity.current.account_id}:userpool/${var.cognito_user_pool_id}"
      }
    ]
  })
}

# Role que a função Lambda irá assumir
resource "aws_iam_role" "lambda_exec_role" {
  name = "${var.project_name}-lambda-exec-role"
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

# Anexa as políticas à role
resource "aws_iam_role_policy_attachment" "lambda_logs_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

resource "aws_iam_role_policy_attachment" "lambda_cognito_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_cognito_read.arn
}

data "aws_caller_identity" "current" {}