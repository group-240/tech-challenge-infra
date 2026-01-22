# 📖 Guia de Uso - Tech Challenge Fast Food

Este guia descreve como utilizar o sistema de autoatendimento de fast food do ponto de vista de um **usuário final**, simulando o fluxo completo de negócio.

---

## 🎯 Visão Geral do Sistema

O Tech Challenge é um sistema de autoatendimento para lanchonetes que permite:

1. **Identificação do Cliente** - Por CPF (opcional)
2. **Visualização do Cardápio** - Produtos organizados por categoria
3. **Realização de Pedidos** - Montagem de combo personalizado
4. **Pagamento** - Via QR Code (MercadoPago)
5. **Acompanhamento** - Status do pedido em tempo real
6. **Preparo** - Cozinha recebe e prepara o pedido
7. **Entrega** - Cliente retira o pedido pronto

---

## 🌐 URL Base da API

```
https://{api-gateway-id}.execute-api.us-east-1.amazonaws.com/dev
```

> **Nota:** Substitua `{api-gateway-id}` pelo ID real do API Gateway. Você pode obtê-lo executando `terraform output api_gateway_url` no repositório `tech-challenge-gateway`.

---

## 📋 Fluxo Completo de Negócio

### Cenário: Cliente faz pedido completo

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   CLIENTE   │    │  COZINHA    │    │ MERCADO     │    │   ADMIN     │
│  (Totem)    │    │             │    │   PAGO      │    │  (Painel)   │
└──────┬──────┘    └──────┬──────┘    └──────┬──────┘    └──────┬──────┘
       │                  │                  │                  │
       │ 1. Identifica-se │                  │                  │
       │    por CPF       │                  │                  │
       │─────────────────▶│                  │                  │
       │                  │                  │                  │
       │ 2. Consulta      │                  │                  │
       │    Cardápio      │                  │                  │
       │◀─────────────────│                  │                  │
       │                  │                  │                  │
       │ 3. Monta Pedido  │                  │                  │
       │    (Produtos)    │                  │                  │
       │─────────────────▶│                  │                  │
       │                  │                  │                  │
       │ 4. Paga via      │                  │                  │
       │    QR Code       │─────────────────▶│                  │
       │                  │                  │                  │
       │                  │  5. Webhook      │                  │
       │                  │◀─────────────────│                  │
       │                  │                  │                  │
       │                  │ 6. Notifica      │                  │
       │                  │    Cozinha       │─────────────────▶│
       │                  │                  │                  │
       │                  │                  │    7. Atualiza   │
       │                  │◀─────────────────│───────Status─────│
       │                  │                  │                  │
       │ 8. Retira        │                  │                  │
       │    Pedido        │                  │                  │
       │◀─────────────────│                  │                  │
       │                  │                  │                  │
       ▼                  ▼                  ▼                  ▼
```

---

## 🚀 Etapas Detalhadas

### ETAPA 1: Identificação do Cliente (Opcional)

O cliente pode se identificar pelo CPF para acumular pontos ou receber promoções personalizadas.

#### 1.1 Cadastrar novo cliente (primeira vez)

```bash
# POST /customers
curl -X POST "https://{api-gateway-id}.execute-api.us-east-1.amazonaws.com/dev/customers" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "João Silva",
    "email": "joao.silva@email.com",
    "cpf": "12345678901"
  }'
```

**Resposta:**
```json
{
  "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "name": "João Silva",
  "email": "joao.silva@email.com",
  "cpf": "12345678901"
}
```

#### 1.2 Identificar-se por CPF (clientes recorrentes)

```bash
# POST /auth/cpf
curl -X POST "https://{api-gateway-id}.execute-api.us-east-1.amazonaws.com/dev/auth/cpf" \
  -H "Content-Type: application/json" \
  -d '{
    "cpf": "12345678901"
  }'
