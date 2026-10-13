# Registro de Versões e Alterações — WaxClub (Vinyl Social Club)

Este arquivo documenta o histórico oficial de versões, datas e melhorias implementadas no projeto **WaxClub — Vinyl Social Club** (nome oficial a partir da v1.3.2). As entradas anteriores registram os nomes usados na época de cada versão: VyniLyric (v1.2.03 a v1.3.1), VinyLyric e VinylSync Lyrics.

## [v1.3.8] — 13/10/2026 (Letra no Celular no Estilo da TV + Ícone com o Rótulo de Volta)

* **Letra no próprio app igual à da TV:** fonte **Inter** peso 800 (embutida em `assets/fonts/`, licença OFL), centralizada e em **caixa alta** quando o texto é em alfabeto latino (outros alfabetos ficam como estão). Três linhas em destaque do mesmo tamanho (anterior, atual e próxima), a atual em branco com brilho laranja; a 2ª linha de distância em 76% e apagada, as demais em 62% e quase invisíveis. A linha atual fica sempre no centro da área visível, com as bordas esmaecendo, e as transições seguem a mesma curva da TV. Trechos sem letra mostram "♪". O tamanho da letra acompanha a altura da tela.
* **Ícone do app:** voltou o rótulo da arte original, com "WaxClub" e "VINYL SOCIAL CLUB" (na v1.3.5 o rótulo tinha sido redesenhado sem texto por engano). `tool/icon/WaxClubWoodIcon.cs` agora mantém o rótulo por padrão; ícones do Android regenerados.
* Novo `test/lyrics_tv_style_test.dart` (caixa alta só para alfabeto latino, tamanhos/cores por distância, fonte Inter 800 centralizada).

---
## [v1.3.7] — 12/10/2026 (Microfone Cromado no Centro da Barra Inferior)

* O botão de ouvir passou a ser **só o microfone cromado** (extraído da arte, sem a madeira: `assets/images/mic_chrome.png`, por `tool/icon/ChromeMicExtract.cs`), no **centro da barra inferior**. Ouvindo, um halo laranja pulsa atrás dele e aparece o selo vermelho de parar.
* Barra inferior reorganizada: à esquerda o estado do microfone (inteiro/cortado), play/pause e parar (botões compactos); no centro o microfone; à direita a rotação. "Calibrating in Xs" (ou a etapa especial) aparece numa linha fina centralizada acima, só quando há algo a mostrar.
* "Flip the record" continua acima da barra quando o lado termina.
* Corrigidas as dicas "Continuar"/"Pausar" que tinham escapado da tradução (agora "Resume"/"Pause").
* Novo `test/footer_layout_test.dart`: a barra cabe sem estourar em 320, 360 e 800 de largura, com o microfone no centro.

---
## [v1.3.6] — 12/10/2026 (Tela Principal Mais Limpa: Painéis de Madeira e Microfone de Madeira)

* **Topo em destaque:** ícones, capa do disco e textos ficam num painel de nogueira, um tom mais claro que o fundo, com veio e friso entalhado, igual ao rodapé.
* **Rodapé enxuto:** saíram o disco girando e os selos "Microphone listening/off" e "Built-in microphone". No lugar, um ícone de **microfone inteiro** (ouvindo, em laranja) ou **cortado** (desligado). Do texto ficou só **"Calibrating in Xs"**; sem contagem, aparece a etapa especial (pausado, fim do lado, próxima faixa, confirmando). Play/pause, parar, a rotação e o ajuste fino continuam.
* **Botão de ouvir:** o **microfone de madeira** da arte do usuário (`assets/images/mic_button.png`, recortado por `tool/icon/WoodTileCrop.cs`), **centralizado embaixo**. Ouvindo, ganha um anel laranja pulsante e o selo de parar. "Flip the record" aparece no mesmo lugar quando o lado termina.
* **Centro sempre inteiro, em pé e deitado:** a saudação reserva o espaço do microfone e se compacta quando falta altura (ícone menor ou oculto, letras menores). Como o rodapé não mostra mais a etapa do reconhecimento, ela aparece em laranja abaixo da saudação (ex.: "Listening through the microphone...").
* Corrigida a posição da saudação: com a barra sobre o conteúdo, a altura dela era contada duas vezes e o texto descia demais com o celular deitado.

---
## [v1.3.5] — 12/10/2026 (Telas Novas: Saudação, Coleção, Ajuda + Visual Madeira e Creme/Laranja)

### 🏠 Tela principal
* Sem música tocando, a tela mostra o ícone e uma **saudação com o nome do usuário**, que varia com a hora e a cada abertura: "Good afternoon, Gustavo!", "Let's go, Gustavo!", "Gustavo, today is a great day to listen to some music.". Na primeira vez, o botão "What should we call you?" pede o nome (tocar na saudação permite trocar). O nome fica no aparelho até existir a conta WaxClub.
* O botão **Quick Demos** saiu. No lugar do antigo "How it works" entrou o ícone de **ajuda**.

### 💿 My Collection
* Novo ícone de **coleção** na barra superior abre a tela "My Collection": discos com capa, artista, **quantas vezes foram ouvidos** e **quando**, ordenáveis por tocados recentemente, mais tocados, adicionados recentemente e A–Z. O detalhe mostra a lista de faixas, primeira e última audição e o **histórico com data e hora** de cada faixa ouvida.
* **Add to collection** na janela de faixas (toque na capa), ao lado de "Change record".
* Audições: cada faixa ouvida é registrada; qualquer faixa conta o disco **uma vez por sessão** (nova sessão após 2 h sem ouvi-lo). Os campos da coleção já seguem o modelo do servidor e do Discogs (nota, estado do disco e da capa, observações, número do lançamento no Discogs).

### ❓ Help
* Manual em tópicos: Getting started, Listening and syncing, Flipping the record, Turntable speed, Lyrics running early or late, Change record and Discogs, Your collection, Showing the lyrics on the TV e Troubleshooting. O toque longo na versão continua copiando os logs da sessão.

### 🪵 Ícone e cores
* **Ícone novo** a partir da arte do usuário: toca-discos em madeira com o disco encaixado (borda levemente entalhada), braço e selo creme e laranja com balão de conversa e pessoas, **sem texto**, com cantos transparentes (`tool/icon/WaxClubWoodIcon.cs`).
* **Paleta do ícone em todo o app:** creme do selo (`#EBD5B0`) nos destaques, laranja queimado (`#C2602F`) nas ações, ferrugem (`#8E3B1E`) nos detalhes e nogueira mais quente no fundo e nos painéis, no lugar do ciano, roxo e rosa neon.

### 🧪 Qualidade
* Novo `test/home_collection_help_test.dart`: saudação por nome e horário, contagem por sessão, coleção e nome salvos e recarregados, telas de coleção e ajuda. Suíte: 168 testes verdes.

---
## [v1.3.4] — 12/10/2026 (Celular Encontra e Conecta no App WaxClub do Fire TV)

### 📺 Apps WaxClub de TV na lista "Cast to TV"
* Além dos Chromecasts, a busca procura os apps WaxClub de TV que se anunciam na rede: `_waxclub-tv._tcp` (nome definitivo) e `_vinylyric._tcp` (nome atual do app do Fire TV, `WaxClubClient`). Cada um aparece com o nome e o modelo anunciados (ex.: "WaxClub TV app · AFTKA").
* Ao tocar, o celular conecta pelo WebSocket do próprio app de TV (`ws://<ip>:<porta>/cast`): handshake `client_ready` → `server_ack`, e depois `track_loaded`, `sync_update`, `side_flip` e `stop`, o mesmo protocolo do `ReceiverServer` do app da TV.
* **Add by IP:** sem Chromecast no endereço (porta 8009), testa o servidor do app de TV (porta 8088) e conecta nele.

### 🧪 Qualidade
* Novo `test/tv_app_connection_test.dart`: aparelho a partir do anúncio; "Add by IP" com um servidor que imita o app do Fire TV (handshake, faixa enviada, `stop` ao desconectar); endereço sem servidor não entra na lista.

---
## [v1.3.3] — 12/10/2026 (Celular se Anuncia na Rede para os Apps de TV)

### 📣 Anúncio `_waxclub._tcp`
* Enquanto o servidor da página da TV está no ar (porta 8088), o celular se anuncia na rede local por mDNS/DNS-SD como **`_waxclub._tcp`**, com o nome "WaxClub (<modelo do celular>)". Assim os apps de TV, como o receptor do Fire TV em desenvolvimento (`WaxClubClient`), encontram o celular sozinhos e abrem `http://<ip>:<porta>/` ou o WebSocket `/cast`.
* Registros TXT: `fn` (nome), `md` (modelo), `v` (versão do protocolo, 1), `app=waxclub`, `ver` (versão do app), `path=/` e `ws=/cast`.
* Anúncio feito pelo NsdManager do Android (`PhoneNsdAnnouncer.kt`, canal `com.waxclub.app/nsd` na `MainActivity`) e controlado pelo Dart (`lib/services/phone_announcer.dart`): sobe com o servidor e é retirado ao fechar o app.

### 🧪 Qualidade
* Novo `test/phone_announcer_test.dart`: tipo, porta e campos do anúncio; anúncio ao subir o servidor e retirada ao fechar; app segue normal sem o canal nativo. Suíte: 156 testes verdes.

---
## [v1.3.2] — 12/10/2026 (Novo Nome: WaxClub — Vinyl Social Club + Trilhas: Nomes Limpos + Minutagem do Selo)

### 🏷️ O app passa a se chamar **WaxClub**, com o sufixo **"Vinyl Social Club"**
* **Tudo que o usuário vê:** nome do app no Android, título, tela inicial (nome + sufixo), barra superior (sufixo abaixo do nome), "Como funciona", mensagem de permissão do microfone, identificação do celular para a TV ("Smartphone WaxClub") e a tela da TV ("WaxClub TV — Vinyl Social Club"; ociosa mostra o nome e o sufixo).
* **Ícone novo:** disco de vinil com anel neon ciano, selo roxo→ciano com "W" e o nome "WaxClub" com o sufixo "VINYL SOCIAL CLUB", no estilo neon do app (gerado por `tool/icon/WaxClubIcon.cs`). Ícone anterior guardado em `backups/`.
* **Identificador Android:** `com.vinylyric.vinylyric` → **`com.waxclub.app`**. O Android trata como um **app novo**: instala ao lado do antigo e começa sem os discos guardados, a rotação calibrada e o login do Discogs. O app antigo deve ser desinstalado à mão.
* **TV (Google Cast):** canal `urn:x-cast:com.waxclub.sync`; a página da TV e as capas passam a ser publicadas no repositório **`INTEGRALIST88/WaxClub`** (`https://integralist88.github.io/WaxClub/`). A URL do receptor precisa ser atualizada no Google Cast Developer Console (App ID 27687E0B).
* **Código:** pacote Dart `waxclub`; `VinylSyncEngine` → `WaxClubEngine` (`lib/engine/waxclub_engine.dart`), `VinylSyncApp` → `WaxClubApp`, `VinylLyricsScreen` → `HomeScreen` (`lib/ui/screens/home_screen.dart`); identificação nas APIs (LRCLIB, MusicBrainz, Discogs) como "WaxClub"; log de sessão `waxclub_events.jsonl`; endereço de retorno do login Discogs `https://waxclub.app/discogs-callback`. Nome e sufixo centralizados em `lib/app_info.dart` (`kAppName`, `kAppTagline`).
* **Arquivos:** manual renomeado para `MANUAL_FUNCIONAL_WAXCLUB.md`; deploy em `deploy.ps1`, gerando `WaxClub_v<versão>.apk` e demais arquivos `WaxClub_*` na pasta do Drive `WaxClub`; pastas do projeto e do Drive renomeadas para `WaxClub`. Versões antigas (APKs/ZIPs 1.0.x e scripts de deploy antigos) movidas para `backups/versoes_antigas/`. Script da troca: `tool/rename_to_waxclub.js`.
* Teste de fumaça confere o nome, o sufixo e a ausência dos nomes antigos na tela.
* **Repositório único no GitHub:** o projeto passou a ficar em `H:\Github\WaxClub`, clone do repositório **`INTEGRALIST88/WaxClub`**. O mesmo repositório guarda o código do app e publica, pelo GitHub Pages (`https://integralist88.github.io/WaxClub/`), a página da TV (`index.html` na raiz, gerado de `web_receiver/index.html` por `tool/sync_tv_receiver.ps1`) e as capas (`covers/` na raiz). Ficam fora do Git: `build/`, `.dart_tool/`, `backups/` e despejos `.hprof`. Rascunhos de desenvolvimento (`find_claude*.ps1`, `extract_*.ps1`, `screen*.png`) foram para `backups/rascunhos_dev/`.
* **Build com projeto em H:** `kotlin.incremental=false` em `android/gradle.properties`. O cache incremental do Kotlin falha quando o projeto e o cache do Flutter estão em discos diferentes.
* **Build:** o Gradle passa a ter 4 GB de memória (`android/gradle.properties`). Com o padrão de 512 MB, o empacotamento do APK falhava de vez em quando por falta de memória e deixava despejos `.hprof` de centenas de MB na pasta `android`.

### 🌎 App em inglês
* Todos os textos que o usuário vê passaram para o **inglês**: menus, botões, painel da transmissão, rodapé, mensagens de status do reconhecimento e da sincronia, diálogos (Change record, Discogs, Cast to TV), mensagem de permissão do microfone, "How it works" e a **tela da TV** ("Up next", "Ready to play", "Waiting for the needle", demonstração). O rótulo de fim de lado passou a "End of side A", e as comparações do motor e do painel acompanharam.
* Comentários do código e logs internos continuam em português.
* Corrigido o título do "How it works", que tinha ficado vazio ("Como funciona o  ()") na troca de nome.
* Os HTML da TV ficam sempre com quebra de linha LF (`.gitattributes`): o Git no Windows gravava CRLF e quebrava a comparação entre a página publicada e a cópia embutida no app.
* Scripts da tradução: `tool/translate_ui_en.js`, `translate_ui_en_2.js` e `translate_tv_en.js`; levantamento dos textos: `tool/list_ui_strings.js`.

