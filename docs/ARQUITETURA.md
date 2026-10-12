# VinyLyric — Arquitetura e próximos passos

Atualizado em 2026-10-12. Versão viva (editável) deste documento: https://claude.ai/code/artifact/91a7ba57-17e0-43cd-8d8b-cef2ee818357

O VinyLyric deve manter todo o trabalho pesado no app (Flutter + C/C++), falar com a TV pela rede local e usar o servidor da Hostinger só para guardar a coleção e as letras do usuário.

## Como usar com o Claude Code no PC

Este documento reúne as decisões tomadas até aqui e serve de briefing para implementações futuras.

1. No Claude Code do PC, abra o projeto do app e peça para ler `docs/ARQUITETURA.md` (baixando o repositório `vinylyric-tv` ou copiando o arquivo para o projeto).
2. Peça uma tarefa por vez, citando a seção: por exemplo, "implemente o WebSocket da seção TV".
3. As seções são direções, não código pronto: o Claude do PC deve conferir o que já existe no app antes de mudar algo.
4. Quando uma decisão mudar, atualize este documento para as próximas sessões.

## Arquitetura

O app concentra reconhecimento, sincronia e transmissão; a TV só exibe o que recebe e o servidor só guarda dados.

```
Fontes de letras (módulos de dados: .lrc do usuário, LRCLIB, licenciadas)
        │
        ▼
┌───────────────────────────────────┐   letra e tempo   ┌─────────────────────────────────────┐
│ App VinyLyric (celular ou PC)     │ ────────────────▶ │ Na TV                               │
│  • Interface e lista de aparelhos │                   │  • Chromecast / Google TV (Cast)    │
│    (Dart/Flutter, Android+Windows)│                   │  • Fire Stick, Android TV, PC,      │
│  • Reconhecimento e sincronia     │                   │    Tizen/webOS (WebSocket, a fazer) │
│    (C/C++ via FFI, offline)       │                   └─────────────────────────────────────┘
│  • Microfone e Google Cast        │
│    (Kotlin, só Android)           │     REST/JSON     ┌─────────────────────────────────────┐
│  • Banco local (SQLite)           │ ◀───────────────▶ │ Servidor Hostinger (PHP + MySQL)    │
└───────────────────────────────────┘                   │  coleção, letras do usuário, login, │
                                                        │  importação do Discogs              │
                                                        └─────────────────────────────────────┘
```

## TV: Chromecast, Fire Stick e WebSocket

A página da TV (`index.html`) hoje só funciona como receiver do Google Cast. Ela já tem uma função de WebSocket, mas essa função só é ativada por uma mensagem que chega pelo próprio Cast.

| Caminho | Onde funciona | Abre o app na TV sozinho? | Esforço |
| --- | --- | --- | --- |
| Google Cast (atual) | Chromecast, Google TV; celular Android | Sim | Já existe |
| WebSocket + descoberta na rede (mDNS) | Fire Stick, Android TV, Smart TV com navegador, PC; celular Android e Windows | Não: o app da TV precisa estar aberto | Baixo |
| Matter Casting (Amazon) | Fire Stick; só celular Android | Sim | Alto; provavelmente exige publicar na Amazon Appstore |
| DIAL | Fire Stick | Sim, se a Amazon registrar o app | Médio; dados continuam por WebSocket |

- **Windows não tem SDK oficial do Google Cast.** No PC, o WebSocket é o único caminho prático.
- **Fire Stick precisa de um app Android** (uma WebView com a mesma página), porque Matter e DIAL abrem apps, não páginas.
- **O formato dos pacotes não muda:** `track_loaded`, `sync_update` e `stop` servem para todos os caminhos.
- **Divisão no código:** Dart cuida da lista única de aparelhos e do WebSocket; Kotlin (só Android) cuida do Google Cast e, no futuro, do Matter.

## Fontes de letras como módulos de dados

Cada fonte de letra vira um módulo que traz só dados e configuração, nunca código. Isso evita bloqueio nas lojas (a Apple proíbe baixar código novo) e o risco de plugins maliciosos.

