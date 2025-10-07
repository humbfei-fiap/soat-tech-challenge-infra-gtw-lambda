# Fast Food API

API para gerenciamento de pedidos de fast food, desenvolvida como parte do Tech Challenge da FIAP.

## Vídeo de Apresentação TechChallenge Fase 3 

- [Vídeo de Apresentação](https://www.youtube.com/watch?v=XySUTroo2dk)
- [ArquiteturaCloud](https://drive.google.com/file/d/1XkkO6LtAgdIEdRIBXZHgui45NchHm7Q_/view?usp=sharing)

## Respositorios

- [Api](https://github.com/humbfei-fiap/soat-tech-challenge-fast-food-app)
- [Gtw + Lambda](https://github.com/humbfei-fiap/soat-tech-challenge-infra-gtw-lambda)
- [EKS](https://github.com/humbfei-fiap/soat-tech-challenge-infra-eks)
- [Postgres](https://github.com/humbfei-fiap/soat-tech-challenge-infra-postgres)
- [Roles](https://github.com/humbfei-fiap/soat-tech-challenge-infra-roles)


## Tecnologias Utilizadas

- Java 17
- Spring Boot 3.5.0
- Spring Data JPA
- PostgreSQL
- Docker
- Maven
- Swagger/OpenAPI

## Estrutura de Deploy na AWS EKS
```
infra/app/
├── 0_app_serviceaccount.yml # Define a conta de serviço para o pod da aplicação (usado para permissões IAM).
├── 1_app_namespace.yml      # Cria o namespace 'fastfood-app' para isolar os recursos.
├── 2_app_secret.yml         # Define parametros para buuscar o Secret na AWS Secrets Manager * Dados sensíveis* (Ex:credenciais de banco de dados).
├── 3_app_configmap.yml      # Armazena configurações não-sensíveis da aplicação como variáveis de ambiente.
├── 4_app_deployment.yml     # Descreve como a aplicação deve ser executada (imagem, réplicas, probes, etc.).
├── 5_app_service.yml        # Expõe a aplicação internamente no cluster com um nome DNS estável.
├── 6_app_hpa.yml            # Configura o Horizontal Pod Autoscaler para escalar a aplicação sob demanda.
└── ingress.yaml             # Define o ingresso para o NLB compartilhado para o NGINX Ingress Controller.

```

## Estrutura do Projeto

```
src/main/java/com/postechfiap_group130/techchallenge_fastfood/
│
├── api/                              # Camada de Interface
│   └── rest/controller/             # Controladores REST
│
├── application/                      # Lógica de Aplicação
│   ├── exceptions/                  # Exceções personalizadas
│   └── validation/                 # Validações de aplicação
│
├── config/                          # Configurações da aplicação
│
├── core/                            # Núcleo do Domínio
│   ├── controllers/                 # Controladores de negócio
│   ├── dtos/                       # Objetos de Transferência
│   ├── entities/                   # Entidades de Domínio
│   ├── gateways/                   # Implementações de portas de saída
│   ├── interfaces/                 # Portas (interfaces)
│   ├── presenters/                 # Conversores para DTOs
│   └── usecases/                   # Casos de Uso
│
├── mock_payment/                   # Simulação de pagamento
└── webhook/                       # Webhooks externos
```

## Funcionalidades

- Cadastro e gerenciamento de produtos
- Cadastro e gerenciamento de clientes
- Criação e acompanhamento de pedidos
- Checkout de pedidos
- Pagamento


Rotas


## Ordem para Execução das APIs

### 1. Gerenciamento de Produtos
```http
# 1.1 Criar um novo produto
POST /products/create
# 1.2 Listar produtos por categoria
GET /products/category/{category}
# 1.3 Atualizar um produto existente
PUT /products/update
```

### 2. Gerenciamento de Clientes
```http
# 2.1 Cadastrar um novo cliente
POST /customers/create
# 2.2 Buscar cliente por CPF
GET /customers/{cpf}
```

### 3. Gerenciamento de Pedidos
```http
# 3.1 Criar um novo pedido (checkout)
POST /orders/checkout
# 3.2 Listar todos os pedidos
GET /orders
# 3.3 Buscar pedido por ID
GET /orders/{order_id}
# 3.4 Atualizar status do pedido
PATCH /orders/{order_id}/status/{status}
```

### 4. Processamento de Pagamentos
```http
# 4.1 Criar pagamento
POST /payments/create
# 4.2 Verificar status do pagamento
GET /payments/{payment_id}/status
# 4.3 Atualizar status do pagamento (recebe a notificação webhook)
POST /payments/{payment_id}/status
```

### 5. Mock de Pagamento (Simulação)
```http
# 5.1 Simular atualização de status de pagamento
POST /mock/payments
```
