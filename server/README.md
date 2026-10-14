# API do WaxClub — `https://api.waxclub.com.br`

PHP 8 + MySQL na Hostinger (plano Business). Pasta no servidor: `domains/waxclub.com.br/public_html/api` (subdomínio `api`).
As tabelas são criadas sozinhas na primeira requisição (migrações em `api/lib/bootstrap.php`, versão na tabela `meta`).

## Configuração
O arquivo `waxclub.env` (modelo em `waxclub.env.example`) fica **fora** da pasta pública, em
`domains/waxclub.com.br/waxclub.env`, e é escrito pelo usuário no Gerenciador de Arquivos do hPanel (a senha do banco nunca vai para o código).

## Endpoints (JSON; rotas com 🔒 pedem `Authorization: Bearer <token>`)
| Método | Rota | O que faz |
|---|---|---|
| GET | `/v1/health` | Estado da API e versão do esquema do banco |
| POST | `/v1/auth/email/start` | `{email}` → envia um código de 6 dígitos (vale 15 min; até 5 por hora por e-mail) |
| POST | `/v1/auth/email/verify` | `{email, code, device?}` → `{token, user}` (cria a conta no primeiro login) |
| POST | `/v1/auth/google` | `{idToken, device?}` → `{token, user}` (precisa de `GOOGLE_CLIENT_IDS`) |
| POST 🔒 | `/v1/auth/logout` | Encerra a sessão atual |
| GET / PATCH / DELETE 🔒 | `/v1/me` | Ver, editar (`displayName`, `city`) ou apagar a conta com todos os dados |
| GET 🔒 | `/v1/collection?since=ISO` | Coleção; com `since`, só o que mudou (inclui apagados) |
| POST 🔒 | `/v1/collection/sync` | `{items:[...]}` envio em lote (até 500); o mais recente (`updatedAt`) vence |
| PUT / DELETE 🔒 | `/v1/collection/{key}` | Grava ou apaga um disco (chave = `CollectionService.keyFor`) |
| POST / GET 🔒 | `/v1/plays` | Audições: envio em lote (repetidas ignoradas) e leitura incremental |

Os campos dos discos são os mesmos do `CollectionItem` do app (`album`, `artist`, `coverUrl`, `year`, `format`,
`discogsReleaseId`, `musicBrainzReleaseId`, `label`, `catalogNumber`, `barcode`, `addedAt`, `rating`,
`mediaCondition`, `sleeveCondition`, `notes`) mais `updatedAt` e `deleted`.

## Publicação
Os arquivos de `api/` são enviados um a um para `public_html/api/` pelo plugin da Hostinger (upload TUS), sem apagar o resto do site.
