# Creates the Cognito User Pool
resource "aws_cognito_user_pool" "user_pool" {
  name = "${var.project_name}-user-pool"

  # Require email as a login alias
  alias_attributes = ["email"]

  # Defines the standard and custom attributes
  schema {
    name                = "email"
    required            = true
    attribute_data_type = "String"
    mutable             = false # Does not allow the email to be changed after registration
  }

  schema {
    name                = "cpf"
    attribute_data_type = "String"
    mutable             = false
    required = false
  }
  
  # Password policy configuration
  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  # Connects the Lambda function to the "Pre Sign-up" trigger
  lambda_config {
    pre_sign_up = aws_lambda_function.validator_cpf_lambda.arn
  }

  tags = {
    Project = var.project_name
  }
}

# Permission for Cognito to invoke the validation Lambda
resource "aws_lambda_permission" "allow_cognito" {
  statement_id  = "AllowCognitoToInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.validator_cpf_lambda.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.user_pool.arn
}

# Creates a "client" for the User Pool. Web/mobile applications will use this ID
# to interact with the pool (login, registration, etc.)
resource "aws_cognito_user_pool_client" "app_client" {
  name = "${var.project_name}-app-client"
  user_pool_id = aws_cognito_user_pool.user_pool.id

  # Disables the generation of a client secret (common for SPA web apps)
  generate_secret = false
  
  # Allowed authentication flows
  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]
}