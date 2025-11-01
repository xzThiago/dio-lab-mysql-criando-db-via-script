use eCommerce;

/*
1. Atualização automática de estoque ao registrar pedidos
Tabela: Relacao_Produto_Pedido

AFTER INSERT
Quando um produto for vendido em um pedido, diminuir o estoque automaticamente.
*/
CREATE TRIGGER trg_atualiza_estoque_after_insert
AFTER INSERT ON Relacao_Produto_Pedido
FOR EACH ROW
UPDATE Produto_has_Estoque
SET Quantidade = Quantidade - New.Quantidade
WHERE ID_Produto = New.ID_Produto;

/*
Estornar estoque se um pedido for apagado
AFTER DELETE - Relacao_Produto_Pedido
*/
CREATE TRIGGER trg_estorna_estoque_after_delete
AFTER DELETE ON Relacao_Produto_Pedido
FOR EACH ROW
UPDATE Produto_has_Estoque
SET Quantidade = Quantidade + OLD.Quantidade
WHERE ID_Produto = OLD.ID_Produto;

/*
Impedir pedidos com produtos sem estoque
BEFORE INSERT - Relacao_Produto_Pedido
*/
#DROP TRIGGER IF EXISTS trg_bloqueia_sem_estoque;
DELIMITER $$
CREATE TRIGGER trg_bloqueia_sem_estoque
BEFORE INSERT ON Relacao_Produto_Pedido
FOR EACH ROW
BEGIN
    DECLARE qtd_estoque INT DEFAULT 0;

    SELECT COALESCE(Quantidade, 0) INTO qtd_estoque
    FROM Produto_has_estoque
    WHERE ID_Produto = NEW.ID_Produto;

    IF qtd_estoque < NEW.Quantidade THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Estoque insuficiente para este produto';
    END IF;
END$$
DELIMITER ;

/*
CALCULAR VALOR TOTAL DO ITEM AUTOMATICAMENTE
BEFORE INSERT - Relacao_Produto_Pedido
*/
DELIMITER $$
CREATE TRIGGER trg_valor_total_item
BEFORE INSERT ON Relacao_Produto_Pedido
FOR EACH ROW
BEGIN
    SET NEW.Valor_Total = NEW.Quantidade * NEW.Valor_Unit;
END;

DELIMITER ;

/*
IMPEDIR EXCLUSAO DE CLIENTE COM PEDIDOS
BEFORE DELETE - Cliente
*/
DELIMITER $$
CREATE TRIGGER trg_bloqueia_delete_cliente
BEFORE DELETE ON Cliente
FOR EACH ROW
BEGIN 
	IF EXISTS(SELECT 1 FROM Pedido WHERE ID_Cliente = OLD.ID_Cliente) THEN
		SIGNAL SQLSTATE '45000'
        SET message_text = 'Cliente possui pedidos, não pode ser excluído.';
	END IF;
END$$
DELIMITER ;


/*
HISTÓRICO DE ALTERAÇÕES DE ESTQOUE - AUDITORIA
CREIANDO TABELA "Log_Estoque" e sua trigger
*/
CREATE TRIGGER trg_log_estoque
AFTER UPDATE ON Produto_has_Estoque
FOR EACH ROW
INSERT INTO Log_Estoque(ID_Produto, Quantidade_Antiga, Quantidade_Nova, Data)
VALUES (OLD.ID_Produto, OLD.Quantidade, NEW.Quantidade, NOW());


/*
TRIGGER PARA REMOVER OS PRODUTOS DO ESTOQUE QUANDO UM PEDIDO É CRIADO 
STATUS = 'Processando'
*/
DELIMITER $$
CREATE TRIGGER trg_baixa_estoque_ao_criar_pedido
AFTER INSERT ON Pedido
FOR EACH ROW
BEGIN
	IF NEW.Status_Pedido = 'Processando' THEN
		UPDATE Produto_has_Estoque pe 
        JOIN Relacao_Produto_Pedido rp
			ON pe.ID_Produto = rp.Produto
		SET pe.Quantidade = pe.Quantidade - rp.Quantidade
        WHERE rp.ID_Pedido = NEW.ID_Pedido;
	END IF;
END$$
DELIMITER ;

