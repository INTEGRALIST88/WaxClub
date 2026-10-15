# Proposta — Brain (chaves de IA do usuário, modelo BYOK)

*15/10/2026 · status: aguardando aprovação*

## 1. Conceito

O **Brain** é a página onde o usuário "encaixa" chaves de IA (**BYOK**: cada usuário traz a própria chave). Os plugins de IA (categoria **A**: A1 Curiosidades, A2 Tradução e os próximos) usam o Brain e não guardam chave nenhuma.

- **Botão:** bloco de madeira com cérebro cromado (`assets/images/btn_brain.png`), na mesma fileira de botões da tela principal (Manual, My Collection, Plugins, Help).
- **Página:** um cérebro com **soquetes de chip**, como na imagem de referência.
  - Soquete vazio: pulsa suavemente, com o rótulo "Toque para encaixar".
  - Chip encaixado: acende na cor do provedor, com o logo dele.
  - Selo **Grátis** ou **Pago** em cada chip.
- **Plugin de IA instalado sem nenhum chip:** o app avisa "Este plugin precisa de um Brain" e abre o Brain com o chip recomendado piscando.
- **Mais de um chip encaixado:** a ordem dos chips é a prioridade (arrastar para ordenar, como no painel de plugins). Se um chip estourar o limite do dia, o próximo assume sozinho.

## 2. Provedores (chips)

| Chip | Grátis? | Cartão? | Página da chave (abrir no Chrome) | Formato da chave | Validação (chamada gratuita) |
|---|---|---|---|---|---|
| **Google Gemini** ★ recomendado | Sim (modelos Flash/Flash-Lite, limite diário) | Não | `aistudio.google.com/apikey` | `AIza…` (39 caracteres) | `GET generativelanguage.googleapis.com/v1beta/models?key=…` |
| **Groq** | Sim (modelos abertos, limite por modelo) | Não | `console.groq.com/keys` | `gsk_…` | `GET api.groq.com/openai/v1/models` |
| **OpenRouter** | Sim (lista de modelos grátis, limite diário) | Não | `openrouter.ai/settings/keys` | `sk-or-v1-…` | `GET openrouter.ai/api/v1/key` |
| **Mistral** | Sim (plano gratuito) | Não | `console.mistral.ai/api-keys` | 32 letras/números, sem prefixo | `GET api.mistral.ai/v1/models` |
| **OpenAI** | Não (pré-pago) | Sim | `platform.openai.com/api-keys` | `sk-proj-…` / `sk-…` | `GET api.openai.com/v1/models` |
| **Anthropic (Claude)** | Não (pré-pago) | Sim | console da Anthropic → API keys | `sk-ant-…` | `GET api.anthropic.com/v1/models` |
| **xAI (Grok)** | Não (cobra por uso; às vezes crédito promocional) | Sim | `console.x.ai` | `xai-…` | `GET api.x.ai/v1/models` |

- ChatGPT e Grok **gratuitos** são os apps de conversa; a **API** (o que o plugin usa) é cobrada à parte.
- Os endereços e formatos acima devem ser conferidos na implementação, porque os provedores mudam as páginas.
- **Primeira versão:** Gemini, Groq e OpenRouter, todos grátis. Os chips pagos entram depois, ou já aparecem como "Pago — em breve".

## 3. Encaixe guiado (pensado para leigos)

1. **Escolher o chip:** o usuário toca num soquete vazio → escolhe o chip (lista com Grátis primeiro).
2. **Tela-guia de 3 passos**, com ilustração do botão que vai aparecer na página do provedor:
   - (1) entre com sua conta (Google serve para o Gemini);
   - (2) toque em **Create API key**;
   - (3) toque em **Copiar** e volte ao WaxClub.
3. **Abrir a página de chaves:** o app abre a página **no navegador do celular** (Chrome Custom Tab), e não no navegador do app.
   - **Motivo:** o Google bloqueia o "Entrar com Google" dentro de navegadores embutidos, e OpenAI/Anthropic mostram a chave **uma única vez**.
   - A captura usada no Discogs (ler a página) não funcionaria aqui.
4. **Ao voltar ao app:** ele lê a área de transferência, reconhece o formato da chave e pergunta "Encaixar esta chave do Gemini?".
5. **Validação:** o app valida com a chamada gratuita da tabela → animação do chip encaixando e acendendo.
6. **Limpeza:** em seguida o app limpa a área de transferência, para a chave não ficar exposta.
7. **Reserva:** se nada for detectado, aparece o campo "Colar chave" com o botão de colar.

**Estados do chip:**
- verde: pronto;
- amarelo: limite do dia atingido, volta amanhã;
- vermelho: chave recusada, com o botão "Trocar chave";
- cinza: sem internet.

## 4. Como os plugins usam o Brain

- O plugin de IA declara no catálogo `requiresBrain: true`. Ao instalar ou ligar o plugin, o app verifica o Brain (ver seção 1).
- **`BrainService.complete(tarefa, texto)`:**
  - chama o primeiro chip disponível;
  - em `429` (limite) ou `401` (chave inválida), marca o chip e passa ao próximo.
- **Três adaptadores cobrem todos os provedores:**
  1. **OpenAI-compatível** (`/chat/completions`): OpenAI, Groq, OpenRouter, Mistral, xAI;
  2. **Gemini** (`generateContent`);
  3. **Anthropic** (`/v1/messages`).
- **Modelo:** cada chip usa um modelo barato/rápido por padrão (ex.: Gemini Flash-Lite). O usuário não escolhe modelo na primeira versão.
- **Chamadas:** saem **do celular direto ao provedor**, sem passar pelo servidor do WaxClub (sem custo de servidor e sem a chave trafegando por ele a cada uso).

## 5. Armazenamento das chaves

