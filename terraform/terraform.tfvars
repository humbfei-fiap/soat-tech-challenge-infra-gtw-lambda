# ARN do Network Load Balancer
nlb_arn = "arn:aws:elasticloadbalancing:us-east-1:239409137076:loadbalancer/net/a8a84b9af455f417da4eab7da911da86/0c2f5acb6e5b18de"

# Detalhes da VPC e Sub-redes
vpc_id             = "vpc-8ce247f1"
private_subnet_ids = ["subnet-c3f47da5", "subnet-8a652684"]

# Detalhes do Banco de Dados
db_host = "soat-postgres-db.cszqygoyua1z.us-east-1.rds.amazonaws.com"
db_name = "fastdb"
# db_port = 5432 # Opcional, o padrão já é 5432

# Nome da tabela e coluna para validação de CPF
db_table      = "customers"
db_cpf_column = "cpf"

jwt_secret = "fiap"