# Cria um arquivo .zip com o código da Lambda e suas dependências
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "../src/"
  output_path = "${path.module}/../build/lambda.zip"
}

# Define o recurso da função Lambda
resource "aws_lambda_function" "auth_function" {
  function_name    = "${var.project_name}-function"
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  role             = aws_iam_role.lambda_exec_role.arn
  
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      USER_POOL_ID = var.cognito_user_pool_id
    }
  }

  tags = {
    Project = var.project_name
  }
}