**No celular:** no cofre do Android (`flutter_secure_storage`), como o token do Discogs. É dali que as chamadas saem.

**No servidor (Hostinger), vinculado à conta**, para os chips continuarem lá ao trocar de celular ou reinstalar:

```sql
CREATE TABLE brain_keys (
  user_id       BIGINT UNSIGNED NOT NULL,
  provider      VARCHAR(20) NOT NULL,          -- gemini, groq, openrouter, mistral, openai, anthropic, xai
  position      TINYINT UNSIGNED NOT NULL,     -- ordem = prioridade
  key_cipher    VARBINARY(512) NOT NULL,       -- chave criptografada (libsodium secretbox)
  key_nonce     VARBINARY(24) NOT NULL,
  key_hint      VARCHAR(8) NOT NULL,           -- últimos 4 caracteres, para mostrar "…a1b2"
  status        VARCHAR(12) NOT NULL DEFAULT 'ok',
  validated_at  DATETIME NULL,
  updated_at    DATETIME NOT NULL,
  PRIMARY KEY (user_id, provider)
);
```

- **Criptografia:**
  - A chave de criptografia (`BRAIN_SECRET`) fica no `waxclub.env`, **fora do banco e fora do `public_html`**. Quem copiar só o banco não consegue usar as chaves.
  - O `waxclub.env` é escrito pelo usuário, como hoje.
- **API:**
  - `GET /v1/brain` — lista os chips sem as chaves, só o `key_hint`;
  - `PUT /v1/brain/{provider}` — encaixa ou troca;
  - `GET /v1/brain/{provider}/key` — devolve a chave **só ao dono**, com sessão válida e limite de pedidos;
  - `DELETE /v1/brain/{provider}` — desencaixa;
  - `PUT /v1/brain/order` — reordena.
- **Segurança:**
  - nada de chave em log (nem do PHP nem do app);
  - **excluir a conta** apaga todas as chaves;
  - "desencaixar" apaga a chave no servidor e no celular.
- **Esquema:** a tabela entra como a migração 6 (`migrate()` em `server/api/lib/bootstrap.php`).

## 6. Privacidade e consentimento

- **Antes do primeiro envio à IA:** aviso único dizendo:
  - o que é enviado (nome do disco, faixa, letra para traduzir…);
  - para qual provedor vai;
  - que, **nos planos gratuitos, o provedor pode usar o conteúdo para treinar modelos**.
- **Botão "Denunciar resposta"** em todo conteúdo gerado por IA, exigência da Google Play para apps com IA generativa.
- **Política de privacidade (site):** nova seção sobre o Brain, cobrindo o que é guardado, onde, como é criptografado e como apagar.

## 7. Lojas oficiais (checklist)

**Google Play**
- [ ] **Data safety:** declarar "credenciais de serviços de terceiros", guardadas criptografadas, sincronizadas com a conta e apagáveis.
- [ ] **Data safety:** declarar o envio de dados a provedores de IA (compartilhamento a pedido do usuário).
- [ ] Política de conteúdo gerado por IA: denunciar resposta, e o app não gera conteúdo proibido (prompts fixos por tarefa, sem chat livre na primeira versão).
- [ ] A exclusão de conta (já exigida) apaga as chaves.
- [ ] Sem raspar páginas de terceiros para obter as chaves: o encaixe é feito pelo usuário (copiar → app detecta). Isso evita enquadramento como coleta indevida de credenciais.

**Apple (se houver versão iOS)**
- [ ] Permissão explícita antes de enviar dados pessoais a IA de terceiros (diretriz 5.1.2).
- [ ] BYOK é permitido; o WaxClub não vende crédito de IA por fora da compra dentro do app.

**Provedores**
- Uso da chave do próprio usuário num app de terceiros é permitido.
- O app nunca compartilha a chave de um usuário com outro.

## 8. Riscos

| Risco | Mitigação |
|---|---|
| Vazamento das chaves no servidor | Criptografia com segredo fora do banco; chave nunca em log; servidor só devolve ao dono |
| Limites grátis mudam/diminuem | Vários chips com troca automática; mensagens claras (chip amarelo) |
| Provedor muda a página da chave | A tela-guia é texto/ilustração fácil de atualizar; detecção pela área de transferência não depende da página |
| Usuário leigo trava no meio | Tela-guia, chip recomendado único (Gemini), campo colar como reserva, ajuda no Help |
| Custo inesperado em chip pago | Selo "Pago", aviso antes de encaixar, modelo barato por padrão |
| Direitos autorais (tradução de letra) | Tradução continua no site, como já planejado; no app, IA para curiosidades/contexto |

## 9. Fases sugeridas

1. **Brain v1:**
   - botão e página com soquetes;
   - chips Gemini, Groq e OpenRouter;
   - encaixe guiado pelo Chrome com detecção da área de transferência;
   - validação;
   - chaves só no celular.
2. **Sincronização:** tabela `brain_keys`, criptografia e API `/v1/brain`.
3. **Plugins:**
   - `requiresBrain`;
   - `BrainService` com troca automática;
   - **A1 Curiosidades** como primeiro plugin a usar o Brain;
   - aviso de consentimento e "Denunciar resposta".
4. **Chips pagos:** OpenAI, Claude e Grok, com o aviso de custo.
5. **Lojas:** Data safety, política de privacidade e ajuda.

## 10. Decisões pendentes

- [ ] Primeira versão só com os chips grátis (Gemini, Groq, OpenRouter)? Ou com os pagos já visíveis como "em breve"?
- [ ] Sincronizar as chaves com a conta desde a fase 1, ou só a partir da fase 2?
- [ ] Nome na tela: "Brain" (inglês, como o resto do app)?
- [ ] Posição do botão Brain na fileira da tela principal.