- **No app:** uma interface `FonteDeLetras` em Dart, com uma implementação por tipo de fonte: letras locais do usuário (.lrc), LRCLIB, fonte licenciada.
- **O módulo:** um arquivo de manifesto com nome, autor, URL dos dados, tipo de fonte e licença declarada.
- **Instalação com um clique:** o site da comunidade abre um link `vinylyric://instalar?url=...`. O app mostra o nome e a licença e pede confirmação antes de instalar.
- **Transparência:** o app mostra de onde veio cada letra e permite desativar, denunciar ou remover um módulo.

## Direitos autorais

Módulos organizam as fontes, mas não tornam legal uma fonte sem licença. O que decide o risco é a origem de cada letra. Visão geral de memória, não parecer jurídico: confira os termos atuais de cada fonte e consulte um advogado de propriedade intelectual antes de lançar.

| Fonte | Licenciada? | Observação |
| --- | --- | --- |
| Letras do próprio usuário (.lrc) | Não se aplica | O app não distribui nada; opção mais segura |
| Musixmatch (API) | Sim, nos planos pagos | O plano gratuito parece entregar só um trecho da letra |
| LyricFind | Sim | Voltado a empresas, exige contrato |
| LRCLIB | Não | Banco comunitário e aberto, sem licença das editoras |
| Genius (API) | A API não entrega letras | Scraping das páginas viola os termos de uso |
| Sites de letras por scraping | Não, nesse uso | A licença do site não se estende ao app |

- No Brasil, letra é obra protegida pela Lei 9.610/98. Os direitos costumam ser das editoras musicais; o ECAD cuida da execução pública, não das letras.
- As capas na pasta `covers/` também são obras protegidas. Buscá-las sob demanda no Cover Art Archive (MusicBrainz) evita distribuí-las dentro do app.

## Coleção no servidor (Hostinger, plano básico)

O plano básico roda PHP + MySQL, o que basta para guardar e entregar dados. Todo o processamento pesado continua no app.

- **API:** PHP com Slim (leve, roda sem SSH), em `api.seusite.com.br` ou, sem subdomínio, em `seusite.com.br/api`.
- **Banco:** MySQL separado do site. Se o plano não permitir outro banco, use o mesmo com prefixo `vl_` nas tabelas.
- **Login:** veja a seção Contas e login.
- **App offline primeiro:** SQLite local no Flutter (`drift`), sincronizando com o servidor quando houver internet.
- **Dados dos discos:** MusicBrainz (dados abertos, CC0) e Cover Art Archive para capas; importação da coleção do Discogs feita pelo servidor, em partes pelo cron, para não expor a chave secreta nem estourar o tempo limite do PHP.
- **LGPD:** política de privacidade, opção de exportar e apagar a conta, HTTPS e backup próprio do banco.

| Tabela | O que guarda |
| --- | --- |
| `vl_usuarios` | Conta e login |
| `vl_discos` | Lançamento: título, artista, ano, gravadora, ids MusicBrainz e Discogs, capa |
| `vl_faixas` | Faixas de cada disco: lado, posição, título, duração |
| `vl_colecao` | Liga usuário a disco: estado, data de compra, observações |
| `vl_letras` | Letra por faixa, com fonte e licença |

A coleção também ajuda o reconhecimento: o app procura primeiro entre as faixas que o usuário tem e pode prever a próxima faixa do lado A ou B. Se o uso crescer, o próximo passo é o plano Premium ou Business, sem mudar nada no app.

## App receptor para Fire TV

Um app Android TV em Kotlin puro: uma WebView em tela cheia que carrega a página da TV servida pelo celular. O `index.html` do `main` já se conecta sozinho a `ws://<endereço>/cast` quando aberto por `http://`, e reconecta a cada 2 segundos.

1. Ao abrir, mostra "Procurando o VinyLyric na rede".
2. Encontra o celular por NSD (o app do celular se anuncia como `_vinylyric._tcp`); com mais de um celular, pergunta qual usar.
3. Carrega `http://<ip-do-celular>:<porta>/`; a página faz o resto.