### 🏷️ Nomes dos discos de trilha corrigidos
* 43 páginas do site de origem usam como título a posição e a vendagem do ranking de trilhas mais vendidas — o disco aparecia como "7. O Outro internacional: 1.164.299 cópias". Agora: **"O Outro Internacional"**.
* Todos os nomes foram padronizados sem a palavra "trilha": "Babilônia trilha sonora volume 1" → "Babilônia Volume 1", "Véu de Noiva trilha sonora" → "Véu de Noiva", "Sete Vidas trilha instrumental" → "Sete Vidas Instrumental". O ano entre parênteses só fica quando dois discos teriam o mesmo nome (remakes).

### ⏱️ Minutagem e lados do selo dos LPs
* As durações vinham da Deezer, que traz as versões de álbum — diferentes das gravadas nos LPs de trilha (ex.: "Coming Around Again", 3:38 na Deezer e 3:19 no selo), o que adiantava a troca de faixa.
* Os LPs da Som Livre foram localizados no **Discogs** (API pública) pelo nome da novela + tipo (nacional, internacional, volume...) e ano, e as faixas receberam a **minutagem impressa no selo** e o **lado real (A/B)**: **219 LPs com os lados do disco, 116 com a minutagem do selo** (1.567 durações). "O Outro Internacional" foi conferido com a foto do selo (Som Livre 590.002), que fica registrada como correção manual (`tool/trilhas/label_overrides.json`, prioridade máxima).
* Os demais LPs (Tupi, Band, outras gravadoras e anteriores a 1971) mantêm a duração da Deezer e os lados estimados.
* O app regrava a lista de faixas da trilha no cache a cada uso, para que minutagens corrigidas em versões novas substituam as antigas.

---
## [v1.3.1] — 08/10/2026 (Mudar Disco + Conta Discogs + Trilhas de Novelas)

### 💿 "Mudar disco": o usuário escolhe o disco certo
* Músicas que aparecem em vários discos (coletâneas, ao vivo, reedições) faziam o app seguir o disco errado. Agora, ao tocar na capa, a lista de faixas tem o botão **"Mudar disco"**.
* A janela lista **todos os discos em que a música aparece**, com capa, artista, ano, país e etiquetas (Atual, Vinil, Coletânea, Ao vivo, N edições), com o disco atual no topo e os discos de estúdio antes das coletâneas. Há também **busca livre** (artista, título do disco).
* Ao escolher, o app carrega a lista de faixas do disco (lados A/B e durações), **trava o disco**, atualiza capa, lado, duração e próxima música no celular e na TV, e grava o disco como **padrão do usuário** para todas as músicas dele. Nas próximas vezes o reconhecimento já usa esse disco, mesmo que o Shazam indique uma coletânea.

### 🔑 Conta Discogs (base principal) + MusicBrainz (reserva)
* Caixa **"Consultar Discogs"** na janela "Mudar disco". Ao marcar sem conta conectada, aparece um texto explicando a vantagem; **OK** leva à **tela de login do Discogs** dentro do app.
* As credenciais ficam **guardadas cifradas só no celular** para as próximas vezes (e a caixa continua marcada); "Sair" desconecta.
* Com o Discogs conectado, ele é a base principal (a mais completa de vinis, prensagens e coletâneas). Se ele falhar ou não achar nada, o app mostra a base **MusicBrainz** com um aviso.
* Login pela tela do Discogs (OAuth) quando as chaves do app estiverem cadastradas (`--dart-define=DISCOGS_CONSUMER_KEY/SECRET`); até lá, a mesma tela abre a página da conta para o usuário gerar e colar o **token pessoal**.

### 📼 Trilhas sonoras de novelas brasileiras embutidas no app
* Catálogo com as trilhas sonoras de novelas (Globo de 1970 em diante, Malhação, séries e minisséries, Record, SBT, Band, Manchete, Excelsior e Tupi) levantadas do site Teledramaturgia / Observatório da TV: nome do disco, emissora, ano e as faixas com o **artista de cada música**. **Capas só dos LPs** (437), recomprimidas (10,5 MB) e hospedadas pelo próprio VyniLyric no GitHub Pages (covers/ (raiz do repositório) → integralist88.github.io/vinylyric-tv/covers/); nenhuma imagem é carregada do site de origem. Trilhas em CD usam a capa informada pelo Shazam. A **duração** de cada faixa veio da Deezer (reserva: iTunes) e foi incorporada ao catálogo (`assets/catalog/trilhas_novelas.json`): **929 discos, 14.414 faixas, 10.215 com duração** (437 LPs até 1993). Scripts de geração em `tool/trilhas/` (`crawl.js`, `durations.js`).
* Quando uma música que está numa trilha é reconhecida, **a trilha é assumida como o disco** (capa, lista de faixas, duração, próxima música) — a mais antiga, se a música aparece em várias. Exceção: músicas com disco **marcado pelo usuário** em "Mudar disco" (ou confirmado pelas 3 faixas seguidas na ordem do disco) continuam no disco escolhido.
* LPs até 1993 ganham lados A/B estimados pela duração (para o "Vire o disco"); trilhas em CD (a partir de 1994) ficam com um lado só, sem pedir virada no meio.
* **Coletâneas com vários artistas:** a próxima música prevista e a busca da letra passam a usar o artista da própria faixa (antes usavam o artista da música atual). A lista de faixas da capa mostra o artista de cada faixa. O Discogs também passa a informar o artista por faixa nas coletâneas.
* A escolha automática do disco pela capa não passa mais por cima da trilha nem do disco escolhido pelo usuário.

### 🧪 Qualidade
* Novo `test/soundtrack_catalog_test.dart`: busca da trilha por música e artista (duetos, a mais antiga primeiro), lados de LP × CD, trilha travada com capa/duração/próxima faixa e letra buscada com o artista certo, prioridade do disco do usuário e proteção da escolha do usuário contra a confirmação automática.
* Novo `test/album_choice_test.dart`: leitura do catálogo Discogs (edições agrupadas, coletâneas, lados, durações, sub-faixas), ordem da lista, login por token e por OAuth com credenciais recuperadas na reabertura, reserva MusicBrainz com o Discogs fora do ar, escolha do disco (trava, TV, padrão do usuário mantido na próxima sessão) e a caixa "Consultar Discogs" com a explicação. Suíte: 147 testes verdes.

---
## [v1.3] — 08/10/2026 (Virada do Disco com Letra Imediata + Reconhecimento Rápido Primeiro)

### 🐞 Correção: o lado B não era reconhecido após tocar em "Vire o disco" (logcat da v1.2.02)
* O toque interrompia a sondagem automática de 12s; a sondagem interrompida voltava "vazia", era tratada como **"não reconhecido"** e reagendada, e a escuta do toque (6s) pegava só o começo do lado (introdução/ruído da agulha). Toques repetidos matavam as sondagens seguintes.
* Agora uma escuta interrompida é marcada como **cancelada** e não é mais confundida com "não reconhecida".

### 💿 Virada do disco: letra do lado B na hora
* Ao tocar em **"Vire o disco"**, o app já mostra a **letra da 1ª faixa do novo lado** (celular e TV), parada em **0:00 — "aguardando a agulha"**. Tanto faz virar o disco antes ou depois de tocar no botão.
* No **primeiro som de música** a letra começa a correr a partir do instante exato em que o som começou; quando o Shazam reconhece, o **timestamp é corrigido**. Se o lado começar por outra música (ex.: agulha na 2ª faixa), o app troca para ela.
* Sem tracklist do novo lado, o botão escuta e identifica como antes, agora com a escuta progressiva.
* TV: mostra "Aguardando a agulha" (em vez de "Pausado") com a letra em destaque normal e a agulha parada no sulco externo.

### ⚡ Reconhecimento: rápido primeiro, robusto depois
* **Escuta progressiva:** uma única gravação contínua consulta o Shazam já aos **4s**, e — sem recomeçar — de novo aos **8s** e **12s**. Músicas fáceis são reconhecidas em ~5s; as difíceis ganham até 12s de áudio sem perder o que já foi gravado.
* Vale para o toque no microfone, a próxima faixa, a confirmação da previsão e a virada; as tentativas seguintes usam direto os trechos longos (8/12s) e as checagens de sincronia usam 6/12s.

### 🧪 Qualidade
* Novos testes: gravação progressiva (para no marco reconhecido, percorre todos os marcos, preempção pelo usuário, cabeçalho WAV); virada com letra imediata em 0:00 → início no som → correção pelo Shazam; virada com outra música no lado B. Suíte: 139 testes verdes.

---
## [v1.2.03] — 08/10/2026 (Novo Painel da Transmissão + Visual em Madeira Escura + Nome Oficial VyniLyric)

### 🏷️ Nome oficial: VyniLyric
* Todos os textos visíveis passam a usar **VyniLyric**: nome do app no Android (ícone na tela inicial), título, tela vazia, diálogo de informações, mensagem de permissão, tela da TV e identificação do celular para a TV.
* **Ícone:** o nome desenhado no ícone foi corrigido para "VyniLyric", reaproveitando as próprias letras neon da arte (as letras "iny" foram reordenadas para "yni", deslocando só o brilho das letras sobre o fundo original); ícones do Android regenerados. O original está em `backups/app_icon_original_VinyLyric.jpg`.
* Identificadores técnicos mantidos para não quebrar atualização e TV: pacote `com.vinylyric.vinylyric`, canal Cast `urn:x-cast:com.vinylyric.sync` e nomes internos de classes.

### 📱 Painel do celular durante a transmissão (layout aprovado por esboço)
* **Tela travada em retrato** enquanto transmite (volta a girar ao desconectar).
* Cabe **inteiro na tela, sem rolagem** (verificado em 393×852 e 360×740 por teste automatizado), em 4 grupos: **TV** (aparelho e Desconectar) · **Tocando agora** (capa com lado do disco e atalho para as faixas, título, artista, disco e "faixa X de Y", barra de tempo, **A seguir** com "letra pronta" ou o aviso de fim do lado) · **Ajustes** (rotação medida em RPM com desvio e incerteza, ajuste fino com ±0.1, Zerar e Travar rotação, sincronia da letra ±0.5s com o ajuste atual) · **Ação principal** no rodapé (Ouvir/Ressincronizar ou "Vire o disco" pulsando) com linha de status.
* Modo compacto automático para telas baixas, com as mesmas funções.

### 🪵 Visual em madeira escura entalhada
* Paleta: ébano `#120C08` (fundo), nogueira escura `#1E140D` (painéis), nogueira `#2B1D13` (elevado); entalhe com nogueira inglesa `#3E2B23` (luz) e `#070403` (sombra) — mesma família da tela da TV.
* Fundo da tela de letra em madeira com veio (desenhado pelo app, sem imagens) e vinheta; rodapé de controles em nogueira com friso entalhado; painéis entalhados e botões em relevo no painel da transmissão; diálogos e menus herdam a paleta.
* Mantidos: a exibição da letra (cores e tamanhos), o ícone e as cores de destaque (ciano/roxo).

### 🧪 Qualidade
* Novo `test/cockpit_layout_test.dart`: o painel cabe sem estouro e sem rolagem nos dois tamanhos de tela.

---
## [v1.2.02] — 08/10/2026 (Botão "Vire o Disco" + Animação de Virada na TV)

### 📱 Celular
* No fim de um lado do disco, o botão de microfone vira **"VIRE O DISCO"** (âmbar, pulsando): no painel do modo TV a tela **rola sozinha** até ele; no modo letra o botão flutuante vira um botão largo pulsante.
* O botão chama a nova ação `flipSide()`: escuta o novo lado **mantendo o disco travado, a tracklist e a previsão** (antes o toque recomeçava a sessão do zero com `startListening`).
* Sondagens automáticas de virada usam 12s de captura (faixas menos conhecidas); o toque do usuário usa 6s.

### 📺 TV (web_receiver/index.html)
* **Animação de virada:** ao tocar em "Vire o disco" (ou quando o microfone detecta sozinho o novo lado), a agulha **levanta**, o disco e o selo **viram 180° no eixo horizontal** e, no meio do giro, a letra do lado troca (A → B). A agulha só **desce no sulco externo** quando a 1ª música do novo lado começa.
* **Troca de disco:** quando a música seguinte é de **outro artista ou outro disco**, a mesma animação ocorre e a **capa troca no meio do giro**.
* Selo a **33⅓ RPM** (mais fácil identificar a capa) e **letra do lado com cor variável**, sempre em contraste com o trecho da capa sob ela (tom complementar com contraste ≥ 4.5:1).
* Novo pacote do celular para a TV: `side_flip` (com o próximo lado).

### 🧪 Qualidade
* Novo teste: virar o disco anuncia um único giro à TV com o lado B, reconhece a 1ª faixa do lado B e mantém o disco travado. Suíte: 131 testes verdes.

---

## [v1.2.01] — 08/10/2026 (Ajustes da Tela da TV + Correção do Salto de Faixa + Tela Sempre Acesa)