/*
SE O PEDIDO MUDAR PARA "CANCELADO", DEVOLVE A QUANTIDADE DOS PRODUTOS PARA O ESTOQUE
*/
DELIMITER $$
CREATE TRIGGER trg_estorna_estoque_cancelamento
AFTER update ON Pedido
FOR EACH ROW
BEGIN
	IF NEW.Status_Pedido = 'Cancelado'
		AND OLD.Status_Pedido <> 'Cancelado' THEN
        
        UPDATE Produto_has_estoque pe
        JOIN Relacao_Produto_Pedido rp
        ON pe.ID_Produto = rp.ID_Produto
        SET pe.Quantidade = pe.Quantidade + re.Quantidade
        WHERE rp.ID_Pedido = New.ID_Pedido;
	END IF;
END$$
DELIMITER ;

/*
VALIDACAO: IMPEDIIR PEDIDO "PROCESSANDO" SE NÃO HOUBER ESTOQUE
*/
DELIMITER $$
CREATE TRIGGER trg_bloqueia_sem_estoque
BEFORE UPDATE ON Pedido
FOR EACH ROW
BEGIN
	DECLARE qtd_invalida INT;
	IF NEW.Status_Pedido = 'Processando' THEN
        SELECT COUNT(*) INTO qtd_invalida
        FROM Relacao_Produto_Pedido rp
        JOIN Produto_has_Estoque pe
			ON pe.ID_Produto = rp.ID_Produto
		AND pe.Quantidade < rp.Quantidade
        WHERE rp.ID_Pedido = NEW.ID_Pedido;
        
        IF qtd_invalida > 0 THEN
			SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Estoque insuficiente para um ou maisi produtos desse pedido';
		END IF;
	END IF;
END$$
DELIMITER ;

SHOW triggers;

/*
IMPEDIR EXLUSÃO DE PEDIDOS
*/
DELIMITER $$
CREATE TRIGGER trg_impede_delete
BEFORE DELETE ON Pedido
FOR EACH ROW
BEGIN 
	IF OLD.Status_Pedido THEN
		signal SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Não é permitido exluir um pedido.';
	END IF;
END$$
DELIMITER ;

### EXCLUSÃO DAS TRIGGERS:
DROP TRIGGER IF EXISTS trg_atualiza_estoque_after_insert;
DROP TRIGGER IF EXISTS trg_estorna_estoque_after_delete;
DROP TRIGGER IF EXISTS trg_bloqueia_sem_estoque;
DROP TRIGGER IF EXISTS trg_valor_total_item;
DROP TRIGGER IF EXISTS trg_bloqueia_delete_cliente;
DROP TRIGGER IF EXISTS trg_log_estoque;
DROP TRIGGER IF EXISTS trg_baixa_estoque_ao_criar_pedido;
DROP TRIGGER IF EXISTS trg_estorna_estoque_cancelamento;
DROP TRIGGER IF EXISTS trg_bloqueia_sem_estoque;
DROP TRIGGER IF EXISTS trg_impede_delete;

########################################################
## INSERINDO DADOS NAS TABELAS;

-- ======= CLIENTE =======
INSERT INTO Cliente (ID_Cliente, Nome, CPF, Dt_Nascimento, Endereco) VALUES
(1, 'Thiago Silva', '08451239870', '1990-05-10', 'Rua Centro, 120 - Recife'),
(2, 'Maria Souza', '07412589630', '1984-11-21', 'Av Brasil, 200 - Olinda'),
(3, 'João Santos', '03692581470', '1995-02-07', 'Rua Aurora, 77 - Paulista'),
(4, 'Ana Costa', '05214796311', '1988-08-12', 'Rua das Flores, 45 - Recife'),
(5, 'Carlos Almeida', '01987543210', '1979-03-03', 'Av Pernambuco, 300 - Paulista'),
(6, 'Larissa Monteiro', '02345678901', '1993-07-22', 'Rua Vitoriosa, 9 - Olinda'),
(7, 'Pedro Azevedo', '04567891234', '1987-01-15', 'Praça Central, 10 - Recife'),
(8, 'Bruna Ferreira', '06789012345', '1996-12-01', 'Rua Nova, 55 - Paulista');

-- ======= FORNECEDOR =======
INSERT INTO Fornecedor (ID_Fornecedor, Razao_Social, CNPJ) VALUES
(1, 'Tech Importações LTDA', '12345678000190'),
(2, 'Super Distribuidora SA', '22111333000180'),
(3, 'Brasil Eletronics ME', '55222444000155');

-- ======= ESTOQUE =======
INSERT INTO Estoque (ID_Estoque, Local) VALUES
(1, 'Armazém Recife'),
(2, 'Armazém Paulista'),
(3, 'Armazém Olinda');