- **Página servida pelo celular:** TV e celular sempre na mesma versão. O APK guarda só a tela de busca e o modo demonstração (`?demo`), útil para a revisão da Amazon.
- **Configuração de rede:** liberar `http` só para endereços da rede local.
- **Tela acesa** pelo próprio app (a trava de tela da página pode não funcionar na WebView).
- **Controle remoto:** Voltar pergunta "Sair do VinyLyric?"; Menu abre trocar de celular e modo demonstração.
- **Tela inicial da TV:** banner 320×180 e declaração de app de TV, sem exigir tela de toque.
- **Página:** com `?tv=1`, pular o carregamento do SDK do Google Cast.
- O mesmo APK roda em TVs Android TV e Google TV de outras marcas.

## Lista de aparelhos

O celular encontra TVs e aparelhos de streaming pela rede mesmo sem o app VinyLyric instalado neles, por SSDP/DIAL e mDNS, e mostra cada um com o que é preciso para transmitir. Protótipo na aba Aparelhos da Jukebox VinyLyric: https://claude.ai/artifact/GJPGdh5cm8fqcUhRTxNSSA

| Aparelho | Estado | Cor | Ao tocar |
| --- | --- | --- | --- |
| Chromecast, Google TV | Pronto | Magenta | Transmite pelo Google Cast |
| Fire TV com o app VinyLyric aberto | Pronto | Magenta | Transmite por WebSocket |
| Fire TV sem o app (ou com o app fechado) | Instale ou abra o VinyLyric na TV | Coral, piscando | Passo a passo e QR code para instalar |
| Samsung, LG | Por espelhamento | Azul-aço | Passo a passo e botão para abrir a transmissão de tela do Android (modo tela secundária) |

- **Cores pela forma de transmissão,** diferentes das cores dos plugins (ciano, verde, lilás, âmbar), sempre com o texto do estado ao lado e o selo da marca.
- **Fire TV sem app:** o celular vê o aparelho pelo DIAL, mas não vê o anúncio do VinyLyric. Sem registro DIAL na Amazon, não dá para distinguir "não instalado" de "fechado".
- **Limitações:** a TV precisa estar ligada; roteadores com isolamento de clientes ou redes de visitante bloqueiam a busca. No Android, pedir a permissão de multicast. No iOS, a Apple exige o entitlement de multicast, solicitado a ela.

## Ordem das plataformas

Android primeiro, depois Windows, por último iOS.

- **Android:** Kotlin livre para Google Cast, microfone (Oboe) e serviços. O app de Fire TV também é Android.
- **Windows:** reaproveita a interface Flutter; a TV recebe por WebSocket, porque não há SDK do Google Cast para Windows.
- **Regra desde já:** todo código específico de plataforma fica atrás de interfaces em Dart, para trocar a implementação sem reescrever o app.
- **Evitar agora o que travaria o iOS depois:** fonte de letras sem licença como peça central, ou login só com Google.

## TVs Samsung e LG e tela secundária

TVs Samsung (Tizen) e LG (webOS) não têm Chromecast. O YouTube as encontra por DIAL, com o app dele já instalado na TV.

| Caminho | Precisa de app na TV? | Observação |
| --- | --- | --- |
| Tela secundária via espelhamento (Android `Presentation`) | Não | TV mostra a tela do VinyLyric, celular fica com os controles. Melhor em celulares Samsung (Smart View/Miracast) |
| Navegador da TV + `?ws=` | Não | Bom para testes |
| App Tizen ou webOS + WebSocket | Sim | A mesma página HTML empacotada. Sem loja: modo desenvolvedor, certificado por TV (como o Jellyfin faz) |
| App Tizen + DIAL | Sim, e registro na Samsung | Abre o app sozinho, como o YouTube |

- O mesmo recurso de tela secundária existe no Windows (projetar em modo Estender) e no iPhone (AirPlay).
- Ao conectar, o app junta tudo numa lista única: Chromecast via Google Cast, apps VinyLyric via WebSocket e telas secundárias via apresentação.
- Roku e VIDAA ficam para o espelhamento.

## Modo sem letras

Em todas as versões, quando não houver letra (ou por escolha do usuário), a TV mostra cartões que se alternam durante a música.

