# Cria um segredo no AWS Secrets Manager para armazenar a chave do JWT
resource "aws_secretsmanager_secret" "jwt_secret" {
  name = "${var.project_name}-jwt-secret-key"
}

# Define o valor do segredo.
# Em um cenário real, gere um valor aleatório e seguro.
# Para este exemplo, estamos usando um valor fixo.
# É recomendado rotacionar essa chave periodicamente.
resource "aws_secretsmanager_secret_version" "jwt_secret_value" {
  secret_id     = aws_secretsmanager_secret.jwt_secret.id
  secret_string = "uma-chave-secreta-muito-forte-e-dificil-de-adivinhar-12345"
}