-- ======= PRODUTO =======
INSERT INTO Produto (ID_Produto, Nome_Produto, Categoria, Valor_Produto) VALUES
(1, 'Mouse Gamer RGB', 'Eletrônicos', 120.00),
(2, 'Teclado Mecânico', 'Eletrônicos', 280.00),
(3, 'Câmera Web HD', 'Eletrônicos', 180.00),
(4, 'Monitor 24 Full HD', 'Eletrônicos', 850.00),
(5, 'Caixa de Som Bluetooth', 'Eletrônicos', 150.00),
(6, 'Relógio Masculino', 'Acessórios', 120.00),
(7, 'Pulseira de Prata', 'Acessórios', 90.00),
(8, 'Colar Feminino', 'Acessórios', 150.00),
(9, 'Anel de Ouro', 'Acessórios', 350.00),
(10,'Brinco Folheado', 'Acessórios', 60.00),
(11,'Carregador USB-C 65W', 'Eletrônicos', 95.00),
(12,'Cabo HDMI 2m', 'Eletrônicos', 25.00);

-- ======= PRODUTO_HAS_ESTOQUE =======

SELECT * FROM INFORMATION_SCHEMA.table_constraints where table_schema = 'eCommerce';
ALTER TABLE Produto_has_Estoque DROP index ID_Estoque_UNIQUE;
ALTER TABLE Produto_has_Estoque DROP index ID_Produto_UNIQUE;

ALTER TABLE Produto_has_Estoque ADD CONSTRAINT pk_Produto_has_Estoque primary key(ID_Produto, ID_Estoque);

-- (ID_Produto, ID_Estoque, Quantidade)
INSERT INTO Produto_has_Estoque (ID_Produto, ID_Estoque, Quantidade) VALUES
(1, 1, 50),
(2, 1, 40),
(3, 1, 25),
(4, 2, 20),
(5, 2, 15),
(6, 3, 50),
(7, 3, 35),
(8, 3, 12),
(9, 1, 45),
(10,2, 17),
(11,1, 60),
(12,2, 120),
(1, 2, 30),   -- também no estoque 2
(5, 3, 10);  -- também disponível no estoque 3

-- ======= DISPONIBILIZANDO_PRODUTO (Fornecedor -> Produto) =======
INSERT INTO Disponibilizando_Produto (ID_Fornecedor, ID_Produto) VALUES
(1, 1),(1, 2),(1, 5),(1, 6),(1, 10),
(2, 3),(2, 4),(2, 9),(2, 11),(2, 12),
(3, 1),(3, 5),(3, 8);


SELECT * FROM Terceiro_Vendedor;
-- ======= TERCEIRO_VENDEDOR =======
INSERT INTO Terceiro_Vendedor (ID_Terceiro_Vendedor, Razao_Social, Nome_Fantasia, Local) VALUES
(1, 'Loja GameMax LTDA', 'GameMax', 'Recife'),
(2, 'EletronicHouse SA', 'EletronicHouse', 'Paulista'),
(3, 'CenterTech LTDA', 'CenterTech', 'Olinda');

-- ======= PRODUTOS_POR_VENDEDOR_TERCEIRO =======
INSERT INTO Produtos_Por_Vendedor_terceiro (ID_Vendedor_Terceiro, ID_Produto, Quantidade) VALUES
(1, 1, 10),
(1, 2, 5),
(2, 3, 8),
(2, 4, 12),
(3, 5, 15),
(3, 10, 20),
(1, 11, 6),
(2, 12, 30);

-- ======= PEDIDO =======
-- Status_Pedido values: 'Processando','Cancelado','Enviado','Entregue'
INSERT INTO Pedido (ID_Pedido, Status_Pedido, Descricao, ID_Cliente, Valor_Frete) VALUES
(100, 'Processando', 'Pedido eletrônico', 1, 20.00),
(101, 'Enviado', 'Pedido urgente', 2, 25.00),
(102, 'Cancelado', 'Pedido cancelado pelo cliente', 1, 0.00),
(103, 'Processando', 'Compra via site', 3, 15.00),
(104, 'Enviado', 'Presentes de aniversário', 4, 10.00),
(105, 'Cancelado', 'Cliente desistiu', 2, 12.00),
(106, 'Entregue', 'Entrega realizada', 4, 20.00),
(107, 'Processando', 'Compra com desconto', 5, 8.00),
(108, 'Entregue', 'Compra promocional', 6, 15.00),
(109, 'Processando', 'Novo pedido aguardando', 7, 18.00),
(110, 'Processando', 'Pedido teste de integração', 8, 10.00);