```

**Resposta:**
```json
{
  "success": true,
  "message": "CPF validado com sucesso",
  "cpf": "12345678901"
}
```

> **📝 Nota:** O CPF é validado no formato, mas não requer autenticação para usar a API.

---

### ETAPA 2: Consultar Cardápio

#### 2.1 Listar categorias disponíveis

```bash
# GET /categories (Público - não precisa de autenticação)
curl "https://{api-gateway-id}.execute-api.us-east-1.amazonaws.com/dev/categories"
```

**Resposta:**
```json
[
  {
    "id": "cat-001",
    "name": "Lanches"
  },
  {
    "id": "cat-002", 
    "name": "Acompanhamentos"
  },
  {
    "id": "cat-003",
    "name": "Bebidas"
  },
  {
    "id": "cat-004",
    "name": "Sobremesas"
  }
]
```

#### 2.2 Listar produtos

```bash
# GET /products (Público)
curl "https://{api-gateway-id}.execute-api.us-east-1.amazonaws.com/dev/products"
```

**Resposta:**
```json
[
  {
    "id": "prod-001",
    "name": "X-Bacon",
    "description": "Hambúrguer com bacon crocante, queijo e molho especial",
    "price": 25.90,
    "categoryId": "cat-001"
  },
  {
    "id": "prod-002",
    "name": "Batata Frita Grande",
    "description": "Porção generosa de batatas fritas",
    "price": 12.00,
    "categoryId": "cat-002"
  },
  {
    "id": "prod-003",
    "name": "Refrigerante 500ml",
    "description": "Coca-Cola, Guaraná ou Sprite",
    "price": 8.00,
    "categoryId": "cat-003"
  }
]
```

#### 2.3 Filtrar produtos por categoria

```bash
# GET /products/category/{categoryId}
curl "https://{api-gateway-id}.execute-api.us-east-1.amazonaws.com/dev/products/category/cat-001"
```

---

### ETAPA 3: Realizar Pedido

#### 3.1 Criar pedido (Combo personalizado)

```bash
# POST /orders
curl -X POST "https://{api-gateway-id}.execute-api.us-east-1.amazonaws.com/dev/orders" \
  -H "Content-Type: application/json" \
  -d '{
    "cpf": "12345678901",
    "items": [
      {
        "productId": "prod-001",
        "quantity": 1
      },
      {
        "productId": "prod-002",
        "quantity": 1
      },
      {
        "productId": "prod-003",
        "quantity": 2
      }
    ]
  }'
```

**Resposta:**
```json
{
  "id": 1001,
  "cpf": "12345678901",
  "items": [
    {
      "productId": "prod-001",
      "productName": "X-Bacon",
      "quantity": 1,
      "unitPrice": 25.90,
      "totalPrice": 25.90
    },
    {
      "productId": "prod-002",
      "productName": "Batata Frita Grande",
      "quantity": 1,
      "unitPrice": 12.00,
      "totalPrice": 12.00
    },
    {
      "productId": "prod-003",
      "productName": "Refrigerante 500ml",
      "quantity": 2,
      "unitPrice": 8.00,
      "totalPrice": 16.00
    }
  ],
  "totalAmount": 53.90,
  "status": "RECEIVED",
  "statusPayment": "PENDING",
  "createdAt": "2026-01-09T10:30:00Z"
}
```

> **📝 Anote:** O `id` do pedido (1001) será usado para acompanhamento e pagamento.

---

### ETAPA 4: Realizar Pagamento

#### 4.1 Criar ordem de pagamento (gera QR Code)

```bash
# POST /payments
curl -X POST "https://{api-gateway-id}.execute-api.us-east-1.amazonaws.com/dev/payments" \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 53.90,
    "description": "Pedido #1001 - Tech Challenge Fast Food",
    "paymentMethodId": "pix",
    "installments": 1,
    "payerEmail": "joao.silva@email.com",
    "identificationType": "CPF",
    "identificationNumber": "12345678901"
  }'
