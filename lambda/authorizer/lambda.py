
import json
import boto3
import psycopg2
import os
import logging

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
    Recebe uma requisição do API Gateway, valida o CPF e retorna uma política IAM.
    """
    logger.info(f"Evento recebido: {event}")

    # O CPF é esperado no cabeçalho 'cpf'
    cpf = event.get('headers', {}).get('cpf')
    method_arn = event.get('methodArn')

    if not cpf:
        logger.warning("CPF não encontrado nos cabeçalhos da requisição.")
        # Retorna 'Deny' explicitamente se o CPF não for fornecido
        return generate_policy('user', 'Deny', method_arn, {"reason": "CPF not provided"})

    try:
        secrets = get_database_secret()

        logger.info("Conectando ao banco de dados...")
        conn = psycopg2.connect(
            host=os.environ.get("DB_HOST"),
            dbname=os.environ.get("DB_NAME"),
            user=secrets['username'],
            password=secrets['password'],
            port=os.environ.get("DB_PORT", 5432)
        )
        
        with conn.cursor() as cur:
            # Constrói a query dinamicamente com os nomes da tabela e coluna
            table_name = os.environ.get("DB_TABLE")
            column_name = os.environ.get("DB_CPF_COLUMN")
            
            if not table_name or not column_name:
                logger.error("Variáveis de ambiente DB_TABLE ou DB_CPF_COLUMN não definidas.")
                # Retorna Deny se a configuração estiver incompleta
                return generate_policy('user', 'Deny', method_arn, {"reason": "Lambda configuration error"})

            query = f"SELECT 1 FROM {table_name} WHERE {column_name} = %s"
            logger.info(f"Executando query: {query}")
            cur.execute(query, (cpf,))
            customer_exists = cur.fetchone()

        conn.close()

        if customer_exists:
            logger.info(f"CPF '{cpf}' encontrado. Autorizando acesso.")
            return generate_policy(cpf, 'Allow', method_arn)
        else:
            logger.warning(f"CPF '{cpf}' não encontrado. Negando acesso.")
            return generate_policy(cpf, 'Deny', method_arn, {"reason": "CPF not found"})

    except psycopg2.Error as db_error:
        logger.error(f"Erro no banco de dados: {db_error}")
        # Falha segura: nega o acesso em caso de erro de banco de dados
        return generate_policy('user', 'Deny', method_arn, {"reason": "Database error"})
    except Exception as e:
        logger.error(f"Erro inesperado: {e}")
        # Falha segura: nega o acesso em caso de qualquer outro erro
        return generate_policy('user', 'Deny', method_arn, {"reason": "Internal server error"})

def generate_policy(principal_id, effect, resource, context=None):
    """Gera a estrutura da política IAM para o API Gateway."""
    policy = {
        "principalId": principal_id,
        "policyDocument": {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Action": "execute-api:Invoke",
                    "Effect": effect,
                    "Resource": resource
                }
            ]
        }
    }
    # O contexto é opcional, mas útil para debugar no lado do cliente
    if context:
        policy['context'] = context
        
    logger.info(f"Política gerada: {policy}")
    return policy