### 📺 Tela da TV (web_receiver/index.html)
* Todas as fontes 20% maiores (exceto o tempo da agulha).
* Letra em **caixa alta** quando o texto é em alfabeto latino.
* Fundo de **madeira bem escura** (veio gerado por ruído SVG embutido, sem baixar imagens).
* Tempo da música **abaixo da agulha**, acompanhando-a, com decorrido e total do mesmo tamanho.
* **Selo:** capa ampliada preenchendo todo o selo; **letra do lado do disco (A, B...)** em caixa alta, no tamanho da letra principal, no lado esquerdo do selo, girando junto com a capa.
* Coluna esquerda: a contagem de tempo saiu e entrou **"A seguir:"** com a próxima música prevista.
* Canto inferior direito: **rotação medida** (fator, desvio em % e incerteza).
* Colunas reequilibradas para a letra maior (18% | letra | 27%).
* **Tela sempre acesa:** a TV entrava na proteção de tela durante a letra. O receptor agora usa a Screen Wake Lock API e, como reforço, mantém um vídeo mudo de 1 quadro/s tocando (tratado pela TV como mídia ativa); reaplicado a cada minuto e ao voltar a ficar visível.
* O celular passa a enviar à TV a próxima música prevista, o lado do disco e a incerteza da rotação.

### ⏭️ "Sugar Free" (Radish) pulava abruptamente para a próxima música
* **Causa (logcat):** a duração usada (114s) veio de um cadastro de texto simples de outra edição no provedor de letras; a faixa real tem mais de 3 minutos. O fim "chegava" cedo e o modo preditivo trocava de música; ao ouvir a mesma música de novo, a duração errada era mantida e o app entrava num ciclo de trocas a cada ~35s.
* A duração da **tracklist do disco (catálogo)** agora tem prioridade sobre a do provedor de letras.
* Se o microfone ouvir uma posição além da duração conhecida, essa duração é descartada como inconsistente (o fim passa a ser detectado pelas checagens).
* Checagens de sincronia com **12s** de captura: no logcat, capturas de ~5.6s de faixas menos conhecidas quase nunca casavam, e a letra não era realinhada.

### 🧪 Qualidade
* Novos testes do caso "Sugar Free" (duração inconsistente e prioridade do catálogo). Suíte: 130 testes verdes.

---

## [v1.2.00] — 07/10/2026 (Nova Tela da TV + Letras Sincronizadas + Reconhecimento + Reconexão)

> Nova numeração de versão a partir desta release (1.2.xx). Inclui todo o conteúdo preparado como v1.1.11, que não chegou a ser publicada.

### 📺 Tela da TV redesenhada (web_receiver/index.html) — layout aprovado por esboço
* **Disco de vinil no canto superior direito**, na proporção de um EP / compacto 7" (selo ≈ 51% do diâmetro): a borda do selo encosta no topo e na lateral direita da tela, e a circunferência aparece onde couber, por trás da letra.
* **Selo = capa do álbum em formato circular, girando a 45 RPM** (pausa junto com a música); sulcos concêntricos com reflexos fixos, faixa lisa de entrada e área lisa final em volta do selo.
* **Agulha horizontal** (cápsula + braço vindo da direita) que **começa no sulco externo, embaixo, e sobe até o selo** conforme a música avança, acompanhada do tempo **"decorrido / total"**; a parte já tocada do disco fica levemente tingida.
* **Letra centralizada, sem karaokê:** as **3 linhas principais (anterior, atual e próxima) com o mesmo tamanho e em destaque**, para que pequenas diferenças de timestamp sejam pouco perceptíveis; as demais diminuem e escurecem conforme se afastam. Véu escuro discreto mantém a legibilidade sobre o disco, sem cobrir o caminho da agulha.
* **Fluidez:** a TV interpola a posição a 60fps (`requestAnimationFrame`) e calcula a linha ativa localmente; os pacotes do celular (2x/s) apenas corrigem a fase suavemente (sem saltos por jitter de rede).
* Coluna esquerda apenas com título, artista, álbum e tempo; capa desfocada como fundo ambiente.
* Avisos discretos ("Vire o disco", "Pausado", "Ouvindo o disco"); modo `?demo` para visualizar sem o celular.
* A página servida pelo celular ao navegador da TV (`tv_web_receiver_html.dart`) agora é **gerada do mesmo arquivo** (`tool/sync_tv_receiver.ps1`); um teste garante que não divergem.
* ⚠️ A TV com Google Cast carrega o receptor do GitHub Pages (`integralist88/vinylyric-tv`), que estava desatualizado desde antes da v1.1.08. É preciso publicar o novo `index.html` lá.

### 📶 Transmissão caindo de repente
* Heartbeat (PING) enviado ao `receiver-0` (nível de plataforma), como nas bibliotecas de referência, em vez da aplicação.
* Quedas não solicitadas disparam **reconexão automática** (2s, 5s, 10s), adotando o app ainda aberto na TV; durante a reconexão o celular permanece no modo TV (`isCastActive`). O motivo da queda é registrado no log.
* O receptor responde `client_ready` apenas ao `hello` (antes respondia a cada pacote de sincronia).

### 📝 Letras não encontradas (ex.: Millencolin — Mr. Clean)
* **Causa:** a busca exata da LRCLIB retornava a edição de um álbum só com texto simples; o app aceitava a resposta e não tentava a busca ampla, onde existe a versão sincronizada.
* A busca ampla agora roda quando falta LRC, filtra por artista e título (antes aceitava o 1º resultado de qualquer artista) e prefere LRC coerente com a duração.
* Sem LRC em nenhuma fonte, usa o texto simples da LRCLIB antes do Lyrics.ovh.
* Letra em texto simples guardada no cache não impede mais a busca de uma versão sincronizada; ao encontrar, ela substitui as cópias antigas da mesma faixa em outros discos do cache (antes a cópia antiga continuava sendo a encontrada primeiro).

### 🎵 Músicas não reconhecidas (ex.: Radish, Bad Religion)
* Diagnóstico pelo logcat: respostas HTTP 200 **sem correspondência** com sinal bom (480–700 picos) — a assinatura era curta demais.
* Comparação com a referência SongRec: no modo microfone ela usa um buffer de **12s**; o app usava 5s. Agora: 6s na 1ª tentativa e 12s nas seguintes (escuta manual, confirmação e próxima faixa).
* Preenchimento final de silêncio como no SongRec (os últimos ~0.4s da gravação antes nunca eram analisados) e janela de Hanning idêntica à de referência.

### 🎛️ Rotação
* Detecção de troca de hardware/fonte: uma medição precisa incompatível com o histórico (ex.: de áudio digital para toca-discos real) substitui o modelo em vez de levar várias faixas para convergir. Piso de incerteza elevado para ±0.15%.

### 🧪 Qualidade
* Novos testes: `test/tv_receiver_and_lyrics_test.dart` (paridade dos receptores, caso Mr. Clean, cache, troca de hardware) e alinhamento com a referência SongRec em `test/shazam_signature_test.dart`. Suíte: 128 testes verdes.

---

## [v1.1.10] — 07/10/2026 (Novo Modelo de Rotação por Regressão + Continuidade de Faixas + TV)

### 🎛️ Rotação: sistema reescrito (estava travado em 1.000x)
* **Diagnóstico:** a 2ª amostra fixava em 1.000x qualquer desvio de até ±2% (zona morta), a média móvel arredondava de novo para 1.000x dentro de ±1.5%, e ao chegar em 1.000x a vitrola era marcada como "calibrada" — o que desligava todas as medições seguintes. Desde a v1.1.09 esse 1.000x ainda era persistido e reaplicado em cada sessão.
* **Novo `lib/engine/speed_estimator.dart`:**
  - `TrackSpeedFit`: regressão linear (mínimos quadrados) de tempo real × posição da música sobre todas as escutas reconhecidas da faixa. A rotação é a inclinação; o erro cai com o intervalo coberto (≈ ±0.2% após 2 minutos). Sem zona morta. Outliers acima de 1s (pulo de agulha, match errado) são descartados.
  - `TurntableSpeedModel`: rotação do toca-discos como média + incerteza; cada faixa concluída é fundida pelo inverso da variância e a faixa atual combina esse conhecimento com a própria regressão. Persistido com desvio-padrão; a incerteza cresce com os dias sem medição. Registros antigos (sem incerteza) entram com confiança moderada para que o 1.000x travado seja corrigido rapidamente.
* **Checagens de sincronia unificadas:** as 8 rotinas antigas (2ª/3ª amostra, meio da faixa, watchdog de pulo de agulha — ~450 linhas) foram substituídas por um agendador único: 20s, +45s e depois a cada 75s até perto do fim da faixa.

### 🎯 Timestamp da letra
* Toda escuta reconhecida realinha a letra no timestamp ouvido (a posição desde a captura passa a ser projetada na rotação medida, não em 1.000x fixo).
* Se uma checagem ouvir outra música (duração de catálogo divergente, faixa pulada), o app transita imediatamente para ela.
* Quando o fim estimado chega cedo e a mesma música ainda toca, a letra é realinhada e a duração estendida (antes ficava sem agendamento).

### ⏭️ App parava após a 2ª música
* **Causa:** ao confirmar a música prevista, com a rotação "calibrada", nenhum agendamento era feito — nem fim de faixa nem checagens — e nada mais acontecia. Corrigido: a confirmação sempre agenda checagens e o fim da faixa. Teste de regressão reproduz o travamento na v1.1.09 e passa na v1.1.10.

### 📺 Transmissão para a TV
* **TV não trocava de música:** o modo preditivo nunca enviava a nova faixa para a TV. Agora a faixa prevista é enviada na hora e reenviada com metadados confirmados.
* **Desconectar não fechava a TV:** a desconexão pelo usuário agora limpa a tela e envia o comando `STOP` do receiver Cast (com o `sessionId` da aplicação), fechando o app na TV.
* **Somente telas na lista:** caixas de som e grupos de áudio são filtrados (bit de vídeo do TXT `ca` do mDNS, `display_supported` do Eureka e modelo: Google Home/Nest Mini/Nest Audio/Chromecast Audio/grupos). A classificação só-áudio não é perdida em sondagens posteriores.

### 🎵 Reconhecimento
* Gravação passa a usar a fonte `VOICE_RECOGNITION` do Android (sem AGC/supressão de ruído de voz, que degradavam a assinatura em aparelhos como Samsung). Para isso o override de `record_platform_interface` foi atualizado de 1.0.2 para 1.5.0 (a versão exigida por `record_android`) e `record_linux` para ^1.0.0 (a 0.7.x quebrava a compilação, motivo do override antigo).
* 2ª tentativa de identificação ampliada de 8s para 10s.
* Motivo de cada falha (`no_match`, `http_xxx`, erro de rede) e quantidade de picos registrados no log da sessão (exportável tocando e segurando a etiqueta de versão); a mensagem na tela distingue "música não identificada" de falha de conexão.

### ⚡ Desempenho
* O ticker de 60fps notifica a interface na troca de estrofe ou no máximo 2x/s (antes ~6x/s pela condição `posição % 0.5`).

### 🧪 Qualidade
* Nova suíte `test/speed_and_sync_redesign_test.dart` (12 testes): regressão, outliers, áudio digital, fusão bayesiana, continuidade até a 3ª música com TV, STOP na desconexão, filtro de caixas de som. Suíte completa: 119 testes verdes.

---

## [v1.1.09] — 07/10/2026 (Correções de Robustez do Motor + Limpeza de Código Morto)

### 🐞 Correções de Bugs (auditoria completa de código)
* **Prior de velocidade do toca-discos preservado:**
  - Diagnóstico: `_resetState()` (chamado no início de `startListening()`) zerava `_confirmedHardwareSpeed` e `_speedFactor`, descartando a rotação restaurada do cache. O recurso `kUsePersistedSpeedPrior` nunca tinha efeito real.
  - A rotação estável (persistida ou consolidada na sessão) agora é mantida em `_persistedSpeedPrior` e reaplicada a cada reinício de escuta.
* **NetEase via HTTPS:** a busca usava `http://music.163.com`, bloqueado pelo Android 9+ (cleartext), fazendo a fonte falhar silenciosamente. Endpoint migrado para `https://`.
* **Retificação de capa tardia descartada com segurança:** o resultado assíncrono de `resolveAlbumCover` agora é ignorado se a sessão foi parada/reiniciada ou se a faixa em reprodução mudou, evitando travar o álbum ou trocar a capa da música errada.
* **Nudge nunca mais perdido:** novo `_flushPendingNudge()` grava o ajuste em debounce antes de `stop()`/reinício e também na transição pelo Modo Preditivo (antes só `_transitionToNewTrack` gravava).
* **Pausa/retomada robusta:**
  - Pausar antes da calibração dos 15s não pula mais a medição de rotação: ao retomar, um novo baseline é estabelecido (o tempo pausado invalida o anterior) e a calibração é reagendada.
  - Pausar durante "Vire o disco" agora retoma corretamente a espera e as sondagens de virada, em vez de reiniciar o ticker com status "calibrado".
* **Descoberta de TVs sem dispositivos fantasmas:** `_resolveCastDeviceInfo` retorna `null` quando nem Eureka (8008) nem CastV2 (8009) respondem — hosts recentes offline não aparecem mais na lista. O `HttpClient` de cada sondagem passou a ser fechado (vazamento de recursos).
* **Fonte preferida Lyrics.ovh:** uma letra em texto plano gravada como fonte preferida era rejeitada (sem timestamps) e a própria fonte era pulada na cascata, impedindo nova obtenção. Agora `lyrics.ovh` permanece como último recurso da cascata.
* **Versão única na interface:** o diálogo de informações exibia `v1.1.07` e o título `v1.1.08`. Criada a constante `kAppVersion` (`lib/app_info.dart`), validada contra o `pubspec.yaml` por teste.

