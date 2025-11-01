# Desafio DIO - Criando Banco de Dados MySQL via Script
## Descrição do Desafio

O objetivo deste projeto é replicar e implementar a modelagem lógica de banco de dados para um cenário de e-commerce, aplicando os conceitos estudados de modelagem conceitual, refinamentos e mapeamento lógico para o MySQL.

Durante o desafio, foram desenvolvidos:

O script SQL para criação do esquema do banco de dados;

Scripts para persistência e manipulação dos dados;

Consultas SQL com diferentes níveis de complexidade.

```
As triggers neste projeto têm como objetivo:

- Garantir que **regras de estoque e pedidos** sejam respeitadas.  
- Evitar inserções inconsistentes (ex: pedidos com produtos sem estoque).  
- Automatizar atualizações entre tabelas relacionadas (ex: ajustar quantidades, status, etc).  
- Registrar e manter a integridade de dados de forma automática.

```

### Estrutura do Projeto
```
📦 dio-lab-mysql-criando-db-via-script
 ┣ 📜 CREATE_DATABASE_eCommerce.txt     # Criação do banco de dados e tabelas
 ┣ 📜 eCommerce_queries.sql             # Triggers, inserts e consultas SQL
 ┗ 📘 README.md                         # Descrição do projeto
```
