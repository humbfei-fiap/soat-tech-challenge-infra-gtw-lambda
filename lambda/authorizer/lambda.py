
import json
import os
import logging
import jwt
from datetime import datetime, timedelta, timezone

# Configuração do logger
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    MOCK DINÂMICO: 
    Recebe o CPF do header e gera um JWT contendo exatamente esse CPF.
    """
    try:
        logger.info(f"Evento recebido: {event}")

        # Tenta pegar o CPF do header (case insensitive para garantir)
        headers = event.get('headers', {})
        # API Gateway pode mandar headers em minúsculo ou original, vamos garantir
        cpf_value = headers.get('cpf') or headers.get('CPF')

        if not cpf_value:
            logger.warning("CPF não encontrado nos cabeçalhos da requisição.")
            return {
                "statusCode": 400,
                "body": json.dumps({"message": "Header 'cpf' é obrigatório"})
            }

        logger.info(f"Gerando token JWT dinâmico para o CPF: {cpf_value}")

        # Lógica de Mock para testar fluxos diferentes:
        # Se o CPF começar com "000", fingimos que é um cliente NOVO (não cadastrado)
        # Caso contrário, fingimos que é um cliente JÁ CADASTRADO.
        customer_exists = not cpf_value.startswith("000")

        # 2. Gerar JWT
        jwt_secret = os.environ.get("JWT_SECRET")
        if not jwt_secret:
            jwt_secret = "soat-secret-key-change-me"

        # Payload padrão JWT
        payload = {
            "sub": cpf_value,           # Subject (quem é o dono do token)
            "cpf": cpf_value,           # Custom claim com o CPF
            "customer": customer_exists, # Flag se existe ou não (para o front/backend saberem)
            "iat": datetime.now(timezone.utc), # Issued At
            "exp": datetime.now(timezone.utc) + timedelta(hours=1) # Expira em 1 hora
        }
        
        token = jwt.encode(payload, jwt_secret, algorithm="HS256")

        # 3. Retornar resposta HTTP com o token
        return {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json"
            },
            "body": json.dumps({
                "token": token
            })
        }
    except Exception as e:
        logger.error(f"Erro fatal na Lambda: {e}")
        return {
            "statusCode": 500,
            "body": json.dumps({"message": "Erro Interno Lambda (Mock)", "details": str(e)})
        }