### 🧹 Limpeza de Código Morto
* Removidos `TvLyricsScreen` (receptor legado de TV) e `AudioWaveformVisualizer`, não referenciados.
* `AudioRecordService`: removidos seleção/listagem de microfones USB (`selectUsbMicrophone`, `listInputDevices`, `isUsbDevice`) e o polling de amplitude a cada 60ms (stream sem consumidores). Mensagem de permissão adaptada para smartphone.
* `VinylTelemetry.isUsbMic` e `CalibrationStatus.prefetching` (nunca emitido) removidos.
* `CastSyncService`: removidos resquícios do receptor UDP legado (`discoveryPort`, `discoveryPing`, `discoveryPrefix`, `_discoverySocket`, `stopReceiver`, callbacks `onRemote*`). `CastV2Client.fallbackAppId` removido.
* Removidos `_preprocessVinylAudio` (fora do pipeline desde v1.1.06), `ShazamService._installationUuid`, helpers sem uso do `PrefetchService` e constantes não lidas de `PredictionTuning`.

### 🧪 Qualidade
* `LrcLibService` e `LyricsProviderService` aceitam `http.Client` injetável (testes sem rede).
* Nova suíte `test/bugfix_regression_test.dart` (6 testes) e `test/app_info_test.dart`. Os testes de motor foram validados falhando contra o código da v1.1.08 e passando na v1.1.09.

---

## [v1.1.08] — 07/10/2026 (Transmissão TV Cast V2 Robusta + Modal de Músicas do Álbum)

### 📺 Transmissão para a TV (Google Cast V2 / CAF Receiver) — Fase 1 Completa
* **T1.1: `CastFrameParser` — Parser Streaming de Quadros Protobuf:**
  - Criação do serviço puro `lib/services/cast_frame_parser.dart` para enquadramento e decodificação robusta do protocolo CastV2.
  - Eliminação de quebra de frames TCP/TLS: processa múltiplos quadros concatenados, pacotes partidos byte-a-byte e dados parciais.
  - Limite de segurança de 1 MiB contra estouro de memória e decodificação precisa dos campos protobuf do `CastMessage`.
* **T1.2: `CastV2Client` com Ciclo de Vida Baseado em Estado e Heartbeat PONG:**
  - Abstração `CastSocket` permitindo testes unitários com sockets simulados (`FakeCastSocket`).
  - Resposta automática de `PONG` imediata ao receber `PING` da televisão no namespace de heartbeat.
  - Lançamento inteligente: consulta `RECEIVER_STATUS` via `GET_STATUS` e pula o comando `LAUNCH` caso a aplicação `27687E0B` já esteja aberta na TV.
  - Suporte a cold start de dongles HDMI (ex: Mi TV Stick) com polling a cada 1.2s e retentativa de launch após 10s.
  - Detecção imediata de fechamento remoto da TV via mensagem `CLOSE` ou encerramento do socket, notificando a interface via `onDisconnected`.
  - Isolamento estrito de mensagens customizadas: `sendCustomMessage` despacha exclusivamente para o `transportId` da aplicação ativa.
* **T1.3 & T1.4: `CastDeviceRegistry` e Descoberta Única (Single-Flight):**
  - Criação do serviço puro `lib/services/cast_device_registry.dart` com cache de dispositivos, expiração automática (TTL de 120s) e stream reativo `devicesStream`.
  - Descoberta de rede `discoverDevices` idempotente: requisições concorrentes compartilham o mesmo `Future`, evitando varreduras duplicadas em paralelo.
  - Ordenação estável: televisores e displays de vídeo primeiro, dispositivos de áudio puro depois, ordenados alfabeticamente por nome.
  - Conexão `connectTo` resiliente com até 2 tentativas automáticas e intervalo de 1.5s antes de reportar erro.
* **T1.5 & T1.6: mDNS Inteligente, Varredura /24 e Adição Manual por IP:**
  - mDNS otimizado para interfaces de rede Wi-Fi locais privadas (192.168.x.x, 10.x.x.x, 172.16-31.x.x), ignorando adaptadores celulares/VPN.
  - Preservação de dispositivos em standby: TVs em espera entram na lista identificadas como "Em espera" sem descarte.
  - Varredura de sub-rede /24 com conexões em lote (até 35 em paralelo) e timeout de 600ms na porta 8009 como fallback ou sob demanda.
  - Memória de hosts recentes (`_lastHosts`) para conexão ultrarrápida no início da busca.
  - Suporte a adição manual de IP direto no diálogo com validação e teste na porta 8009.
* **T1.7: Diálogo de TVs (`CastThinkingWheelDialog`) Reativo:**
  - Interface conectada ao `devicesStream` exibindo novos aparelhos progressivamente sem congelamento.
  - Contador dinâmico "Procurando... N encontrado(s)", botões "Buscar na rede" e "Adicionar por IP".
* **T1.8: Web Receiver & Sincronização CAF v3:**
  - `web_receiver/index.html` e `tv_web_receiver_html.dart` atualizados para responder `{"type": "client_ready"}` ao conectar.
  - Criação segura de elementos `<img>` no DOM, sanitizando URLs de capas externas e prevenindo injeções no navegador da TV.
  - Configuração de `disableIdleTimeout: true` e `maxInactivity: 3600` no SDK CAF.
* **T1.10: Higiene do Repositório:**
  - Removido o arquivo duplicado `android/app/src/main/kotlin/com/vinylyric/vinylsync_lyrics/MainActivity.kt`.

### 📀 Diálogo de Músicas do Álbum (Adendo de UI Solicitado)
* **Visualização Completa do Disco ao Tocar na Capa:**
  - Ao tocar na capa do disco (na AppBar superior ou no console de Cockpit no celular), abre-se um modal deslizante com a lista completa de faixas do álbum.
  - Toque no título e artista da AppBar superior também aciona o modal.
  - Destaque visual nítido na faixa em reprodução: ícone de equalizador gráfico ciano e badge "TOCANDO".
  - Destaque na faixa prevista para tocar a seguir: ícone de próximo e badge "A SEGUIR" em neon roxo.
  - Exibição de duração das faixas (mm:ss), lado do LP (A / B) e número original da prensagem.

### 🧪 Suíte de Testes e Qualidade
* **100 Testes Automatizados Verdes:**
  - `test/cast_frame_parser_test.dart`: validação de enquadramento, chunks partidos, payloads Unicode e limites.
  - `test/cast_v2_client_test.dart`: validação com fake socket, handshake, auto-PONG e isolamento de canal.
  - `test/cast_device_registry_test.dart`: validação de TTL (120s), ordenação estável e stream reativo.
  - Zero erros e zero warnings de análise estática (`flutter analyze`).

---

## [v1.1.07] — 07/10/2026 (Isolamento de Rotação por Faixa + Estabilização de Hardware)

### 🎛️ Nova Arquitetura de Rotação Mecânica Independente e Estabilizada
* **Pilar 1: Isolamento e Independência de Rotação por Faixa:**
  - Diagnóstico: o acúmulo residual de filtros EMA entre faixas consecutivas somado à imprecisão de carimbo do Shazam em janelas de 15s causava aceleração artificial acumulada, estourando descompasso crítico a partir da 3ª música (especialmente em áudio digital).
  - Cada nova faixa (seja via transição manual, automática ou Modo Preditivo) inicia com baseline limpo e velocidade isolada (`_speedFactor` resetado para `_confirmedHardwareSpeed ?? 1.000x`).
  - `_firstSampleCaptureTime` e `_firstSampleShazamOffset` são reinicializados a cada nova música, impedindo deltas temporais corrompidos entre músicas distintas.
* **Pilar 2: Separação de Fase (Offset) vs. Frequência (Pitch / Rotação):**
  - O microfone atua primordialmente para **realinhamento de fase** (`_baseOffset = detectedAtNow`), garantindo que o início das estrofes coincida com precisão no som ambiente sem alterar a velocidade do motor.
  - A rotação física do toca-discos só é recalculada se houver baseline sólido e consistente.
* **Pilar 3: Trava Automática de Velocidade Estável de Hardware (`isHardwareSpeedCalibrated`):**
  - Uma vez que a velocidade do toca-discos é aferida na 1ª faixa (ou restaurada do cache), a velocidade do motor é considerada consolidada (`_confirmedHardwareSpeed`).
  - Nas faixas subsequentes da sessão (2ª, 3ª, 4ª...), o sistema dispensa re-calibrações mecânicas aos 15 segundos (`_scheduleSecondSampleCalibration`), eliminando o ruído que causava falsas acelerações na 3ª faixa.
* **Pilar 4: Deadband Adaptativa e Tolerância a Áudio Digital:**
  - Deadband em janelas de 15s expandida para $\pm 2.0\%$, fixando estritamente em **1.000x** qualquer jitter normal de processamento do Shazam em reproduções digitais ou vitrolas nominalmente perfeitas.
  - Outliers calculados fora da faixa física aceitável ($[0.90, 1.10]$) são rejeitados para evitar solavancos espúrios no cálculo de RPM.
* **Qualidade e Testes:**
  - Criada suíte de testes `test/speed_calibration_isolation_test.dart` comprovando o isolamento entre faixas consecutivas e a herança estável da velocidade de hardware sem drift.
  - Suíte completa de testes unitários passando (86/86 testes verdes).
  - Análise estática com zero erros e zero warnings.

---

## [v1.1.06] — 07/10/2026 (Reconhecimento Shazam Digital + Descontinuação de Mic USB)

### 🎵 Correção Definitiva do Pipeline de Fingerprint Shazam e Hardware de Áudio
* **A) Descontinuação de Microfones USB (Exclusividade Smartphone):**
  - Removida seleção automática e forçada de microfones USB herdada da versão legada de TV.
  - `AudioRecordService.selectUsbMicrophone()` transformado em no-op seguro; `isUsbDevice` fixado em `false` e `activeDeviceName` em `'Microfone interno'`.
  - Microfone padrão do sistema sempre utilizado nas gravações sem interferência em aparelhos Xiaomi/Samsung.
  - Rodapé e telemetria atualizados para exibir consistentemente "Microfone interno" sem crachás ou estilização de USB.
* **B) Sample Rate Real do Cabeçalho WAV vs. Hardware:**
  - Diagnóstico da causa raiz: smartphones modernos gravam nativamente em 44.1 kHz ou 48 kHz. Ao impor `sampleRate: 16000` estático do chamador, o áudio sofria compressão de frequência 3:1, impedindo a identificação acústica de bandas/faixas (ex.: Radish – Little Pink Stars).
  - `ShazamSignatureGenerator.generateSignatureFromAudio` agora inspeciona e prioriza rigorosamente o cabeçalho WAV (`wavInfo.sampleRate`).
  - Implementado resampler linear em tempo de execução para converter com precisão 44.1 kHz / 48 kHz para 16 kHz antes da FFT e extração de picos espectrais.
  - Removido o argumento estático `sampleRate: 16000` em todos os pontos de chamada em `VinylSyncEngine`.
* **C) Fingerprint com PCM Cru (Especificação Shazamio):**
  - Removido o pré-processamento de áudio analógico (`_preprocessVinylAudio`) do caminho crítico de assinatura do Shazam.
  - Picos espectrais são extraídos diretamente do fluxo PCM bruto em 16 kHz com matriz de energia intacta.
* **D) Cliente HTTP Estilo Shazamio (iPhone) com Rotação de Identificadores:**
  - Endpoint atualizado para o serviço de descoberta v5 oficial do Shazam para iOS (`https://amp.shazam.com/discovery/v5/en/US/iphone/-/tag/{UUID_UPPER}/{UUID_LOWER}`).
  - Headers atualizados com identificador autêntico de cliente (`X-Shazam-Platform: IPHONE`, `X-Shazam-AppVersion: 14.1.0`, `User-Agent: Shazam/3685 CFNetwork/1197 Darwin/20.0.0`).
  - Geração dinâmica de novos UUIDs por chamada, prevenindo respostas em cache nulo da CDN.
* **E) Janelas Acústicas Ajustadas para Áudio Digital:**
  - Primeira escuta ajustada para 5.0s (5000ms).
  - Janela de repetição (retry) ajustada para 8.0s (8000ms).
* **F) Testes Unitários de Caracterização:**
  - Adicionado teste unitário com geração sintética de WAV a 48 kHz validando a extração do cabeçalho, decodificação do sample rate e geração do fingerprint `0xcafe2580` com sample rate ID `3 << 27`.
  - Validada a desativação da auto-seleção de microfone USB.

---

## [v1.1.05] — 07/10/2026 (Fase 0: Resiliência de Estado, Gravação e Motor)

### 🛡️ Resiliência Arquitetural, Exclusão Mútua e Correções de Estado (Fase 0)
* **T0.1: Limpeza Real de Campos Anuláveis na Telemetria (`VinylTelemetry`):**
  - Adicionados flags explícitos `clearSideEndLabel`, `clearPredictedNext`, `clearTrackDuration` e `clearDiagnosticMessage` no método `copyWith`.
  - Introduzido o estado `isUserListening` para diferenciar escuta ativada diretamente pelo usuário vs. sondagens automáticas em segundo plano.
  - O rótulo "Fim do lado" e previsões herdadas agora são limpos confiavelmente em `_startPrefetch`, `_executeSideFlipProbe`, `_enterWaitingEndOfSide` e `stop()`.
* **T0.2: Exclusão Mútua e Concorrência no Áudio (`AudioRecordService`):**
  - Implementada a abstração `AudioRecorderBackend` com suporte a injeção de dependência e testes unitários com fakes determinísticos.
  - Implementado sistema de prioridade de gravação com enum `RecordPriority` (`user` vs `background`) e tokens sequenciais `_currentToken`.
  - Adicionado `cancelAndWait()` para liberação garantida do hardware de áudio antes de novas capturas.
  - Capturas de usuário agora cancelam imediatamente e de forma limpa qualquer sondagem de background ativa sem colisão de recursos.
