data "aws_secretsmanager_secret" "db_credentials" {
  # PREENCHA: Substitua pelo nome do seu secret que já existe no AWS Secrets Manager
  name = "rds!db-8e4f60db-f835-4c87-a1cd-2fe50c8ab3cb"
}
