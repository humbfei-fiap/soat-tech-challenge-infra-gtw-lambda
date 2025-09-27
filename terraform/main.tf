provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

# --- IAM Role and Policies ---
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

resource "aws_iam_policy" "lambda_logging" {
  name        = "${var.project_name}-lambda-logging-policy"
  description = "Policy for CloudWatch logs"
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

resource "aws_iam_policy" "lambda_cognito_read" {
  name        = "${var.project_name}-lambda-cognito-policy"
  description = "Policy to read users from Cognito"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = ["cognito-idp:ListUsers"],
        Effect   = "Allow",
        Resource = aws_cognito_user_pool.user_pool.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

resource "aws_iam_role_policy_attachment" "lambda_cognito_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_cognito_read.arn
}

# --- Lambda Functions ---
data "archive_file" "validator_cpf_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../src/validator_cpf/"
  output_path = "${path.module}/validator_cpf.zip"
}

data "archive_file" "api_endpoint_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../src/api_endpoint/"
  output_path = "${path.module}/api_endpoint.zip"
}

resource "aws_lambda_function" "validator_cpf_lambda" {
  function_name    = "${var.project_name}-validator-cpf"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  filename         = data.archive_file.validator_cpf_zip.output_path
  source_code_hash = data.archive_file.validator_cpf_zip.output_base64sha256
  tags = {
    Project = var.project_name
  }
}

resource "aws_lambda_function" "api_endpoint_lambda" {
  function_name = "${var.project_name}-api-endpoint"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  filename      = data.archive_file.api_endpoint_zip.output_path
  source_code_hash = data.archive_file.api_endpoint_zip.output_base64sha256
  environment {
    variables = {
      USER_POOL_ID = aws_cognito_user_pool.user_pool.id
    }
  }
  tags = {
    Project = var.project_name
  }
}