* **T0.3: Preempção Confiável no Botão de Ação Flutuante (FAB):**
  - `_onFabPressed` no `vinyl_lyrics_screen.dart` agora verifica `isUserListening` em vez de `isMicActive`.
  - Usuário pode tocar para identificar uma nova música a qualquer instante, cancelando tarefas de fundo e iniciando a captura sem mensagens indevidas de parada.
* **T0.4: Blindagem contra Exceções não Tratadas em Background (`_guarded`):**
  - Todas as rotinas de segundo plano (`_performSecondSampleCalibration`, `_performThirdSampleCalibration`, `_performMidSongCheck`, `_confirmPredictionInBackground`, `_listenAndIdentifyNextTrack`, `_executeSideFlipProbe`, `_checkNeedleSkipFallback`) agora executam encapsuladas em blocos `_guarded`.
  - Falhas de rede ou timeout de gravação são registradas com elegância via `SessionLogService` e telemetria, sem congelar o motor nem travar `isMicActive`.
* **T0.5: Otimização de Persistência em Lote no Cache de Vinil:**
  - Adicionado `setPreferredAlbumBatch` no `VinylCacheService`, permitindo salvar o álbum preferencial para múltiplas faixas com um único I/O de disco.
  - Gravação desvinculada do caminho crítico de áudio com chamada assíncrona desacoplada em segundo plano.
* **T0.6: Guarda de Mesma Faixa em Mid-Song e Cancelamento de Watchdog:**
  - `_performMidSongCheck` e `_checkNeedleSkipFallback` agora verificam se a faixa identificada acústicamente é a mesma atualmente em reprodução (`isSameTrack`). Faixas diferentes não causam saltos incorretos de offset temporal.
  - `_watchdogTimer` (180s) é cancelado e recriado rigorosamente ao transitar entre faixas.
* **T0.7: Duração Individual e Isolada por Faixa:**
  - `_trackDurationSeconds` é resetado para `null` no início de cada troca de faixa (`_autoListenNextTrack` e `_transitionToNewTrack`), impedindo que a duração da música anterior contamine a nova faixa até que o novo LRC ou catálogo seja lido.
* **T0.8: Remoção de Persistência Prematura em `resolveAlbumCover`:**
  - Eliminada chamada antecipada a `setPreferredAlbum` durante a resolução de capas de faixas individuais.
* **T0.9: Instrumentação Diagnóstica Padronizada (`SessionLogService`):**
  - Adicionados eventos de log para `routine_error`, `side_end_reached`, `side_flip_confirmed`, `lock_disc` e `unlock_disc`.
* **Qualidade e Testes:**
  - Suíte completa com 82 testes unitários passando com sucesso (100% verde).
  - Análise estática com zero erros e zero warnings (`flutter analyze`).

#### Decisões Tomadas
1. **Preservação Rígida das Fórmulas Físicas:** Inviolabilidade mantida nas equações de RPM (`SpeedFactor = ΔMúsica / ΔReal`), deadbands e filtros EMA.
2. **Preempção de Microfone:** Ações explícitas do usuário possuem prioridade máxima (`RecordPriority.user`), cancelando silenciosamente rotinas secundárias de predição e calibração de rotação.

---

## [v1.1.04] — 07/10/2026

### 🔒 Trava Estrita de Nome e Capa do Disco Físico (Sem Sobrescrita pelo Shazam)
* **Trava de Sessão do Disco (`isAlbumLocked` / `_lockAlbum`):**
  - Implementado modelo de sessão dedicado no `VinylSyncEngine`:
    - `_lockedAlbumName`: Nome oficial do álbum físico travado.
    - `_lockedAlbumCoverUrl`: URL da capa oficial do disco travada.
    - `_lockedAlbumArtist`: Artista do álbum travado.
    - `_lockedTracklist`: Tracklist oficial completa do disco travado.
    - `isAlbumLocked`: Booleano reativo que indica se o disco está travado.
  - Uma vez identificado o disco físico na sessão (seja via cache local ou catálogo oficial do MusicBrainz), o **NOME** e a **CAPA** permanecem estritamente **TRAVADOS** até o fim da reprodução do disco.
* **Descarte de Metadados de Álbum/Capa do Shazam nas Músicas Consecutivas:**
  - O Shazam continua sendo utilizado com máxima eficiência para título, artista e alinhamento milimétrico do offset temporal da agulha.
  - Nas faixas subsequentes (tanto na predição imediata quanto na confirmação em segundo plano e em `_transitionToNewTrack`), `confirmed.album` e `confirmed.coverUrl` do Shazam são **completamente descartados** se `isAlbumLocked == true`.
  - O aplicativo e o receptor da TV (Google Cast) continuam exibindo ininterruptamente o nome e a capa física do disco original da vitrola, eliminando o comportamento em que coletâneas e singles avulsos alteravam a arte e o título do disco a cada faixa.
* **Predição Orientada à Tracklist do Disco Travado:**
  - `_predictNextTrack` prioriza a ordem física contígua da `_lockedTracklist` antes de qualquer outra heurística, aplicando o nome e capa travados na faixa prevista.
* **Detecção de Anomalias e Destrave Automático:**
  - `_isTrackInLockedAlbum`: Valida se a faixa detectada pertence à tracklist oficial travada.
  - Ao identificar uma faixa anômala (fora da tracklist do disco em reprodução), o motor destrava automaticamente a sessão (`_unlockAlbum`), loga o motivo e permite a identificação e travamento no novo disco.
* **Indicadores Visuais na Interface:**
  - **AppBar (`vinyl_lyrics_screen.dart`):** Linha 2 exibe ícone de disco `Icons.album` neon ao lado do nome do disco quando travado. Capa utiliza `lockedAlbumCoverUrl`. Modal de tracklist exibe a lista do disco travado.
  - **Cockpit (`vinyl_control_cockpit.dart`):** Card principal exibe ícone `Icons.album` neon ao lado do nome do álbum travado e arte gráfica de alta resolução travada.
  - Rótulos de versão atualizados para `v1.1.04`.
* **Testes e Qualidade:**
  - Suíte de testes dedicada em `test/locked_album_test.dart` (100% aprovada).
  - 74/74 testes da suíte global passando com sucesso.

#### Decisões Tomadas
1. **Preservação de Fórmulas de Calibração RPM:** Nenhuma alteração foi realizada nas fórmulas matemáticas do Speed Factor (`ΔMúsica / ΔReal`), deadbands ou filtros EMA.
2. **Descarte Cirúrgico de Metadados:** Apenas os campos `album` e `coverUrl` do Shazam são filtrados quando travados; offset temporal, título e artista continuam sendo aproveitados integralmente para manter o sincronismo acústico preciso da letra.

---

## [v1.1.03] — 07/10/2026

### 🎨 Evolução Visual (+20%) e Correções Críticas de Calibração e Capa do Disco
* **Correção Crítica da Calibração da 3ª Faixa (Eliminação do Travamento do Ticker):**
  - **Sincronização do Baseline de Captura (`_firstSampleCaptureTime` e `_firstSampleShazamOffset`):** Em `_confirmPredictionInBackground`, o motor agora sincroniza o timestamp e o offset acústico com a amostra confirmada. Anteriormente, o motor mantinha o timestamp da 1ª faixa da sessão (400+ segundos atrás), gerando `deltaReal` acumulado gigantesco e colapsando o `speedFactor` para o limite mínimo (0.88x), o que desregulava o cálculo de tempo e congelava o avanço das letras na 3ª música consecutiva.
  - **Blindagem das Amostras 2 e 3 (`_performSecondSampleCalibration` / `_performThirdSampleCalibration`):** Adicionada validação de mesma faixa (`TracklistMatcher.isSameTrack`) e limites estritos de sanidade temporal (`deltaReal` entre 5s e 35s para amostra 2, e 15s a 50s para amostra 3). Amostras fora dessa janela são descartadas para ajuste de rotação, preservando a estabilidade do motor.
  - **Toque no Microfone Sempre Limpo:** `startListening()` agora realiza escuta imediata e limpa a partir do zero, sem interceptações de `waitingEndOfSide` que prendiam o aplicativo caso o usuário tocasse para identificar manualmente.
* **Preservação e Propagação Contínua da Capa do Disco:**
  - `_predictNextTrack` atualizado para propagar a URL da capa (`coverUrl`) em todas as 3 prioridades de predição (TrackPredictor, álbum preferencial e cache em memória).
  - Herança robusta de capa em `_autoListenNextTrack`, `_confirmPredictionInBackground` e `_transitionToNewTrack`, evitando que faixas subsequentes percam a arte gráfica do álbum durante a reprodução contínua.
  - Correção em `PrefetchService.clearSession` para reatribuição limpa de lista (`_currentDiscTracklist = []`), prevenindo exceção de lista imutável.
* **Aprimoramento Visual e Tipográfico da Interface (+20%):**
  - **AppBar (`vinyl_lyrics_screen.dart`):**
    - Seção da capa ampliada em 24% (34px $\to$ 42px com cantos arredondados de 10px).
    - Altura da barra expandida para `toolbarHeight: 74`, acomodando com conforto e legibilidade três linhas estruturadas.
    - **Linha 1:** Nome da Música em destaque (+20%, 17.5px, bold, branco puro).
    - **Linha 2:** Nome do Disco (12.5px, ciano neon, seminegrito).
    - **Linha 3:** Linha de status "A seguir:" / "Fim do lado" (11.5px, roxo neon / âmbar com indicador de letra pronta ⚡).
  - **Cockpit de Controle (`vinyl_control_cockpit.dart`):**
    - Capa do disco ampliada em 21% (76px $\to$ 92px com `borderRadius: 14`).
    - Nome da Música: 20.5px (+20%, negrito).
    - Artista: 16.0px (+18%, ciano neon).
    - Álbum: 14.0px (+21%, branco 70%).
* **Testes e Qualidade:**
  - Nova suíte de testes em `test/prediction_and_cover_fixes_test.dart`.
  - 100% dos testes aprovados (72/72 testes verdes).

#### Decisões Tomadas
1. **Sincronização Imediata em Confirmações de Predição:** Sempre que uma faixa prevista é confirmada pelo microfone via Shazam em segundo plano, o motor atualiza `_firstSampleCaptureTime` e `_firstSampleShazamOffset` para a captura recém-confirmada. Isso garante que qualquer calibração subsequente aos 15 segundos seja calculada em relação à música atual e não ao início da sessão.
2. **Hierarquia Visual de Três Linhas no Topo:** A organização Nome da Música $\to$ Nome do Disco $\to$ "A seguir:" no topo da tela oferece visão completa do contexto do vinil (álbum atual + próxima faixa) sem necessidade de rolagem nem obstrução da visualização das letras no modo retrato.

---

## [v1.1.02] — 07/10/2026

### 🛡️ Fase 2 da Evolução do Sistema de Predição: Robustez do Áudio e Aprendizado Local
* **T2.1: Analisador Acústico de Nível e Silêncio (`AudioLevelAnalyzer`):**
  - Implementado analisador de áudio em janelas de 100 ms (1.600 amostras a 16 kHz PCM 16-bit mono).
  - Cálculo de estatísticas acústicas sem alocações desnecessárias: RMS em dBFS, nível de pico, mediana e percentil 90 (p90).
  - Algoritmo de gate e detecção de silêncio com limiar adaptativo dinâmico (`limiar = referenceMusicDb - 15 dB`), garantindo identificação confiável de silêncio de agulha e intervalos entre faixas, mesmo sob ruído ambiente (ruído de fundo, estalos leves de vinil ou ventilador).
* **T2.2: Captura com Retentativas Persistentes e Eliminação de Chamadas Desnecessárias:**
  - Método `_captureAndIdentify` com política de retry progressiva (`retryDelaysSeconds = [0, 8, 20, 35, 55, 80]` e `giveUpAfter = 90s`).
  - Classificação do áudio em `CaptureOutcome`: `silent` (silêncio), `identified` (identificado com sucesso) ou `unrecognized` (áudio musical presente porém não identificado pelo fingerprint).
  - Amostras silenciosas **não consomem chamadas de rede do Shazam**: a letra prevista permanece visível na tela e na TV enquanto o motor aguarda a agulha tocar o próximo sulco.
  - O app deixa de desligar prematuramente no intervalo entre faixas ("Cenário 3"), permanecendo paciente e resiliente.
* **T2.3: Persistência do Prior de Velocidade da Vitrola (`lastStableSpeedFactor`):**
  - Modelo `CachedTurntableState` persistido em `vinyl_collection.json`.
  - Ao calibrar com concordância $\le 0.4\%$ entre amostras consecutivas (amostras 2 e 3), o fator de rotação estável é gravado em disco.
  - Ao reiniciar o app ou iniciar nova sessão, o fator salvo é restaurado imediatamente (validade $\le 30$ dias e desvio $\le 5\%$), eliminando o atraso de sincronização nos primeiros 15 segundos da primeira faixa.
* **T2.4: Nudge Persistente e Fonte Preferencial de Letras:**
  - Ajuste fino manual de letra (*nudge*) desacoplado da rotação e do relógio: variável dedicada `_lyricBiasSeconds`.
  - O nudge sobrevive a realinhamentos acústicos periódicos do microfone (`seekTo`), corrigindo a frustração do usuário onde o nudge era zerado a cada 15 segundos.
  - Persistência com debounce de 3 segundos no cache local (`CachedTrack.lyricOffsetMs`) e reaplicação automática ao ouvir a mesma música novamente.
  - Rastreamento e persistência da fonte de letra bem-sucedida (`preferredSource` / `lyricsSource`), priorizando na cascata a fonte que comprovadamente entregou a letra correta para aquela música.