| Cartão | Fonte | Cuidado |
| --- | --- | --- |
| Disco e prensagem: gravadora, catálogo, país, ano, matriz | Discogs, MusicBrainz | |
| Ficha técnica: compositores, músicos, arranjador | MusicBrainz, Discogs | |
| Valor de mercado | Estatísticas do Discogs | Mostrar como referência com data; conferir os termos da API |
| Curiosidades | Wikipedia e Wikidata | CC BY-SA: citar a fonte na tela |
| Tema de personagem (trilhas de novela) | Cadastro próprio ou comunitário | |
| Notas do usuário | Coleção | Visível só para o dono |

- Na página da TV, um novo pacote `track_info` com a lista de cartões; o app monta o conteúdo e a TV só exibe.
- Texto gerado por IA aparece marcado como tal.
- O modo também serve de demonstração para os revisores das lojas.

## Contas e login

Login próprio, na API PHP da Hostinger. A conta é opcional: o app funciona sem ela, e a conta serve para backup, sincronização entre aparelhos e importação do Discogs.

- **Preferir não guardar senhas:** link mágico por e-mail e Entrar com Google. Se houver Google no iOS, a Apple deve exigir também Entrar com a Apple.
- **Se houver senha:** `password_hash` (Argon2id ou bcrypt), recuperação por link de uso único que expira, mensagens que não revelam se o e-mail existe.
- **Tokens:** acesso curto + renovação revogável no banco; no app, em `flutter_secure_storage`.
- **API:** consultas preparadas (PDO), limite de tentativas por e-mail e IP numa tabela MySQL, toda consulta filtrada pelo usuário do token, HTTPS obrigatório, segredos fora da pasta pública e do GitHub.
- **Exigências das lojas e da LGPD:** excluir a conta dentro do app e por página web, política de privacidade, exportar e apagar dados.
- **Ao criar a conta:** oferecer enviar a coleção que já está no aparelho.
- **Manutenção contínua:** atualizar PHP e bibliotecas, testar backups, observar tentativas suspeitas, comunicar vazamentos à ANPD.

## Coleções públicas

A coleção de cada usuário pode ficar visível para outros, só com autorização e sem mostrar o nome.

- **Privado por padrão;** ativar e desativar a qualquer momento, e ocultar discos específicos.
- **Apelido** gerado ou escolhido no lugar do nome, e **id público aleatório**, nunca o id interno da conta.
- **Só campos públicos:** disco, artista, ano, estado. Nunca notas, preço, data ou local de compra, e-mail. Quem filtra é o servidor.
- **Fotos:** o servidor remove os dados EXIF (localização).
- **Recursos:** "quantos colecionadores têm este disco", navegar por coleções anônimas, futuramente trocas com mensagens dentro do app; denunciar e bloquear.
- **Banco:** `vl_usuarios` ganha `perfil_publico`, `apelido`, `id_publico`; `vl_colecao` ganha `visivel`.
- **LGPD:** dados pseudonimizados continuam pessoais; consentimento claro ao ativar.

## Idiomas

O app será multilíngue, com idiomas também como plugins de dados.

- **Base:** sistema nativo do Flutter (`flutter_localizations` + arquivos `.arb`), com plural, datas e números por país.
- **Embutidos:** português, inglês e espanhol. Os demais como pacotes da comunidade; frase faltando cai no inglês.
- **Regra a partir de agora:** nenhuma tela nova com texto escrito direto no código. Extrair os textos existentes quanto antes.
- **Também traduzir:** a página da TV e as descrições nas lojas. O servidor devolve códigos de erro, e o app traduz.
- **Layout:** aguentar textos até 30% mais longos; idiomas da direita para a esquerda ficam para depois.
- **Traduções da comunidade:** Weblate ou Crowdin para organizar tradução e revisão.

## Jukebox de plugins

A tela de plugins é uma jukebox: cada plugin é um compacto de 7" em vinil colorido, com código de seleção na cartela. Protótipo interativo: https://claude.ai/artifact/GJPGdh5cm8fqcUhRTxNSSA

| Tipo | Cor | Códigos | Regra |
| --- | --- | --- | --- |
| Letras | Azul ciano | L1, L2... | Vários ativos, em fila que define a ordem de busca |
| Idiomas | Verde | I1, I2... | Um por vez |
| IA | Lilás | A1, A2... | Vários; conteúdo marcado como gerado por IA |
| Informações do disco | Âmbar | D1, D2... | Vários; cada um vira um cartão na TV |

