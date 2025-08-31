# Role para as Lambdas dos Triggers do Cognito
resource "aws_iam_role" "cognito_trigger_lambda_role" {
  name = "${var.project_name}-cognito-trigger-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# Política de permissões para os triggers
resource "aws_iam_policy" "cognito_trigger_lambda_policy" {
  name        = "${var.project_name}-cognito-trigger-policy"
  description = "Permissões para os triggers do Cognito enviarem SMS e logar"
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
        Effect   = "Allow",
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Action   = ["sns:Publish"],
        Effect   = "Allow",
        Resource = "*" # Para produção, restrinja ao tópico SNS específico
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cognito_trigger_attach" {
  role       = aws_iam_role.cognito_trigger_lambda_role.name
  policy_arn = aws_iam_policy.cognito_trigger_lambda_policy.arn
}

# Role para a Lambda do API Gateway (Orchestrator)
resource "aws_iam_role" "orchestrator_lambda_role" {
  name = "${var.project_name}-orchestrator-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# Política para a Lambda Orchestrator chamar o Cognito
resource "aws_iam_policy" "orchestrator_lambda_policy" {
  name        = "${var.project_name}-orchestrator-policy"
  description = "Permite que a Lambda orquestradora chame o Cognito"
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
        Effect   = "Allow",
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Action   = ["cognito-idp:ListUsers", "cognito-idp:AdminInitiateAuth", "cognito-idp:AdminRespondToAuthChallenge"],
        Effect   = "Allow",
        Resource = aws_cognito_user_pool.user_pool.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "orchestrator_attach" {
  role       = aws_iam_role.orchestrator_lambda_role.name
  policy_arn = aws_iam_policy.orchestrator_lambda_policy.arn
}