* **T2.5: Qualidade, Testes Automatizados e Auditoria:**
  - Testes unitários acústicos em `test/audio_level_analyzer_test.dart` (6 testes).
  - Testes integrados de motor e persistência em `test/vinyl_sync_engine_phase2_test.dart` (6 testes).
  - 100% de testes da suíte passando (70/70 testes verdes) e análise de código sem erros ou avisos.

#### Decisões Tomadas
1. **Gate Sem Trim Destrutivo:** O analisador acústico apenas avalia e classifica a amostra (p90 vs limiar adaptativo). O buffer de áudio original não sofre trim destrutivo, preservando a integridade temporal exata exigida pelo algoritmo do Shazam.
2. **Prior de Velocidade Conservador:** Se o fator salvo no cache exceder desvio de 5% em relação ao nominal (1.000x) ou tiver mais de 30 dias de idade, ele é descartado e o motor inicia com 1.000x, aguardando calibração em tempo real.
3. **Nudge com Limite de Segurança:** O viés acumulado de nudge é limitado a $\pm 10$ segundos (`maxNudgeBiasSeconds`), protegendo a experiência de visualização contra avanços acidentais excessivos.

---

## [v1.1.01] — 06/10/2026

### 🎯 Validação Estrita da Ordem das Músicas e Regra de 3 Faixas Consecutivas para Álbum Preferencial
* **Validação Sequencial de Faixas (`TracklistMatcher.isSequentialMatch`):**
  - Implementado algoritmo determinístico de verificação de ordem que assegura que as faixas tocadas apareçam estritamente em sequência crescente e contígua na tracklist do disco (`idx_next > idx_curr` e `diff <= 2`).
  - Coletâneas ou compilações que contenham as mesmas músicas, mas em posições desordenadas ou invertidas, são **descartadas imediatamente**.
* **Regra de Pelo Menos 3 Músicas Consecutivas para Confirmação de Álbum (`preferredAlbum`):**
  - O `VinylSyncEngine` passa a manter álbuns em estado de observação provisória (`1/3` e `2/3` faixas).
  - O álbum só é persistido em cache como `preferredAlbum` definitivo se a sequência de **pelo menos 3 músicas consecutivas** bater perfeitamente com a tracklist oficial do disco físico.
* **Desambiguação Aprofundada no `PrefetchService` e Cache Local:**
  - `resolveAlbumCover` atualizado para receber o histórico completo de músicas da sessão (`sessionTracks`) e rejeitar candidatos de catálogo cujas tracklists não reflitam a ordem cronológica tocada na vitrola.
  - `findDiscContainingTracks` no `VinylCacheService` agora valida estritamente a sequência das faixas antes de retornar qualquer disco existente.
* **Eliminação de Conflitos no `TrackPredictor`:**
  - Fontes que apresentem conflito de ordem de faixas em relação ao histórico de confirmações da sessão são desqualificadas.
* **Testes Automatizados:**
  - Adicionado teste específico de rejeição de coletânea com faixas em ordem invertida e aprovação de álbum correto após 3 confirmações contíguas em `test/vinyl_sync_engine_sides_test.dart` e `test/tracklist_matcher_test.dart` (58/58 testes verdes).

#### Decisões Tomadas
1. **Mínimo de 3 Músicas Consecutivas para Álbum Preferencial:** Conforme diretriz do teste de campo, uma ou duas músicas de um artista podem coincidir em compilações (coletâneas/"Best Of") e no álbum de estúdio original. Apenas a partir da 3ª música consecutiva confirmada na ordem exata o álbum é gravado como preferencial no cache local (`preferredAlbum`).
2. **Rejeição Imediata de Ordem Divergente (`isSequentialMatch`):** Se uma coletânea possui as mesmas músicas mas em ordem diferente (ou invertida) em relação ao histórico real tocado na vitrola, essa tracklist é sumariamente desqualificada para predição, capa e cache.

---

## [v1.1.00] — 06/10/2026

### 🔄 Fase 1 da Evolução do Sistema de Predição: Detecção de Lados de Vinil & Preditor Determinístico
* **T1.1: `SideEstimator` — Inferência de Lados de Vinil (A/B/C/D):**
  - Três heurísticas em cascata com zero dependências externas:
    1. Lados explícitos vindos do catálogo MusicBrainz / Discogs.
    2. Padrões de numeração de vinil (`A1..A9`, `B1..B9`, `1-01`, etc.).
    3. Partição contínua pelo ponto médio de duração acumulada (com teto máximo de 25 minutos por lado físico de LP de 33⅓ RPM).
* **T1.2: `TrackPredictor` — Motor de Predição Determinístico Desacoplado:**
  - Desambiguação inteligente entre edições e lançamentos múltiplos usando histórico de faixas já confirmadas na sessão (eliminação por adjacência).
  - Resolução categorizada em `PredictionKind`:
    - `next`: próxima faixa contínua do mesmo lado físico.
    - `alternative`: próxima faixa segundo um release alternativo plausível.
    - `afterNext`: pulo de agulha / salto de uma faixa dentro do mesmo lado.
    - `afterFlip`: primeira faixa do próximo lado físico (B1 após término do lado A).
  - Identificação precisa de fim de lado (`endOfSide`, `sideLabel`).
* **T1.3: Refatoração do `PrefetchService` (Cache-First & Tokens de Geração):**
  - Cache em memória estruturado com modelo `PrefetchedTrack` e verificação rápida `hasLyricsFor`.
  - Token de cancelamento/geração (`_generation` monotônico) para interromper imediatamente prefetchs obsoletos caso o usuário troque de música antes da conclusão.
  - Cache negativo de 7 dias (`lyricsMissingSince`, `isLyricsMissingRecent`) no `VinylCacheService` para evitar chamadas de rede repetitivas e desnecessárias para faixas sem letras conhecidas.
* **T1.4: Fluxo de Virada de Disco e Confirmações no `VinylSyncEngine`:**
  - Fim de lado físico entra no estado `waitingEndOfSide` (D5 resolvido), pausando timers e exibindo aviso claro de virada de disco.
  - Sondagem de áudio periódica silenciosa (10s inicial, 15s subsequentes até 5min de timeout) e transição imediata ao toque do usuário no botão de microfone.
  - Regra de 2 confirmações consecutivas no mesmo álbum antes de persistir `preferredAlbum` (D9 resolvido), impedindo que coletâneas ou identificações isoladas corrompam a associação de discos.
  - Resolução estrita cache-first de letras em `_resolveLyricsFor` (D11 resolvido): Memória (0ms) ➔ Disco Local (0 rede) ➔ Cascata de Provedores.
  - Alinhamento de offset na troca de faixa: `_currentPositionSeconds = _baseOffset`.
* **T1.5: Telemetria & Experiência de Usuário (Cockpit e Telas):**
  - Banner "🔄 FIM DO LADO A — VIRE O DISCO" com badge estilizado e proteção contra overflow.
  - Indicador de prontidão de letras no card "A seguir": exibe `⚡ pronta` quando o LRC já está na memória ou `buscando letra...`.
  - Rótulo de versão atualizado para `v1.1.00`.
* **T1.6: Cobertura de Testes Automatizados:**
  - Novos testes dedicados em `test/side_estimator_test.dart`, `test/track_predictor_test.dart` e `test/vinyl_sync_engine_sides_test.dart`.
  - 100% de testes verdes (56/56 testes passando) e análise estática sem erros ou avisos.

#### Decisões Tomadas
1. **Conservadorismo na virada de disco:** Ao atingir a última música de um lado, a próxima faixa não é exibida preditivamente como contínua — o motor transita para `waitingEndOfSide` e prepara em background a letra da primeira faixa do lado seguinte (`afterFlip`).
2. **2 Confirmações Consecutivas para Álbum Preferencial:** Nenhuma faixa grava `preferredAlbum` no cache no primeiro reconhecimento; apenas após duas faixas consecutivas pertencerem ao mesmo lançamento o álbum é gravado como preferencial para as faixas da sessão.
3. **Prevenção de sobrescrita acidental no Cache:** Adicionado lock de inicialização (`isInitialized`) e barreira de fila de escrita (`_saveQueue`) em `VinylCacheService` para garantir que leituras de disco não sobreponham discos adicionados em memória durante o ciclo de inicialização concorrente.

---

### 🧠 Fase 0 da Evolução do Sistema de Predição & Tracklist Oficial
* **T0.1: `TracklistMatcher` Unificado:** Normalizador textual e fonético puro em Dart (zero dependências externas), com mapa completo de desacentuação Unicode, remoção segura de sufixos de estúdio (*Remaster, Live, 2011 Mix*) com preservação estrita de qualificadores narrativos (*Part 2, Reprise*), similaridade de Levenshtein (limiar 0.85/0.88), localização de faixas homônimas via `expectedIndex` e geração de chave canônica para cache.
* **T0.2: Modelo de Tracklist Oficial e Persistência Atômica (`VinylCacheService`):**
  - Criação da entidade `TrackEntry` (posição sequencial, número/faixa de catálogo, lado físico do vinil e duração em milissegundos).
  - Migração de schema de dados para v2 em `vinyl_collection.json`, preservando a ordem oficial do disco e impedindo a regressão D1 (onde a faixa ouvida primeiro desordenava o álbum).
  - Escrita atômica em disco com arquivo temporário (`.tmp`) e backup de segurança (`.bak`), recuperação automática de corrupção e fila assíncrona serializada para evitar colisões de concorrência.
* **T0.3: Provedor de Catálogo Isolado (`MusicBrainzTracklistProvider`):**
  - Isolamento da consulta de catálogos via interface `TracklistProvider`.
  - Controle de fluxo e rate limiting rigoroso (intervalo >= 1100ms) com retry automático em caso de respostas HTTP 429 ou 503.
  - Pré-pontuação de lançamentos priorizando mídias físicas em vinil (+25 pontos) e versões de estúdio oficiais (+20 pontos).
  - `PrefetchService` atualizado para consultar o cache local antes da rede e limitar consultas de capas a no máximo 4 candidatos.
* **T0.4: Confirmação Endurecida e Engine Desacoplado (`VinylSyncEngine`):**
  - Remoção de métodos redundantes no engine; predição baseada em `TracklistMatcher.findIndex`.
  - Confirmação em segundo plano via Shazam endurecida com `TracklistMatcher.isSameTrack()`, impedindo que uma música similar rejeite erroneamente a predição correta.
* **T0.5: Auditoria de Eventos da Sessão (`SessionLogService`):**
  - Registro de eventos do ciclo preditivo (`track_recognized`, `prediction_shown`, `prediction_confirmed`, `prediction_rejected`) em formato JSON Lines (`vinylyric_events.jsonl`).
  - Rotação automática configurada para 2.000 linhas ou 512 KB sem bloquear threads de áudio.
  - Exportação instantânea dos últimos logs tocando e segurando (long-press) a etiqueta de versão na barra superior ou na tela de informações.
* **T0.6: Parser LRC Tolerante e Resiliente (`LrcParser`):**
  - Processamento de tags de compensação temporal `[offset:±ms]`, aplicando correção de avanço/atraso precisa nas letras.
  - Suporte a minutos com 1 dígito (`m:ss.xx`) e separador de fração com dois pontos (`:` ou `.`).
  - Remoção automática de marcações de karaokê por palavra (`<mm:ss.xx>`) e deduplicação de estrofes idênticas consecutivas preservando marcadores instrumentais.
* **T0.7: Modal Interativo de Faixas do Álbum e Interface:**
  - Toque na capa do disco (na barra superior ou no console Cockpit da TV) abre um painel modal deslizante com a tracklist oficial do álbum, número/lado, tempo de cada faixa e indicador animado da música tocando no momento.

#### Decisões Tomadas
1. **Zero Dependências Extras:** O `TracklistMatcher` foi construído com tabela estática em memória para conversão de acentos e diacríticos em vez de incluir pacotes como `diacritic` no `pubspec.yaml`, preservando o tamanho mínimo do APK.
2. **Resiliência do Cache Local:** O carregamento do arquivo de discos recupera automaticamente do backup `.bak` se o arquivo `.json` principal estiver corrompido, e arquivos inválidos são renomeados para `.corrupt` para auditoria.
3. **MusicBrainz Rate Limiting:** As chamadas de rede para o catálogo respeitam o intervalo de 1100ms através de encadeamento sequencial, protegendo o IP do usuário contra bloqueios na API.

#### Limitações Conhecidas
* A inferência automática de virada de lado ("Vire o Disco" / Lado B) baseada em contagem de tempo acumulado e o motor de predição desacoplado (`TrackPredictor`) serão introduzidos na Fase 1.

---

## [v1.0.012] — 06/10/2026

### 🎶 Cascata Multi-Provedores de Letras Sincronizadas (Multi-Source Lyrics Cascade)
* **Novo Serviço Orquestrador (`LyricsProviderService`):** Implementada arquitetura de busca resiliente em cascata para resolver o problema de faixas sem letra sincronizada (especialmente catálogo nacional, MPB e discografias menos populares).
  1. **Fonte 1 (Primária) — LRCLIB:** Mantida como referência inicial para metadados de estúdio e letras sincronizadas de alta precisão.
  2. **Fonte 2 (Secundária) — NetEase Cloud Music (网易云音乐):** Integração com o gigantesco acervo aberto do NetEase. Fornece cobertura completa para MPB, bossa nova, samba, pop e rock internacional clássico com timestamps em milissegundos.
  3. **Fonte 3 (Terciária) — Megalobiz:** Consulta ao arquivo comunitário de arquivos `.lrc` com proteção contra timeouts.
  4. **Fonte 4 (Fallback) — Letra em Texto Plano (Lyrics.ovh):** Quando nenhuma fonte possuir marcação de tempo, a letra é recuperada em texto simples e ritmicamente espaçada.
