# Criaçao da lambda function
resource "aws_lambda_function" "auth_lambda" {
  function_name = "authLambda"
  role          = aws_iam_role.lambda_role.arn

  # Classe Java + metodo handler
  handler       = "com.example.lambda.Handler::handleRequest"
  runtime       = "java21"

  # Caminho para o jar empacotado pelo Maven/Gradle
  filename         = "${path.module}/../lambda-build/lambda-auth-1.0-SNAPSHOT-shaded.jar"
  source_code_hash = filebase64sha256("${path.module}/../lambda-build/lambda-auth-1.0-SNAPSHOT-shaded.jar")


  # Variáveis de ambiente para conexão com o banco
  environment {
    variables = {
      DB_URL      = "jdbc:mysql://SEU_RDS_ENDPOINT:3306/sua_db"
      DB_USER     = "admin"
      DB_PASSWORD = "senhaSegura"
    }
  }
}

