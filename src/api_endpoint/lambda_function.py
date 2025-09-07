import json

def lambda_handler(event, context):
    """
    Handler do endpoint protegido da API.
    A informação do usuário autenticado pode ser encontrada no contexto da requisição.
    """
    
    # O API Gateway injeta as informações do autorizador Cognito aqui
    # Você pode usar isso para obter o email, username, etc. do usuário logado.
    claims = event.get('requestContext', {}).get('authorizer', {}).get('claims', {})
    email_usuario = claims.get('email', 'Email não encontrado')

    print("Usuário autenticado:", email_usuario)

    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json'
        },
        'body': json.dumps({
            'message': 'Olá! Sua requisição foi autenticada com sucesso.',
            'seu_email': email_usuario
        })
    }