* **Interrupção Imediata na Primeira Fonte Sincronizada:** O serviço interrompe a busca assim que detecta o primeiro provedor com timestamps (`[`), economizando banda e entregando exibição quase instantânea.
* **Evolução do Parser LRC (`LrcParser`):** Atualizado para receber parâmetros de duração estimada (`estimatedDurationSeconds`). Caso receba uma letra em texto puro, calcula e projeta o avanço das estrofes ao longo do tempo da música sem deixar a tela em branco.
* **Integração no Motor de Vinil (`VinylSyncEngine`) e Pré-Carregamento (`PrefetchService`):**
  - O prefetch agora busca na cascata em segundo plano durante a rotação do disco.
  - O modo preditivo ao final de cada faixa herda automaticamente a nova cobertura estendida.

---

## [v1.0.011] — 06/10/2026

### 🌐 Compatibilidade Total e Resiliência de Rede Multi-OEM (Samsung One UI + Xiaomi + Android 10 ao 14)
* **Trava Nativa de Multicast (`WifiManager.MulticastLock`):** Implementada a aquisição da trava de hardware no ciclo de vida Android (`MainActivity.kt`). Corrige a falha crônica do Samsung One UI que desliga a recepção de pacotes mDNS/Chromecast (porta 5353) na placa de rede Wi-Fi por economia de bateria.
* **Trava de Wi-Fi de Alta Performance (`WifiManager.WifiLock - HIGH_PERF`):** Impede que o sistema operacional coloque o rádio Wi-Fi em estados de latência estendida (DTIM sleep) durante a transmissão de letras e telemetria de rotação.
* **Blindagem contra Adaptadores Virtuais P2P da Samsung:** O algoritmo de detecção de IP local (`getLocalIpAddress()`) agora descarta expressamente adaptadores virtuais como `p2p-wlan0-0`, `swlan`, `dummy`, `tun` e `rmnet`, garantindo que o IP local seja sempre o endereço real da rede residencial (`192.168.x.x` / `10.x.x.x`), impedindo que a TV tente acessar o servidor Web Receiver em sub-redes P2P inacessíveis.
* **Otimização da Sonda de Sub-rede TCP (Porta 8009):** Aumento do timeout de conexão de 350ms para 750ms e redução do lote de conexões concorrentes de 20 para 10. Isso respeita os tempos de resposta de chips Wi-Fi da Samsung e de TVs em repouso sem gerar falsos timeouts nem saturar a pilha de sockets local.
* **Timeouts Aumentados para Handshake CastV2 e Eureka:** Timeout de inicialização TLS expandido para 6.0s e inspeção de status estendida para 1.2s.
* **Suporte Completo ao Android 13 e 14:** Adicionadas as permissões `NEARBY_WIFI_DEVICES` (com a flag `neverForLocation`) e `WAKE_LOCK` no `AndroidManifest.xml`, garantindo compatibilidade contínua e sem restrições tanto em aparelhos Android 10 (como o Xiaomi Redmi 9A) quanto nos modelos topo de linha da Samsung (Galaxy S/A/Z com Android 13 e 14).

---

## [v1.0.010] — 05/10/2026

### 🎨 Modernização Estética e Hierarquia Visual na Tela Principal
* **Nome da Música no Topo Substituindo "VinylSync":** Quando uma faixa está tocando, o nome da música ativa substitui diretamente o texto "VinylSync" ao lado da capa do disco na barra superior (AppBar), oferecendo identificação imediata e eliminando redundâncias visuais.
* **Música a Seguir em Formato Compacto Abaixo da Principal:** O título da próxima música prevista do disco (`predictedNextTrackTitle`) é exibido com tipografia menor e cor neon roxo logo abaixo do título principal (`A seguir: ...`), mantendo o ouvinte informado sem poluir a interface.
* **Remoção do Banner Flutuante Central:** Eliminado o antigo banner que ficava sobreposto no meio da tela de letras, liberando 100% da área útil do display para a rolagem das estrofes sincronizadas.
* **Inversão dos Ícones da Barra Superior:**
  - O ícone de **Informações / Como Funciona** (`Icons.info_outline`) agora fica posicionado no canto superior esquerdo (`leading`).
  - O ícone oficial de **Transmissão para TV / Chromecast** (`_buildCastButton`) foi transferido para o canto superior direito (`actions`), em conformidade com as diretrizes de design do ecossistema Google Cast.

### 🎛️ Rodapé Limpo e Prevenção de Estouro de Parâmetros
* **Remoção de Título e Artista no Rodapé:** Os nomes da música e da banda foram totalmente removidos da barra inferior (`VinylStatusFooter`), deixando o espaço dedicado unicamente à telemetria mecânica da vitrola.
* **Telemetria Centralizada e Ajuste Fino em 1 Toque:** O rodapé exibe com destaque o status de calibração (`statusMessage`) e contagem regressiva em segundos. O badge estroboscópico de RPM agora é interativo: basta tocar nele para abrir ou fechar o controle deslizante de Pitch.
* **Blindagem Total contra Overflow de Texto:** Todos os textos do rodapé e badges de microfone utilizam `Expanded`, `Flexible` e `TextOverflow.ellipsis`, impedindo que títulos longos ou nomes de dispositivos de áudio extrapolem as dimensões da tela em celulares compactos.

### 📺 Lista de Dispositivos Cast com Ocultação de Endereço IP
* **Exibição Limpa de Aparelhos:** Na lista de TVs e Chromecasts detectados, o endereço IP técnico (`IP: 192.168.x.x`) foi suprimido, exibindo **exclusivamente o nome amigável do dispositivo** (ex: *"TV Quarto (Mi Stick)"*).

---

## [v1.0.009] — 05/10/2026

### 📺 Resolução Definitiva de Nomes e Filtragem de Dispositivos Cast
* **Eliminação de Dispositivos em StandBy (TV Desligada):** A busca por sonda TLS (porta 8009) agora verifica o estado `isStandBy` via handshake CastV2. Aparelhos desligados ou em repouso (como a TV da Sala com tela inativa) são sumariamente excluídos da lista de seleção.
* **Filtro Rigoroso Contra Caixas de Som (Google Nest / Home):** Inspeção de propriedades de equalização de áudio (`high_shelf`, `noise_level`). Caixas puramente de áudio (Google Nest Quarto e Sala) não são mais listadas como alvos de projeção visual.
* **Identificação Correta do Xiaomi Mi TV Stick:** O dispositivo de streaming do quarto agora é detectado e rotulado com precisão como `"TV Quarto (Mi Stick)"`.
* **Varredura com Cache Limpo:** Toda nova busca limpa os aparelhos descobertos anteriormente, impedindo o surgimento de dispositivos fantasmas ou IPs obsoletos.

### 🎨 Proporção e Fluidez Otimizada na TV (Web Receiver)
* **Ajuste de Proporção no Layout:** Redução do diâmetro do disco de vinil e capa de álbum (de 320px para 230px) no Web Receiver local e hospedado. A área de texto das letras sincronizadas agora ocupa 70% da largura útil da televisão (coluna esquerda reduzida para 30%).
* **Rolagem Macia por Hardware:** Substituição de `scrollIntoView` por algoritmo de rolagem centralizada via CSS/JS (`container.scrollTo({ behavior: 'smooth' })`) com aceleração gráfica (`will-change: transform, color, opacity`), eliminando solavancos e engasgos visuais em TVs e sticks com processamento modesto.
* **Compensação de Latência de Transmissão (Lookahead de +400ms para TV):** Implementado adiantamento inteligente de sincronismo específico para a TV (`tvLeadTimeMs = 850ms`, sendo 400ms além do lookahead mobile de 450ms). Isso neutraliza o atraso de buffer da rede Wi-Fi e tempo de decodificação da televisão, fazendo a estrofe iluminar exatamente com a voz do cantor.

### 📱 Cockpit Exclusivo no Smartphone Durante Transmissão
* **Ocultação Estrita da Letra no Celular Durante o Cast:** Quando a conexão com a TV está ativa, a interface móvel desativa totalmente a tela de rolagem de letras. O celular exibe com exclusividade o **Cockpit de Controle do Vinil** (estabilização RPM, drift mecânico, trava de pitch e controles de reprodução), transformando o smartphone em uma central de controle audiófilo enquanto a TV projeta a experiência visual imersiva.

---

## [v1.0.008] — 05/10/2026

### 📺 Diagnóstico e Blindagem da Conexão Cast (Resolução de Falsos Positivos)
* **Eliminação de Confirmação Prematura:** O app não assume mais falsamente que a conexão foi estabelecida antes de receber a resposta oficial da TV. A confirmação verde/ciano só é ativada quando o `RECEIVER_STATUS` da TV traz o `transportId` ativo do aplicativo.
* **Remoção do Fallback Silencioso para `CC1AD845`:** Removida a tentativa inútil de redirecionar para o Default Media Receiver que causava tela preta/congelada na TV. Se o App ID personalizado falhar ou for recusado pela TV (`LAUNCH_ERROR`), o app reporta o erro real com clareza.
* **Parser Robusto de Frames CastV2 com Profundidade JSON:** O leitor de pacotes TLS foi reescrito com algoritmo de rastreamento de chaves (`{ ... }`), permitindo extrair múltiplos blocos JSON concatenados sem corromper mensagens de status ou erros.
* **Aumento de Timeout de Conexão (6.0s):** Tempo limite de resposta estendido de 2.5s para 6.0s para permitir que aparelhos de TV mais lentos ou com Wi-Fi oscilante baixem e inicializem o Web Receiver.
* **Feedback Visual Completo e Contingência em 1 Toque no Modal:**
  - Etapas visuais explícitas: "Conectando ao Chromecast via TLS...", "Aguardando TV iniciar o App ID...", ou "A TV não abriu o App Cast".
  - Se a TV retornar `LAUNCH_ERROR (NOT_FOUND)`, o diálogo exibe alerta ambar explicativo e oferece imediatamente o botão **"TRANSMITIR VIA NAVEGADOR (PLANO B)"**, direcionando o usuário para o servidor local (`http://<IP>:8088`) que funciona de forma 100% autônoma e offline.
* **Identificação da Causa Raiz do App ID 27687E0B:** Identificado que o repositório GitHub Pages (`integralist88/vinylyric-tv`) continha apenas o `README.md` (página Jekyll padrão), sem o arquivo `web_receiver/index.html`. Instruções detalhadas adicionadas para publicação do Web Receiver estático.

---

## [v1.0.007] — 05/10/2026

### 📺 Resolução da Transmissão para TV & Nomes Reais dos Aparelhos
* **Nomes Amigáveis Reais via Eureka API (Porta 8008):** Durante a varredura e sonda de sub-rede, o aplicativo agora consulta diretamente o endpoint HTTP Eureka nativo do Chromecast (`http://<IP>:8008/setup/eureka_info`), obtendo o nome real atribuído pelo usuário à TV (ex: "Sala", "TV Philips") em vez de rótulos genéricos com IP.
* **Eliminação Definitiva de Caixas de Som (Google Nest / Home):** Dispositivos puramente de áudio (como o "Google Nest Quarto") são descartados de imediato pela verificação de capacidades de vídeo e lista de exclusão estrita, exibindo **exclusivamente televisores e telas**.
* **Transport ID e Handshake de Dados CastV2:** O cliente CastV2 agora escuta a resposta `RECEIVER_STATUS` da TV, extrai o identificador de sessão (`transportId`) do receptor e conecta diretamente o canal de dados nele.
* **Fallback Transparente para Receptor Universal (`CC1AD845`):** Caso o App ID personalizado (`27687E0B`) ainda esteja em período de propagação global nos servidores do Google, o app faz fallback automático e instantâneo para o Default Media Receiver (`CC1AD845`), garantindo projeção sem erros na TV.

### ⚡ Reconhecimento Ultra-Rápido & Janela Adaptativa
* **Captura Primária Otimizada (3.5s):** Primeira escuta reduzida para 3.5 segundos para garantir que a identificação aconteça antes do fim do início da música ou no término da anterior.
* **Janela Adaptativa Estendida (7.0s):** Em situações de sinal fraco, faixas instrumentais sutis ou chiado mecânico de vinil, o app dispara automaticamente uma segunda captura estendida de 6.5s a 7s, aumentando drasticamente a taxa de acerto.
* **Pré-Processamento Acústico de Vinil:** Adicionada normalização de pico de amplitude e filtro passa-altas IIR (~50Hz) para eliminar o "rumble" mecânico de motores de vitrola e desvios DC de discos empenados antes da FFT.

### 🔮 Predição de Disco & Transição Instantânea
* **Banner de Próxima Música no Cockpit e Tela de Letras:** Enquanto a faixa atual toca, a próxima música provável do álbum físico é mapeada via MusicBrainz/LRCLIB e destacada na tela com ícone de vinil.
* **Auto-Listen com Zero Espera:** Ao término da faixa, o motor não aguarda 2 segundos extras; o reconhecimento da próxima faixa inicia no instante exato do fim da música.

### 🔒 Trava de Rotação (Pitch Lock) & Filtro EMA de Suavização
* **Botão "Travar Pitch" no Cockpit:** Permite que o usuário fixe o fator de rotação da vitrola já estabilizada (`33.3 RPM`), impedindo que ruídos futuros alterem a velocidade mecânica.
* **Filtro Exponencial Ponderado (EMA):** Aplicação de média móvel exponencial nas 2ª e 3ª amostras de calibração, eliminando saltos bruscos no tempo das letras.
* **Diagnóstico Acústico em Tempo Real:** Selo de qualidade de sinal (%) e status detalhado exibidos no Cockpit.

