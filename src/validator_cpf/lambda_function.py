import json
import os
import boto3

# Inicializa o cliente do Cognito
cognito_client = boto3.client('cognito-idp')

# Pega o ID do User Pool das variáveis de ambiente (será configurado via Terraform)
USER_POOL_ID = os.environ.get('USER_POOL_ID')

def lambda_handler(event, context):
    """
    Função principal que recebe o evento do API Gateway.
    Espera um corpo JSON com a chave 'cpf'.
    """
    print(f"Evento recebido: {event}")

    # Valida se o corpo da requisição existe
    if 'body' not in event or not event['body']:
        return {
            'statusCode': 400,
            'body': json.dumps({'message': 'Corpo da requisição ausente ou vazio.'})
        }

    try:
        # Extrai o CPF do corpo da requisição
        body = json.loads(event['body'])
        cpf = body.get('cpf')

        if not cpf:
            return {
                'statusCode': 400,
                'body': json.dumps({'message': "O campo 'cpf' é obrigatório."})
            }

        # Monta os parâmetros para a busca no Cognito
        # Assumindo que o CPF está armazenado em um atributo customizado chamado 'custom:cpf'
        params = {
            'UserPoolId': USER_POOL_ID,
            'Filter': f'custom:cpf = "{cpf}"',
            'Limit': 1
        }

        # Executa a consulta
        response = cognito_client.list_users(**params)

        if response['Users']:
            # Usuário encontrado
            user_data = response['Users'][0]
            # Filtra os atributos que você quer retornar
            attributes = {attr['Name']: attr['Value'] for attr in user_data.get('Attributes', [])}
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Cliente encontrado.',
                    'username': user_data['Username'],
                    'attributes': attributes
                })
            }
        else:
            # Usuário não encontrado
            return {
                'statusCode': 404,
                'body': json.dumps({'message': 'Cliente não encontrado.'})
            }

    except json.JSONDecodeError:
        return {
            'statusCode': 400,
            'body': json.dumps({'message': 'Corpo da requisição não é um JSON válido.'})
        }
    except Exception as e:
        print(f"Erro inesperado: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'message': 'Erro interno do servidor.'})
        }