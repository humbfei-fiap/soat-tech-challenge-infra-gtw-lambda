# Cria o Cognito User Pool
resource "aws_cognito_user_pool" "user_pool" {
  name = "${var.prefixo_projeto}-user-pool"

  # Exigir email como alias de login
  alias_attributes = ["email"]

  # Define os atributos padrão e customizados
  schema {
    name                = "email"
    required            = true
    attribute_data_type = "String"
    mutable             = false # Não permite que o email seja alterado após o cadastro
  }

  schema {
    name                = "cpf"
    required            = true
    attribute_data_type = "String"
    mutable             = false
    # O prefixo 'custom' é adicionado automaticamente pelo Cognito
  }
  
  # Configuração da política de senha
  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  # Conecta a função Lambda ao gatilho "Pre Sign-up"
  lambda_config {
    pre_sign_up = aws_lambda_function.validator_cpf_lambda.arn
  }

  tags = {
    Project = var.prefixo_projeto
  }
}

# Permissão para o Cognito invocar a Lambda de validação
resource "aws_lambda_permission" "allow_cognito" {
  statement_id  = "AllowCognitoToInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.validator_cpf_lambda.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.user_pool.arn
}

# Cria um "cliente" para o User Pool. Aplicações web/mobile usarão este ID
# para interagir com o pool (login, cadastro, etc.)
resource "aws_cognito_user_pool_client" "app_client" {
  name = "${var.prefixo_projeto}-app-client"
  user_pool_id = aws_cognito_user_pool.user_pool.id

  # Desabilita a geração de um client secret (comum para apps web SPA)
  generate_secret = false
  
  # Fluxos de autenticação permitidos
  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]
}