---

## [v1.0.006] — 05/10/2026

### 📺 Resolução da Lista de Aparelhos (Seleção Primária Obrigatória)
* **Fluxo em Duas Etapas:** O modal de transmissão agora abre **obrigatoriamente na Lista de Aparelhos Detectados**. O usuário visualiza a varredura ativa da rede e deve escolher explicitamente a TV antes de qualquer tentativa de conexão.
* **Fim do Bloqueio em "Aguardando a Tela":** A Roda de Pensamento animada agora só é exibida **após** o usuário tocar no aparelho desejado, garantindo controle total sobre qual tela receberá o sinal.
* **Escaneamento Ativo ao Abrir:** O diálogo dispara a busca de dispositivos imediatamente ao ser aberto (`discoverDevices()`), sem depender de verificações em segundo plano.
* **Sonda Híbrida de Sub-rede (mDNS + TCP 8009):** Implementada varredura por sonda unicast na porta 8009 para garantir detecção mesmo em roteadores com isolamento de multicast ou filtros mDNS.
* **Botão "Escolher Outro Aparelho":** O usuário pode retornar à lista de TVs a qualquer momento caso queira trocar de aparelho durante o processo de conexão.

---

## [v1.0.005] — 05/10/2026

### 🚀 Publicação Oficial no Google Cast SDK Developer Console
* **Application ID Oficial Ativo:** Aplicação **VinyLyric TV** registrada e com status **Published** mundialmente pelo Google Cast Developer Console (App ID: `27687E0B`).
* **Vinculação de Transmissor Android (Sender Application):** Homologação do pacote transmissor `com.vinylyric.vinylyric` no ecossistema Google Cast.

### 📡 Lançamento Automático via Protocolo CastV2 (Porta 8009 TLS)
* **Cliente Nativo Pure-Dart CastV2 (`CastV2Client`):** Implementada comunicação direta via socket TLS na porta 8009 do Chromecast Built-in com enquadramento binário e serialização de mensagens Protocol Buffers (sem dependências pesadas).
* **Comando `LAUNCH` em 1 Toque:** Ao selecionar qualquer TV Chromecast na lista, o smartphone envia o pacote `LAUNCH` com o App ID `27687E0B`, inicializando automaticamente a aplicação na tela da TV sem precisar abrir navegador nem digitar endereços de IP no controle remoto.
* **Canal Customizado CAF de Alta Resiliência (`urn:x-cast:com.vinylyric.sync`):** Suporte nativo à transmissão de metadados e sincronismo pelo túnel TLS do Google Cast em paralelo ao WebSocket local.

### 🎛️ Roda de Pensamento Interativa com Dispositivos Chromecast
* **Botão "TRANSMITIR" Direto na Lista de Aparelhos:** As TVs detectadas via mDNS agora possuem botão interativo direto dentro do diálogo holográfico da Roda de Pensamento.
* **Ciclo de Vida Robusto:** Tratamento seguro de descarte de listeners (`_isDisposed`) e encerramento sincronizado de timers no `CastSyncService`.

---

## [v1.0.004] — 05/10/2026

### 💡 Diagnóstico e Resolução Definitiva da Conexão
* **Causa Raiz Identificada:** Como a versão de TV foi descontinuada (sem app instalado na TV), a TV não ouve conexões WebSocket na porta 8088 por padrão. A tentativa anterior do smartphone de conectar na TV resultava em recusa imediata pelo sistema operacional (`Connection Refused`) sem nenhum retorno visual para o usuário.
* **Inversão Arquitetural — Web Receiver Embutido no Celular:** O smartphone agora é o servidor local (`http://<IP_DO_CELULAR>:8088`). Qualquer televisão (Philips, Android TV, Samsung, LG, PC ou tablet) pode simplesmente abrir o endereço no seu navegador de internet nativo, dispensando **100%** qualquer instalação de app na TV.

### 🌀 Roda de Pensamento Animada & Feedback em Tempo Real
* **Diálogo Visual Holográfico (`CastThinkingWheelDialog`):** Desenvolvida animação customizada de "Roda de Pensamento" com arcos concêntricos giratórios em ciano e lilás neon, com radar de pulso orbital e estado dinâmico enquanto aguarda a tela.
* **Painel de Endereço Local com 1 Toque:** Exibição clara e em destaque do endereço IP local (`http://192.168.X.X:8088`) com botão de cópia rápida e instruções diretas para o navegador da TV.

### 🤝 Handshake de Confirmação da Tela Cliente
* **Espera e Validação de Confirmação:** O smartphone aguarda explicitamente o pacote de handshake `client_ready` emitido pela tela cliente.
* **Feedback de Conexão Estabelecida:** Ao receber a confirmação da TV, a Roda de Pensamento transforma-se imediatamente em um selo luminoso de sucesso (`TELA CLIENTE CONFIRMADA!`), transicionando o celular para o Console Cockpit ampliado.

---

## [v1.0.003] — 05/10/2026

### 🚫 Descontinuação Definitiva da Versão para TV (App 100% Mobile)
* **Remoção Completa do Leanback:** Removidas do `AndroidManifest.xml` todas as tags de suporte e inicialização de TV (`android.software.leanback`, categoria `LEANBACK_LAUNCHER` e dispensas de touchscreen).
* **Fim da Necessidade de Apps na TV:** O VinyLyric passa a ser estritamente um aplicativo de smartphone. Não é necessário instalar nenhum aplicativo na TV.
* **Limpeza de Receptores Internos:** Desativado o servidor de recepção UDP e o botão de inicialização direta de TV na barra superior do smartphone.

### 📺 Filtragem Rigorosa de Telas (Eliminação de Caixas de Som e Dispositivos de Áudio)
* **Inspeção de Capacidade de Vídeo (`VIDEO_OUT`):** O serviço mDNS de descoberta de Google Cast agora valida a máscara binária de capacidades (`ca & 1`), descartando imediatamente qualquer dispositivo que não possua saída de vídeo ativa.
* **Filtro de Modelos de Áudio:** Bloqueio adicional por palavras-chave (`nest mini`, `google home`, `soundbar`, `speaker`, etc.). Dispositivos de áudio puro nunca mais aparecem na lista de transmissão — somente TVs e telas reais são listadas.

### ⚡ Conexão Direta em 1 Toque (Fim das Telas Quebradas e Confirmações no Xiaomi)
* **Remoção de Telas Intermediárias do Sistema:** Eliminada a chamada nativa a `Settings.ACTION_CAST_SETTINGS` (que no Xiaomi Redmi 9A/MIUI abria uma tela quebrada de transmissão miracast pedindo permissões de Bluetooth e falhava).
* **Zero Telas ou Confirmações Desnecessárias:** A transmissão é iniciada com um único toque direto no nome da TV listada no modal.

---

## [v1.0.002] — 05/10/2026

### 📺 Arquitetura Dual-Screen: Exibição na TV (Modo Sala) & Cockpit no Celular
* **Modo TV / Exibição de Sala (`TvLyricsScreen`):** Criada tela imersiva em tela cheia dedicada para a TV Philips / Android TV. Exibe com exclusividade:
  * Capa do disco em alta definição com acabamento estético de vinil saindo da manga;
  * Letras sincronizadas perfeitamente centralizadas na tela (horizontal e verticalmente) em tipografia grande (legível do sofá a 3-4 metros);
  * Destaque luminoso neon ciano e lilás na linha ativa e rolagem contínua suave;
  * Interface 100% limpa: zero botões, menus ou barras poluindo a imagem da TV.
* **Console de Controle Ampliado no Celular (`VinylControlCockpit`):** Quando a transmissão está ativa para a TV, o smartphone assume o papel de mesa de controle ergonômica dedicada, trazendo:
  * Capa do disco, título da música, artista e álbum;
  * Barra de tempo com progresso interativo e marcadores de tempo decorrido e duração total;
  * Visor ampliado de RPM estroboscópico/analógico com indicador percentual de desvio mecânico;
  * **Ajuste Fino de Rotação (Pitch):** Slider de -5% a +5% com precisão de 0.1%, botões de micro-passo (`[-0.1%]`, `[+0.1%]`), reset rápido e botões de avanço/recuo de sincronismo de agulha (Nudge);
  * **Botão do Microfone Ampliado:** Botão ergonômico largo e centralizado para escutar o som do ambiente e calibrar a qualquer momento com toque imediato;
  * Banner de transmissão indicando status da TV conectada e opção de desconectar.
* **Compensação Automática de Latência de Rede:** Inclusão de carimbo de data/hora nos pacotes de sincronismo e compensação de buffer (~15ms) na recepção para que a letra na TV ilumine no milissegundo exato da agulha sem delay acústico.
* **Suporte à Transmissão de Tela do Sistema Android:** Adicionado botão direto "Transmitir Tela do Android (Cast)" que aciona nativamente `android.settings.CAST_SETTINGS`, permitindo espelhar o app em qualquer TV com Google Cast mesmo sem o app instalado na TV.
* **Remoção do Campo Manual de IP:** Eliminados o campo de digitação de IP e o botão "Conectar" manual no modal de Cast, mantendo a listagem limpa e direta dos aparelhos encontrados via mDNS.
* **Ajuste de Frequência do Halo Neon Circular:**
  * O halo brilha circularmente por 3 ciclos suaves (~4s) logo após a inicialização (2,5s) se detectar TVs disponíveis, e então cessa.
  * Emite um ciclo suave de aviso discreto uma vez a cada 1 minuto (60 segundos) caso ainda não esteja conectado.
  * Permanece fixo em ciano neon quando a conexão é estabelecida.

---

## [v1.0.001] — 05/10/2026

### 📡 Transmissão sem fio & Chromecast (Google Cast Built-in)
* **Descoberta Nativa via mDNS (`_googlecast._tcp.local`):** Implementada a busca oficial do protocolo Google Cast utilizando a biblioteca `multicast_dns`. Agora o aplicativo identifica todas as Android TVs e Chromecasts reais ligados na rede Wi-Fi exibindo seus nomes oficiais (ex: *"Philips 75"*, *"Chromecast Sala"*).
* **Eliminação de Dispositivo Fantasma:** Adicionado filtro automático do IP local para impedir que o próprio smartphone responda à busca e liste a si mesmo como TV.
* **Alerta Visual com Halo Neon Circular:** Adicionada varredura automática em segundo plano 2,5 segundos após a inicialização. Se forem detectados aparelhos de TV/Chromecast disponíveis na rede, a borda do botão de transmissão ativa uma animação suave de pulsação luminosa em ciano neon para convidar o usuário a transmitir as letras para a TV.

### 🎯 Sincronismo Analógico & Calibração de Rotação (RPM)
* **3ª Verificação Confirmatória de Rotação aos 30s:** Caso a 2ª amostra aos 15s detecte um desvio de velocidade relevante (> 1.5%), o aplicativo agenda imediatamente uma 3ª medição aos 30s de áudio acumulado. Isso dilui ruídos acústicos de milissegundos e crava a velocidade mecânica do toca-discos com precisão absoluta.
* **Realinhamento Instantâneo a Cada Escuta:** Eliminada qualquer margem de tolerância residual (anteriormente 350ms). Toda e qualquer escuta realizada (manual ou automática) reposiciona o relógio da letra imediatamente no milissegundo exato retornado pelo áudio da vitrola.

### 🔮 Modo Preditivo de Faixas e Álbum
* **Persistência Completa de Tracklists em JSON:** A lista oficial de faixas obtida via MusicBrainz agora é gravada de forma permanente no arquivo local de cache (`vinyl_collection.json`), garantindo que o app conheça todas as músicas do LP mesmo offline.
* **Correção do Algoritmo de Títulos (Substring Bug):** Corrigido o algoritmo de comparação que causava "matches" falsos com títulos curtos (ex: "In", "You", "Intro"), garantindo previsão rigorosa da próxima faixa real.
* **Suporte a Término de Lado do Disco:** O app agora identifica quando a agulha alcançou a última faixa do lado do LP e orienta o usuário a virar o disco.

### 🏷️ Identificação Visual
* Atualizada a etiqueta no topo da barra de ferramentas para `[ v1.0.001 ]`.

---

## [v1.0.000] — 05/10/2026

### 📺 Compatibilidade com Android TV
* **Separação de Intent-Filters no AndroidManifest:** Divisão dos filtros `LAUNCHER` (smartphones) e `LEANBACK_LAUNCHER` (Android TV) para que o aplicativo apareça normalmente na grade de aplicativos da TV (e não como aplicativo de sistema oculto).
* **Banner Oficial Leanback:** Inclusão de banner gráfico em resolução 640x360 em `drawable` e `drawable-xhdpi`.

### 🎙️ Telemetria e Hardware de Microfone
* **Detecção Automática de Microfone USB:** Implementada lógica prioritária para câmeras/microfones USB conectados em Android TVs (ex: Philips 75PUG7906).
* **Crachá de Microfone no Rodapé:** Identificação visual contínua exibindo se a captura está sendo feita via `USB: [Nome]` ou `Microfone Interno / Padrão`.

### 📺 Botão de Transmissão (Cast)
* Criação do botão de transmissão no canto superior esquerdo com alternância de estados:
  * Desconectado: `Icons.cast` (moldura vazada).
  * Conectado: `Icons.cast_connected` (tela preenchida em ciano neon).

### 📦 Otimização de Tamanho do APK
* Remoção de símbolos de debug NDK duplicados e migração para **APK Universal Único** (redução drástica de mais de 500 MB para apenas ~47 MB).
