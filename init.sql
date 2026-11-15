-- Banco de demonstração. Os dados são sintéticos.
-- wal_level=logical é definido no docker-compose.yml antes da inicialização do servidor.

CREATE TABLE public.accounts (
    account_id BIGINT PRIMARY KEY,
    customer_name TEXT NOT NULL,
    risk_level TEXT NOT NULL CHECK (risk_level IN ('LOW', 'MEDIUM', 'HIGH')),
    created_at TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (CURRENT_TIMESTAMP(3) AT TIME ZONE 'UTC')
);

-- A transação é tratada como evento imutável no fluxo de fraude: uma linha nova = um pagamento.
-- Correções/cancelamentos devem ser modelados separadamente para evitar contar UPDATE como nova compra.
CREATE TABLE public.transactions (
    transaction_id BIGINT PRIMARY KEY,
    account_id BIGINT NOT NULL REFERENCES public.accounts(account_id),
    card_id TEXT NOT NULL,
    amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    status TEXT NOT NULL CHECK (status IN ('APPROVED', 'DECLINED', 'PENDING')),
    created_at TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL
);

-- Tabela auxiliar para demonstrar os três tipos de mudança CDC sem alterar eventos financeiros.
CREATE TABLE public.cdc_probe (
    id BIGINT PRIMARY KEY,
    message TEXT NOT NULL,
    updated_at TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT (CURRENT_TIMESTAMP(3) AT TIME ZONE 'UTC')
);

INSERT INTO public.accounts (account_id, customer_name, risk_level) VALUES
    (101, 'Cliente Exemplo A', 'LOW'),
    (202, 'Cliente Exemplo B', 'MEDIUM'),
    (303, 'Cliente Exemplo C', 'HIGH');

-- Três compras do mesmo cartão em 20 segundos: devem produzir um alerta quando a etapa Flink for ativada.
INSERT INTO public.transactions (transaction_id, account_id, card_id, amount, status, created_at) VALUES
    (1001, 101, 'CARD-ALPHA', 120.00, 'APPROVED', (CURRENT_TIMESTAMP AT TIME ZONE 'UTC') - INTERVAL '25 seconds'),
    (1002, 101, 'CARD-ALPHA', 240.00, 'APPROVED', (CURRENT_TIMESTAMP AT TIME ZONE 'UTC') - INTERVAL '15 seconds'),
    (1003, 101, 'CARD-ALPHA',  80.00, 'APPROVED', (CURRENT_TIMESTAMP AT TIME ZONE 'UTC') - INTERVAL '5 seconds'),
    (2001, 202, 'CARD-BETA',   35.00, 'APPROVED', (CURRENT_TIMESTAMP AT TIME ZONE 'UTC') - INTERVAL '20 seconds'),
    (2002, 202, 'CARD-BETA',   65.00, 'APPROVED', (CURRENT_TIMESTAMP AT TIME ZONE 'UTC') - INTERVAL '2 seconds');

INSERT INTO public.cdc_probe (id, message) VALUES (1, 'registro inicial para snapshot');