```

**Resposta:**
```json
{
  "id": "1325737896",
  "status": "pending",
  "qrCode": "00020126580014br.gov.bcb.pix0136...",
  "qrCodeBase64": "iVBORw0KGgoAAAANSUhEUgAA...",
  "expirationDate": "2026-01-09T11:30:00Z",
  "amount": 53.90
}
```

#### 4.2 Exibir QR Code para pagamento

O campo `qrCodeBase64` contém a imagem do QR Code em Base64. Exiba no totem para o cliente escanear com o app do banco.

```html
<!-- Exemplo de exibição -->
<img src="data:image/png;base64,{qrCodeBase64}" alt="QR Code PIX" />
```

#### 4.3 Verificar status do pagamento

```bash
# GET /payments/{paymentId}
curl "https://{api-gateway-id}.execute-api.us-east-1.amazonaws.com/dev/payments/1325737896"
```

**Resposta (aguardando):**
```json
{
  "id": "1325737896",
  "status": "pending"
}
```

**Resposta (aprovado):**
```json
{
  "id": "1325737896",
  "status": "approved",
  "dateApproved": "2026-01-09T10:35:00Z"
}
```

---

### ETAPA 5: Webhook de Confirmação (Automático)

Quando o pagamento é confirmado, o MercadoPago envia automaticamente uma notificação:

```bash
# POST /webhooks (Chamado pelo MercadoPago)
# Este endpoint é público - não requer autenticação
{
  "action": "payment.updated",
  "data": {
    "id": "1325737896"
  }
}
```

> **⚙️ Sistema automaticamente:**
> 1. Recebe a notificação
> 2. Verifica o status no MercadoPago
> 3. Atualiza o status do pedido para `APPROVED`
> 4. Libera o pedido para a cozinha

---

### ETAPA 6: Acompanhamento do Pedido

#### 6.1 Consultar status do pedido

```bash
# GET /orders/{orderId}
curl "https://{api-gateway-id}.execute-api.us-east-1.amazonaws.com/dev/orders/1001"
```

**Estados possíveis do pedido:**

| Status | Descrição | Exibição no Painel |
|--------|-----------|-------------------|
| `RECEIVED` | Pedido recebido | 🟡 Aguardando pagamento |
| `PENDING` | Pagamento pendente | 🟡 Aguardando pagamento |
| `APPROVED` | Pagamento aprovado | 🟢 Pago - Na fila |
| `IN_PREPARATION` | Em preparo na cozinha | 🔵 Preparando |
| `READY` | Pronto para retirada | ✅ Pronto! |
| `COMPLETED` | Entregue ao cliente | ✔️ Finalizado |

#### 6.2 Listar todos os pedidos (Admin/Cozinha)

```bash
# GET /orders
curl "https://{api-gateway-id}.execute-api.us-east-1.amazonaws.com/dev/orders"
```

#### 6.3 Filtrar pedidos por status (Painel da Cozinha)

```bash
# GET /orders?status=IN_PREPARATION
curl "https://{api-gateway-id}.execute-api.us-east-1.amazonaws.com/dev/orders?status=IN_PREPARATION"
```

---

### ETAPA 7: Preparo na Cozinha

#### 7.1 Iniciar preparo do pedido

```bash
# PUT /orders/{orderId}/status/preparation
curl -X PUT "https://{api-gateway-id}.execute-api.us-east-1.amazonaws.com/dev/orders/1001/status/preparation"
```

#### 7.2 Marcar pedido como pronto

```bash
# PUT /orders/{orderId}/status
curl -X PUT "https://{api-gateway-id}.execute-api.us-east-1.amazonaws.com/dev/orders/1001/status" \
  -H "Content-Type: application/json" \
  -d '{
    "status": "READY"
  }'
```

---

### ETAPA 8: Entrega ao Cliente

#### 8.1 Finalizar pedido (cliente retirou)

```bash
# PUT /orders/{orderId}/status
curl -X PUT "https://{api-gateway-id}.execute-api.us-east-1.amazonaws.com/dev/orders/1001/status" \
  -H "Content-Type: application/json" \
  -d '{
    "status": "COMPLETED"
  }'
