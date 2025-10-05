Dando continuidade ao desenvolvimento do software para a lanchonete,
teremos as seguintes melhorias e alterações:

1. Implementar um API Gateway para receber a solicitação externa e
uma function serverless para autenticar/consultar o cliente com
base no CPF.
a. Integrar/Consultar o sistema de autenticação (AD, Cognito)
para identificar o cliente.
b. O cliente não precisa inserir qualquer tipo de senha para se
identificar, somente o CPF.
c. O fluxo de integração/consulta pode utilizar JWT ou
equivalente.

Implementar as melhores práticas de CI/CD para a aplicação,
segregando os códigos em repositórios

Toda ação que realizar criações/edições na cloud, devem
ser feitas com Terraform e automatizada com CI/CD.



Rotas 

1. Gerenciamento de Produtos
# 1.1 Criar um novo produto
POST /products/create
# 1.2 Listar produtos por categoria
GET /products/category/{category}
# 1.3 Atualizar um produto existente
PUT /products/update
2. Gerenciamento de Clientes
# 2.1 Cadastrar um novo cliente
POST /customers/create
# 2.2 Buscar cliente por CPF
GET /customers/{cpf}
3. Gerenciamento de Pedidos
# 3.1 Criar um novo pedido (checkout)
POST /orders/checkout
# 3.2 Listar todos os pedidos
GET /orders
# 3.3 Buscar pedido por ID
GET /orders/{order_id}
# 3.4 Atualizar status do pedido
PATCH /orders/{order_id}/status/{status}
4. Processamento de Pagamentos
# 4.1 Criar pagamento
POST /payments/create
# 4.2 Verificar status do pagamento
GET /payments/{payment_id}/status
# 4.3 Atualizar status do pagamento (recebe a notificação webhook)
POST /payments/{payment_id}/status

# SOAT Tech Challenge - Infra com API Gateway e Lambda

Este repositório contém a infraestrutura para um API Gateway com autenticação usando Cognito e Lambda Authorizer.

## Estrutura
- **Terraform**: Provisiona os recursos AWS.
- **Lambda**: Contém os códigos das funções Lambda.

## Como usar
1. Configure suas credenciais AWS.
2. Execute os comandos Terraform:
   ```bash
   terraform init
   terraform apply