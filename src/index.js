// Usando o AWS SDK v3, que é o padrão moderno
import { 
    CognitoIdentityProviderClient, 
    ListUsersCommand, // Comando para buscar usuários
    AdminInitiateAuthCommand, 
    AdminRespondToAuthChallengeCommand 
} from "@aws-sdk/client-cognito-identity-provider";

const client = new CognitoIdentityProviderClient({});
const { USER_POOL_ID, CLIENT_ID } = process.env;

// Função auxiliar para formatar a resposta para o API Gateway
const createResponse = (statusCode, body) => ({
    statusCode,
    headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*", // Em produção, restrinja o domínio
    },
    body: JSON.stringify(body),
});

export const handler = async (event) => {
    // 1. Extrair dados do corpo da requisição
    if (!event.body) {
        return createResponse(400, { message: "Corpo da requisição ausente." });
    }
    const body = JSON.parse(event.body);
    const { cpf, otp, session } = body;

    if (!cpf) {
        return createResponse(400, { message: "O CPF é obrigatório." });
    }
    
    let username;
    
    // 2. Etapa de Consulta: Encontrar o usuário pelo CPF
    try {
        const listUsersCommand = new ListUsersCommand({
            UserPoolId: USER_POOL_ID,
            Filter: `custom:cpf = "${cpf}"`, // Filtra pelo atributo customizado
            Limit: 1,
        });

        const { Users } = await client.send(listUsersCommand);

        if (!Users || Users.length === 0) {
            return createResponse(404, { message: "Cliente não encontrado." });
        }
        if (Users.length > 1) {
            // Isso indica um problema de integridade de dados (CPFs duplicados)
            console.error(`Múltiplos usuários encontrados para o CPF: ${cpf}`);
            return createResponse(500, { message: "Erro interno: Múltiplos registros encontrados." });
        }
        
        // Armazena o username principal do usuário encontrado
        username = Users[0].Username;

    } catch (error) {
        console.error("Erro ao buscar usuário no Cognito:", error);
        return createResponse(500, { message: "Erro ao consultar cliente.", error: error.message });
    }

    // 3. Etapa de Autenticação: Iniciar ou responder ao fluxo
    try {
        let authResponse;
        
        // Se o OTP foi enviado, estamos na segunda fase (verificação)
        if (otp && session) {
            const command = new AdminRespondToAuthChallengeCommand({
                UserPoolId: USER_POOL_ID,
                ClientId: CLIENT_ID,
                ChallengeName: 'CUSTOM_CHALLENGE',
                Session: session,
                ChallengeResponses: {
                    USERNAME: username, // Usa o username encontrado na busca
                    ANSWER: otp,
                },
            });
            authResponse = await client.send(command);
        } else {
            // Se não, estamos na primeira fase (iniciação)
            const command = new AdminInitiateAuthCommand({
                UserPoolId: USER_POOL_ID,
                ClientId: CLIENT_ID,
                AuthFlow: 'CUSTOM_AUTH',
                AuthParameters: {
                    USERNAME: username, // Usa o username encontrado na busca
                },
            });
            authResponse = await client.send(command);
        }

        // Se a autenticação for bem-sucedida, os tokens JWT estarão em `AuthenticationResult`
        return createResponse(200, authResponse);

    } catch (error) {
        console.error("Erro no fluxo de autenticação do Cognito:", error);
        return createResponse(400, { message: "Falha na autenticação.", error: error.name });
    }
};