```

---

## 🎮 Simulação Completa (Script)

Para testar o fluxo completo, execute os comandos na ordem:

```bash
# Configuração
API_URL="https://{api-gateway-id}.execute-api.us-east-1.amazonaws.com/dev"
CPF="12345678901"

# 1. Cadastrar cliente
curl -X POST "$API_URL/customers" \
  -H "Content-Type: application/json" \
  -d '{"name":"Cliente Teste","email":"teste@email.com","cpf":"'$CPF'"}'

# 2. Autenticar por CPF (apenas validação de formato)
curl -s -X POST "$API_URL/auth/cpf" \
  -H "Content-Type: application/json" \
  -d '{"cpf":"'$CPF'"}'

# 3. Ver cardápio
curl "$API_URL/categories"
curl "$API_URL/products"

# 4. Criar pedido
ORDER=$(curl -s -X POST "$API_URL/orders" \
  -H "Content-Type: application/json" \
  -d '{"cpf":"'$CPF'","items":[{"productId":"prod-001","quantity":1}]}')

ORDER_ID=$(echo $ORDER | jq -r '.id')
echo "Pedido criado: $ORDER_ID"

# 5. Criar pagamento
curl -X POST "$API_URL/payments" \
  -H "Content-Type: application/json" \
  -d '{"amount":25.90,"description":"Pedido #'$ORDER_ID'","paymentMethodId":"pix","installments":1,"payerEmail":"teste@email.com","identificationType":"CPF","identificationNumber":"'$CPF'"}'

# 6. Acompanhar pedido
curl "$API_URL/orders/$ORDER_ID"
```

---

## 📊 Diagrama de Estados do Pedido

```
                                    ┌─────────────────────┐
                                    │                     │
                                    ▼                     │
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│ RECEIVED │────▶│ PENDING  │────▶│ APPROVED │────▶│IN_PREPAR.│────▶│  READY   │
│          │     │          │     │          │     │          │     │          │
│ (Pedido  │     │(Aguarda  │     │(Pagamento│     │(Cozinha  │     │ (Pronto  │
│ criado)  │     │pagamento)│     │confirmado)│    │prepara)  │     │  retirar)│
└──────────┘     └──────────┘     └──────────┘     └──────────┘     └────┬─────┘
                                                                         │
                                                                         ▼
                                                                   ┌──────────┐
                                                                   │COMPLETED │
                                                                   │          │
                                                                   │(Entregue │
                                                                   │ao cliente│
                                                                   └──────────┘
```

---

## 🔐 Resumo de Autenticação

| Endpoint | Método | Autenticação |
|----------|--------|--------------|
| `/auth/cpf` | POST | ❌ Não |
| `/categories` | GET | ❌ Público |
| `/products` | GET | ❌ Público |
| `/health` | GET | ❌ Público |
| `/webhooks` | POST | ❌ Público |
| `/customers` | POST | ❌ Público |
| `/customers` | GET | ❌ Público |
| `/orders` | GET/POST | ❌ Público |
| `/payments` | POST | ❌ Público |

> **⚠️ Nota:** Todas as rotas são públicas. A API não requer autenticação.

---

## ❓ FAQ

### O CPF é obrigatório para fazer pedidos?
Não. A identificação por CPF é opcional e serve apenas para validação de formato no Lambda.

### O que acontece se o pagamento não for confirmado?
O pedido permanece com status `PENDING` e não é enviado para a cozinha.

### Posso fazer pedido sem me identificar?
Sim, a identificação por CPF é opcional. Basta não enviar o CPF no pedido.

### Como a cozinha sabe que tem pedido novo?
A cozinha monitora o endpoint `GET /orders?status=APPROVED` para ver pedidos pagos aguardando preparo.

---

## 📞 Suporte

Em caso de dúvidas ou problemas, consulte:
- [Documentação de Arquitetura](./ARCHITECTURE.md)
- [README do repositório](./README.md)
