resource "aws_secretsmanager_secret" "db_credentials" {
  name = "soat/tech-challenge/db-credentials"
  description = "Credenciais para o banco de dados PostgreSQL"
}

resource "aws_secretsmanager_secret_version" "db_credentials_version" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  secret_string = jsonencode({
    # PREENCHA: Substitua pelos dados de conexão do seu banco de dados.
    host     = "your-database-host.rds.amazonaws.com"
    port     = 5432
    username = "your_db_user"
    password = "your_db_password"
    dbname   = "your_db_name"
  })

  # Ignora mudanças feitas fora do Terraform (ex: rotação de senha manual)
  lifecycle {
    ignore_changes = [secret_string]
  }
}