- **Ativo** = disco no prato, girando. **Com erro** = disco riscado, com aviso em texto. **Instalar** = escolher no caixote da loja, vendo fonte e licença antes.
- **Acessibilidade:** o estado nunca depende só da cor; há também uma visão em lista.
- **Entre plataformas:** o mesmo manifesto funciona em Android, Windows e iOS. Ele traz `formatVersion` e versão mínima do app. A lista instalada e a fila de letras sincronizam pela conta. Chaves de IA ficam só no aparelho. No iOS, tipos não permitidos aparecem como "não disponível nesta versão".
- **Link de instalação:** `vinylyric://instalar?url=...`; no Windows, o instalador registra esse protocolo.
- **Plugins de IA:** o áudio nunca sai do aparelho sem consentimento explícito; o usuário vê o que é enviado ao serviço.

## Versão para iPhone

No iOS, o VinyLyric é publicado como app de coleção, com reconhecimento, TV e modo sem letras. Letras só do próprio usuário ou de fonte licenciada.

- **Importar `.lrc`** genérico, apresentado como "suas letras", sem lista, link ou menção a repositórios da comunidade.
- **Nada escondido:** a Apple proíbe recursos liberados após a revisão (diretriz 2.3.1).
- **Necessário:** Mac (ou Mac na nuvem, como Codemagic), iPhone de teste, conta Apple Developer (cerca de US$ 99 por ano).
- **Refazer em Swift:** microfone (`AVAudioEngine`) e Google Cast. C/C++ via FFI funciona.
- **Permissões com texto claro:** microfone e rede local. Segundo plano é restrito; o app funciona com a tela aberta.
- **Para o revisor:** conta de teste, modo demonstração sem vitrola e sem TV, notas explicando as fontes de dados.
- **Extra:** AirPlay para Apple TV e TVs Samsung recentes.

## Próximos passos

- [ ] Refazer o layout para celular sobre o novo `index.html` do branch `main`
- [ ] Página da TV: conexão automática por WebSocket via `?ws=`, com reconexão e aviso de "conectando..."
- [ ] App Flutter: servidor WebSocket local e descoberta por mDNS, com lista única de aparelhos (Cast + VinyLyric)
- [ ] App de Fire TV: WebView com a página, navegação pelo controle e modo demonstração
- [ ] Levantar as fontes de letra que o app usa hoje e classificar a licença de cada uma
- [ ] Definir o formato do manifesto dos módulos de letras
- [ ] Conferir no hPanel os limites do plano: bancos MySQL, subdomínio, SSH, tempo de execução do PHP
- [ ] API de coleção em PHP/Slim + MySQL
- [ ] Política de privacidade (LGPD) e conversa com advogado de propriedade intelectual antes do lançamento público
- [ ] Subir o código do app para um repositório privado no GitHub, sem chaves, senhas nem arquivo de assinatura
- [ ] Extrair os textos das telas para arquivos `.arb` (idiomas)
- [ ] Modo tela secundária (`Presentation`) para TVs sem Chromecast
- [ ] Pacote `track_info` e cartões do modo sem letras na página da TV
- [ ] Contas: link mágico + Google, exclusão de conta no app
- [ ] Tela de plugins em jukebox, a partir do protótipo
- [ ] Compilação automática do APK pelo GitHub Actions
- [ ] App receptor para Fire TV (Kotlin, WebView, NSD, banner, controle remoto)
- [ ] Lista de aparelhos com busca SSDP/DIAL e mDNS, cores por forma de transmissão

## Perguntas em aberto

- Quais fontes de letra o app usa hoje? O código do app não está neste repositório.
- Matter Casting funciona com app instalado por sideload ou exige publicação na Amazon Appstore?
- Abrir o app no Fire Stick pelo celular é essencial, ou dá para pedir que o usuário abra o app na TV antes?
- O plano básico da Hostinger permite um segundo banco MySQL e subdomínio?
- Plugins de IA pagos: cobrança pelas lojas (que ficam com 15% a 30%), assinatura, pacote de usos ou chave do próprio usuário? Se a IA for paga por você, o servidor intermedia as chamadas e limita o uso por usuário.
- A loja da Samsung aceita o app, e com que exigências?
