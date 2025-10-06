
import json
import boto3
import psycopg2
import os
import logging
import jwt
from validate_docbr import CPF

# Configuração do logger
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def get_database_secret():
    """Busca as credenciais do banco de dados no AWS Secrets Manager."""
    secret_name = os.environ.get("DB_SECRET_NAME")
    if not secret_name:
        raise ValueError("Variável de ambiente DB_SECRET_NAME não definida.")

    session = boto3.session.Session()
    client = session.client(service_name='secretsmanager')

    try:
        get_secret_value_response = client.get_secret_value(SecretId=secret_name)
        secret = get_secret_value_response['SecretString']
        return json.loads(secret)
    except Exception as e:
        logger.error(f"Erro ao buscar o segredo: {e}")
        raise e

def lambda_handler(event, context):
    """
    Recebe uma requisição do API Gateway, valida o CPF e retorna um JWT.
    Funciona como uma integração de proxy Lambda.
    """
    logger.info(f"Evento recebido: {event}")

    cpf_value = event.get('headers', {}).get('cpf')

    if not cpf_value:
        logger.warning("CPF não encontrado nos cabeçalhos da requisição.")
        return {
            "statusCode": 400,
            "body": json.dumps({"message": "Header 'cpf' é obrigatório"})
        }

    # 1. Validar o formato do CPF
    cpf_validator = CPF()
    if not cpf_validator.validate(cpf_value):
        logger.warning(f"CPF '{cpf_value}' é inválido.")
        return {
            "statusCode": 400,
            "body": json.dumps({"message": "CPF inválido"})
        }

    customer_exists = False
    try:
        secrets = get_database_secret()
        conn = psycopg2.connect(
            host=os.environ.get("DB_HOST"),
            dbname=os.environ.get("DB_NAME"),
            user=secrets['username'],
            password=secrets['password'],
            port=os.environ.get("DB_PORT", 5432)
        )
        with conn.cursor() as cur:
            table_name = os.environ.get("DB_TABLE")
            column_name = os.environ.get("DB_CPF_COLUMN")
            
            if not table_name or not column_name:
                logger.error("Variáveis de ambiente DB_TABLE ou DB_CPF_COLUMN não definidas.")
                return {"statusCode": 500, "body": json.dumps({"message": "Erro de configuração do servidor"})}

            query = f"SELECT 1 FROM {table_name} WHERE {column_name} = %s"
            cur.execute(query, (cpf_value,))
            customer_exists = cur.fetchone() is not None
        conn.close()
        
        if customer_exists:
            logger.info(f"CPF '{cpf_value}' encontrado no banco de dados.")
        else:
            logger.info(f"CPF '{cpf_value}' não encontrado, mas é válido.")

    except Exception as e:
        logger.error(f"Erro ao consultar o banco de dados: {e}. Prosseguindo.")
        customer_exists = False

    # 2. Gerar JWT
    jwt_secret = os.environ.get("JWT_SECRET")
    if not jwt_secret:
        logger.error("Variável de ambiente JWT_SECRET não definida.")
        return {"statusCode": 500, "body": json.dumps({"message": "Erro de configuração do servidor"})}

    payload = {
        "cpf": cpf_value,
        "customer": customer_exists
    }
    token = jwt.encode(payload, jwt_secret, algorithm="HS256")

    # 3. Retornar resposta HTTP com o token
    return {
        "statusCode": 200,
        "body": json.dumps({"token": token})
    }