-- ======= RELACAO_PRODUTO_PEDIDO =======
-- (ID_Produto, ID_Pedido, Quantidade, Valor_Unit, Valor_Total)
INSERT INTO Relacao_Produto_Pedido (ID_Produto, ID_Pedido, Quantidade, Valor_Unit, Valor_Total) VALUES
-- Pedido 100
(1, 100, 2, 120.00, 240.00),
(2, 100, 1, 280.00, 280.00),

-- Pedido 101
(3, 101, 1, 180.00, 180.00),
(4, 101, 2, 850.00,1700.00),

-- Pedido 102 (cancelado)
(1, 102, 1, 120.00, 120.00),

-- Pedido 103
(5, 103, 2, 150.00, 300.00),
(11,103,1, 95.00, 95.00),

-- Pedido 104
(7, 104, 1, 90.00, 90.00),

-- Pedido 105 (cancelado)
(12,105,2, 25.00, 50.00),

-- Pedido 106 (entregue)
(9, 106, 1, 350.00, 350.00),

-- Pedido 107
(10,107,2, 60.00, 120.00),
(2, 107,1, 280.00, 280.00),

-- Pedido 108 (entregue)
(10,108,2, 60.00, 120.00),

-- Pedido 109
(1, 109, 1, 120.00, 120.00),
(8, 109, 1, 150.00, 150.00),

-- Pedido 110
(11,110,1, 95.00, 95.00),
(12,110,2, 25.00, 50.00);


##### CASES;

-- Quantos pedidos NÃO CANCELADOS foram feitos por cada cliente?
SELECT
	c.Nome,
    COUNT(p.ID_Pedido) AS total_pedido_cliente
FROM Cliente c
JOIN Pedido p
	ON c.ID_Cliente = p.ID_Cliente
WHERE p.Status_Pedido <> 'Cancelado'
GROUP BY c.Nome
ORDER BY total_pedido_cliente DESC;

-- Retorne o total de pedidos CANCELADOS por cada cliente
SELECT
	c.Nome,
    COUNT(p.ID_Pedido) AS total_pedido_cliente
FROM Cliente c
JOIN Pedido p
	ON c.ID_Cliente = p.ID_Cliente
WHERE p.Status_Pedido = 'Cancelado'
GROUP BY c.Nome
ORDER BY total_pedido_cliente DESC;

-- Algum vendedor também é fornecedor?
SELECT 
	tv.Razao_Social as razao_social_vendedor,
    f.Razao_Social as razao_social_fornecedor
FROM terceiro_vendedor tv
JOIN produtos_por_vendedor_terceiro ptv
	ON tv.ID_Terceiro_Vendedor = ptv.ID_Vendedor_Terceiro
JOIN disponibilizando_produto dp
	ON ptv.ID_Produto = dp.ID_Produto
JOIN fornecedor f
	ON dp.ID_Fornecedor = f.ID_Fornecedor
WHERE tv.Razao_Social = f.Razao_Social;

-- Relação de produtos fornecedores e estoques;
SELECT DISTINCT
	f.Razao_Social,
    f.CNPJ AS CNPJ_Fornecedor,
    e.Local AS Local_Estoque
FROM fornecedor AS f
INNER JOIN disponibilizando_produto AS dp
	ON f.ID_Fornecedor = dp.ID_Fornecedor
INNER JOIN produto_has_estoque AS phe
	ON dp.ID_Produto = phe.ID_produto
INNER JOIN estoque AS e
	ON phe.ID_Estoque = e.ID_Estoque;

-- Relação de nomes dos fornecedores, nomes dos produtos e com estoque maior que 100;
SELECT
	f.Razao_Social,
    p.Nome_Produto,
    SUM(phe.Quantidade) as Total_qtd_estoque
FROM fornecedor AS f
INNER JOIN disponibilizando_produto AS dp
	ON f.ID_Fornecedor = dp.ID_Fornecedor
INNER JOIN produto_has_estoque AS phe
	ON dp.ID_Produto = phe.ID_produto
INNER JOIN Produto AS p
	ON dp.ID_Produto = p.ID_Produto
GROUP BY 
	f.Razao_Social,
    p.Nome_Produto
HAVING SUM(phe.Quantidade) > 100
ORDER BY f.Razao_Social, Total_qtd_estoque DESC;

