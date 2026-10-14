# Manual Funcional e Técnico da Arquitetura — WaxClub

> **Documento de Especificação Técnica e Funcional do Sistema**  
> **Versão de Referência:** 1.3.2 (Trilhas: Nomes Limpos + Minutagem do Selo)  
> **Data:** 08/10/2026  
> **Finalidade:** Auditoria de Código, Análise por Modelos de Inteligência Artificial e Arquitetura de Software.

---

## 1. Visão Geral do Produto e Propósito

O **WaxClub (WaxClub)** é uma aplicação móvel em Flutter/Dart desenvolvida para audiófilos e entusiastas de discos de vinil. A sua finalidade central é **ouvir o som ambiente de uma vitrola / toca-discos mecânico, identificar a música sendo tocada, sincronizar a letra da música (LRC) em tempo real e calcular o desvio físico de rotação da vitrola (Pitch Drift)**, compensando variações mecânicas de velocidade da correia ou do motor (33 ⅓ RPM e 45 RPM) para que as letras nunca saiam do compasso com a agulha no sulco do disco.

---

## 2. Mapa Geral de Arquitetura do Código

```
lib/
├── main.dart                          # Ponto de entrada, tema escuro e inicialização
├── app_info.dart                      # Versão exibida na UI (kAppVersion, validada contra o pubspec.yaml em teste)
├── engine/
│   ├── prediction_tuning.dart         # Constantes de calibração, janelas de áudio, gate e retry
│   ├── speed_estimator.dart           # Regressão de rotação por faixa e modelo bayesiano do toca-discos
│   └── waxclub_engine.dart         # Motor central: orquestra microfone, Shazam, calibração mecânica e letras
├── models/
│   ├── lyric_line.dart                # Estrutura de dados de uma estrofe sincronizada (timestamp + texto)
│   ├── track_entry.dart               # Faixa do catálogo com posição oficial, número, lado e duração
│   ├── track_info.dart                # Metadados da faixa (título, artista, álbum, capa, offset, duração)
│   └── sync_state.dart                # Enum de estados de calibração e classe VinylTelemetry
├── services/
│   ├── audio_record_service.dart      # Captura de áudio mono PCM pelo microfone interno com exclusão mútua por tokens
│   ├── audio_level_analyzer.dart      # Analisador de nível RMS, estatísticas acústicas (p90) e gate de silêncio
│   ├── shazam_service.dart            # Cliente de API e parsing de resposta da assinatura acústica (headers iPhone)
│   ├── shazam_signature_generator.dart# Gerador de fingerprint acústico (FFT, picos de frequência, resampler 48k->16k)
│   ├── lyrics_provider_service.dart   # Cascata de provedores: LRCLIB -> NetEase -> Megalobiz -> Plain text
│   ├── lrclib_service.dart            # Integração com API LRCLIB para obtenção de letras sincronizadas
│   ├── lrc_parser.dart                # Parser de arquivos .lrc com suporte a milissegundos, [offset:±ms] e tolerância
│   ├── tracklist_matcher.dart         # Normalizador fonético puro Dart, Levenshtein e identificação de faixas
│   ├── tracklist_provider.dart        # Interface abstrata e modelo de candidatos para provedores de catálogo
│   ├── musicbrainz_tracklist_provider.dart # Provedor MusicBrainz com rate-limiting (>=1100ms) e priorização de vinil
│   ├── side_estimator.dart            # Inferência de lados de vinil (A/B/C/D) via catálogo, números ou partição de tempo
│   ├── track_predictor.dart           # Motor determinístico de predição (next, alternative, afterNext, afterFlip)
│   ├── prefetch_service.dart          # Pré-carregamento orientado ao preditor, tokens de geração e desambiguação
│   ├── vinyl_cache_service.dart       # Cache local em disco (JSON v2) com gravação atômica (.tmp/.bak), fila e cache negativo
│   ├── session_log_service.dart       # Auditoria de eventos em JSON Lines (waxclub_events.jsonl) e rotação
│   ├── cast_frame_parser.dart         # Parser streaming de quadros Protobuf CastV2 com reensamblagem TCP
│   ├── cast_device_registry.dart      # Registro de dispositivos com TTL (120s), ordenação estável e stream reativo
│   ├── cast_v2_client.dart            # Cliente nativo Google CastV2 (porta 8009 TLS, auto-PONG, detecção de fechamento)
│   ├── cast_sync_service.dart         # Descoberta mDNS/sub-rede single-flight, servidor local e handshake CAF
│   └── tv_web_receiver_html.dart      # Template HTML5/CSS/JS da tela na TV (zero apps na televisão)
└── ui/
    ├── screens/
    │   └── home_screen.dart   # Tela principal do smartphone (letras, modal de tracklist ou cockpit)
    ├── widgets/
    │   ├── lyrics_list_view.dart      # Lista vertical com rolagem fluida e iluminação neon da estrofe
    │   ├── vinyl_status_footer.dart   # Rodapé analógico com disco giratório, RPM, telemetria e ajuste fino
    │   ├── vinyl_control_cockpit.dart # Console ampliado com visor de RPM, pitch slider, barra e botão de mic
    │   └── cast_thinking_wheel_dialog.dart # Diálogo reativo com Roda de Pensamento animada e busca progressiva
```

---

## 3. Módulos Funcionais e Especificação Detalhada

### 3.1 Módulo 1: Captura de Áudio e Hardware de Microfone
* **Arquivo:** [`lib/services/audio_record_service.dart`](lib/services/audio_record_service.dart)
* **Objetivo:** Capturar o som acústico do ambiente emitido pelos alto-falantes ou pela vitrola.
* **Hardware de Captura:**
  * Utiliza sempre o microfone embutido padrão do smartphone (seleção de microfones USB descontinuada na v1.1.06 e removida do código na v1.1.09).
  * Gravações concorrentes são serializadas por tokens com prioridade `user` (preempta) vs `background` (descartada se o microfone estiver ocupado).
* **Formato de Gravação:** PCM linear de 16-bit, monocanal (1 channel), com taxa de amostragem padronizada em 16.000 Hz (16 kHz), otimizado para o algoritmo de reconhecimento acústico.
* **Escuta Progressiva (`recordProgressive`, v1.3):** uma única gravação contínua em fluxo PCM (`startStream`); em cada marco o áudio acumulado é embrulhado em WAV (`wrapPcm16AsWav`) e enviado ao Shazam, parando no primeiro reconhecimento. Marcos (`PredictionTuning`): 4/8/12s na 1ª escuta (rápida), 8/12s nas seguintes (robusta), 6/12s nas checagens de sincronia. Sem fluxo disponível, recorre a uma gravação única até o último marco.

### 3.2 Módulo 2: Reconhecimento Acústico e Fingerprinting (Shazam)
* **Arquivos:** [`lib/services/shazam_signature_generator.dart`](lib/services/shazam_signature_generator.dart) e [`lib/services/shazam_service.dart`](lib/services/shazam_service.dart)
* **Algoritmo:**
  * O áudio PCM é transformado em espectrograma no domínio da frequência através de janelas FFT.
  * O algoritmo extrai constelações de picos de energia espectral em faixas de frequência características.
  * Esses picos são empacotados em uma estrutura binária compatível com a especificação de assinatura de áudio do Shazam (`data:audio/vnd.shazam.sig;base64,...`).
* **Offset Temporal da Agulha:**
  * A resposta da API identifica o título, o artista, o álbum, o link da capa e, crucialmente, o `offsetSeconds` (a minutagem exata da música em que a agulha da vitrola se encontra no momento da captura).

### 3.3 Módulo 3: Cascata Multi-Provedores e Parsing de Letras Sincronizadas
* **Arquivos:** [`lib/services/lyrics_provider_service.dart`](lib/services/lyrics_provider_service.dart), [`lib/services/lrclib_service.dart`](lib/services/lrclib_service.dart) e [`lib/services/lrc_parser.dart`](lib/services/lrc_parser.dart)
* **Arquitetura da Cascata de Fontes (Prioridade Sequencial):**
  1. **LRCLIB (Primário):** Metadados oficiais de estúdio, duração exata e arquivo LRC de alta estabilidade.
  2. **NetEase Cloud Music (Secundário):** Acervo massivo aberto com cobertura abrangente para músicas brasileiras (MPB, Samba, Rock Nacional, Bossa Nova) e internacionais, com marcações de milissegundos.
  3. **Megalobiz (Terciário):** Repositório comunitário de arquivos sincronizados com proteção de timeout.
  4. **Lyrics.ovh (Fallback de Texto):** Recupera a letra em texto plano quando nenhuma fonte possui timestamps.
* **Critério de Interrupção Imediata:** Assim que a primeira fonte retorna um arquivo com marcações de tempo válidas (`[`), o fluxo da cascata é encerrado instantaneamente, maximizando a velocidade.
* **Parsing de Linhas, Tags e Tolerância (`LrcParser`):**
  * Aceita linhas com cabeçalho de tempo `[mm:ss.xx]` ou `[mm:ss.xxx]` (suporte a 1, 2 e 3 dígitos para minutos e frações com ponto ou dois pontos).
  * Processa tags de compensação global `[offset:±ms]`, adiantando ou atrasando a rolagem conforme a convenção do arquivo.
  * Remove tags de palavras de karaokê (`<mm:ss.xx>`) e deduplica estrofes consecutivas idênticas preservando marcadores instrumentais vazios.
  * Ignora metadados como `[ti:...]`, `[ar:...]`, `[by:...]`.
  * Se receber letra em texto plano (fallback), divide as estrofes e calcula timestamps proporcionais ao longo de `estimatedDurationSeconds`, assegurando que a interface e a TV nunca fiquem em branco.
* **Algoritmo de Busca Ativa (`findActiveIndex`):**
  * Aplica um avanço perceptual (*lookahead*) de **450 milissegundos** no celular (e **850 milissegundos** na TV) para compensar o tempo de reação humano e latência de rede/decodificação, garantindo sincronia perfeita com a voz do cantor.

### 3.4 Módulo 4: Motor de Sincronismo e Compensação Mecânica de Rotação (RPM)
* **Arquivos:** [`lib/engine/waxclub_engine.dart`](lib/engine/waxclub_engine.dart) e [`lib/engine/speed_estimator.dart`](lib/engine/speed_estimator.dart)
* **Modelo de Rotação (v1.1.10 — substitui a calibração por 2/3 amostras com zona morta):**
  Vitrolas mecânicas sofrem flutuações físicas causadas por frouxidão da correia (*belt drive*), desgaste de polias, variações na rede elétrica ou controles analógicos de Pitch descalibrados.
  * **Observações:** cada escuta reconhecida fornece o par $(t_i, T_i)$ — instante real do início da captura e posição da música informada pelo Shazam.
  * **Regressão por faixa (`TrackSpeedFit`):** com rotação $s$, vale $T = s\cdot t + c$. A rotação é a inclinação da reta de mínimos quadrados sobre **todas** as escutas da faixa:
    $$s = \frac{\sum (t_i-\bar t)(T_i-\bar T)}{\sum (t_i-\bar t)^2}, \qquad \sigma_s = \frac{\sigma}{\sqrt{\sum (t_i-\bar t)^2}}$$
    O erro cai com o intervalo coberto (com ruído $\sigma \approx 0.15\,s$, cerca de ±1% aos 20s e ±0.2% após 2 minutos). Não há zona morta: desvios reais de 1–2% são medidos em vez de arredondados para $1.000\times$. Escutas com resíduo acima de 1s (pulo de agulha, match errado) são descartadas.
  * **Modelo do toca-discos (`TurntableSpeedModel`):** a rotação é propriedade do hardware. Ao fim de cada faixa, o ajuste é incorporado por fusão bayesiana (peso = inverso da variância); a faixa em curso combina esse conhecimento prévio com a própria regressão. O resultado (média e desvio-padrão) é persistido; a incerteza cresce com os dias sem medição. Faixa física aceita: 0.94–1.06.
  * **Checagens de sincronia:** após identificar a faixa, o microfone confere a sincronia aos 20s, +45s e depois a cada 75s, até perto do fim. Cada checagem **realinha a letra no timestamp ouvido** e alimenta a regressão. Se ouvir outra música, o app transita imediatamente para ela.

### 3.5 Módulo 5: Modo Preditivo de Faixas, Catálogo Oficial e Persistência Resiliente
* **Arquivos:** [`lib/services/prefetch_service.dart`](lib/services/prefetch_service.dart), [`lib/services/tracklist_matcher.dart`](lib/services/tracklist_matcher.dart), [`lib/services/tracklist_provider.dart`](lib/services/tracklist_provider.dart), [`lib/services/musicbrainz_tracklist_provider.dart`](lib/services/musicbrainz_tracklist_provider.dart), [`lib/services/vinyl_cache_service.dart`](lib/services/vinyl_cache_service.dart) e [`lib/services/session_log_service.dart`](lib/services/session_log_service.dart)
* **Normalização Fonética e Correspondência (`TracklistMatcher`):**
  * Desenvolvido em Dart puro (sem dependências externas) para remover acentos/diacríticos e caracteres de pontuação Unicode.
  * Remove sufixos e ruídos de estúdio (*Remaster, 2011 Mix, Live at...*) enquanto preserva rigorosamente qualificadores narrativos (*Part 2, Act I, Reprise*).
  * Similaridade textual Levenshtein (limiares 0.85/0.88) e desambiguação com `expectedIndex` para faixas com nomes repetidos.
* **Provedor de Catálogo Oficial (`MusicBrainzTracklistProvider`):**
  * Isola consultas através da interface `TracklistProvider`.
  * Rate-limiting serializado com intervalo mínimo de 1100ms e retry único para códigos HTTP 429/503.
  * Pré-pontuação de candidatos priorizando edições em vinil (+25) e lançamentos oficiais de estúdio (+20).
* **Persistência Atômica e Cache v2 (`VinylCacheService`):**
  * Estrutura em disco baseada em `TrackEntry` (posição sequencial, número de catálogo, lado e duração).
  * Gravação atômica via arquivo temporário (`.tmp`) e cópia de segurança (`.bak`), com recuperação automática de integridade caso ocorra desligamento repentino. Fila assíncrona serializada contra concorrência de I/O.
* **Confirmação Endurecida e Log de Sessão:**
  * Confirmação da previsão em segundo plano via Shazam validada com `TracklistMatcher.isSameTrack()`.
  * Registro de auditoria estruturada (`SessionLogService`) em formato JSON Lines (`waxclub_events.jsonl`, rotação de 2.000 linhas), exportável via long-press na etiqueta de versão `v1.0.013`.
* **Painel Modal de Faixas do Álbum:**
  * Ao tocar na capa do disco (na barra superior ou no cockpit da TV), abre modal deslizante (`_showAlbumTracklistModal`) com a lista oficial de faixas, número/lado, tempos e destaque visual da música em reprodução.
* **Trava Estrita do Disco Físico (`isAlbumLocked` / `_lockAlbum`):**
  * Uma vez identificado o disco físico na sessão (via cache ou catálogo oficial), o nome do álbum e a capa física ficam **TRAVADOS** na sessão (`_lockedAlbumName` e `_lockedAlbumCoverUrl`).
  * Nas músicas subsequentes do disco, o Shazam é utilizado exclusivamente para identificação do título, artista e alinhamento do offset temporal da agulha. Os metadados de `album` e `coverUrl` retornados pelo Shazam são **100% descartados**, garantindo que coletâneas e singles avulsos do Shazam não alterem indevidamente a identidade visual do disco que está girando na vitrola.
  * O preditor de faixas (`_predictNextTrack`) prioriza a ordem contígua da tracklist oficial travada.
  * O destrave (`_unlockAlbum`) ocorre de maneira inteligente e automática apenas quando uma faixa anômala (fora da tracklist do disco travado) é confirmada.

### 3.6 Módulo 6: Console de Controle Ampliado no Celular
* **Arquivo:** [`lib/ui/widgets/vinyl_control_cockpit.dart`](lib/ui/widgets/vinyl_control_cockpit.dart)
* **Componentes Integrados:**
  1. **Capa do Disco & Informações:** Arte do álbum em alta resolução, título, artista e álbum.
  2. **Barra de Progresso e Tempo:** Marcador de tempo decorrido, slider para saltar na música (*seek*) e duração total estimada.
  3. **Visor de RPM Ampliado:** Mostrador analógico giratório estilizado com leitura estroboscópica (`33.3 RPM` / `45.0 RPM`) e porcentagem de desvio de Pitch colorida.
  4. **Ajuste Fino de Rotação (Pitch):** Slider de $-5.0\%$ a $+5.0\%$ com precisão de $0.1\%$, botões rápidos de micro-passo (`[-0.1%]`, `[+0.1%]`), botão de `Reset (0.0%)` e botões de `Nudge` (`-0.5s`, `+0.5s`).
  5. **Botão de Microfone Ampliado:** Botão ergonômico largo no rodapé para início/interrupção imediata da captura e calibração.

* **Letra no celular (sem transmitir), no estilo da TV (v1.3.8):** [`lib/ui/widgets/lyrics_list_view.dart`](lib/ui/widgets/lyrics_list_view.dart) replica o `web_receiver/index.html`: fonte Inter 800 (`assets/fonts/Inter-Variable.ttf`), centralizada, caixa alta só para alfabeto latino (`isLatinText`), escalas 1 / 1 / 0,76 / 0,62 e opacidades 1 / 0,92 / 0,24 / 0,16 por distância da linha atual (`scaleFor` / `opacityFor`), linha atual centralizada, bordas esmaecendo (ShaderMask 0–18% e 82–100%), curva cubic-bezier(0.22, 0.8, 0.24, 1), "♪" nos trechos sem letra.

### 3.7 Módulo 7: Descoberta, Transmissão e Web Receiver (Cast)
* **Arquivos:** [`lib/services/cast_sync_service.dart`](lib/services/cast_sync_service.dart), [`lib/services/cast_v2_client.dart`](lib/services/cast_v2_client.dart), [`lib/services/tv_web_receiver_html.dart`](lib/services/tv_web_receiver_html.dart) e [`lib/ui/widgets/cast_thinking_wheel_dialog.dart`](lib/ui/widgets/cast_thinking_wheel_dialog.dart)
* **Ecossistema Google Cast Oficial (Application ID `27687E0B`):**
  * Aplicação receptora **WaxClub TV** registrada e com status oficial **Published** no Google Cast SDK Developer Console.
  * Transmissor Android homologado com Package Name `com.waxclub.app`.
  * **Lançamento Automático em 1 Toque via CastV2 (`CastV2Client`):** O smartphone conecta via TLS na porta 8009 da TV Chromecast e despacha o comando binário `LAUNCH` (Protobuf) com o App ID `27687E0B`. A TV abre a aplicação imediatamente em tela cheia sem necessidade de intervenção do usuário no navegador ou controle remoto da TV.
  * **Canal Customizado CAF (`urn:x-cast:com.waxclub.sync`):** Pacotes de metadados (`track_loaded`) e telemetria de rotação (`sync_update`) são transmitidos diretamente pelo túnel TLS protegido do Google Cast.
* **Arquitetura Híbrida de Contingência (Web Receiver Embutido no Celular):**
  * Para Smart TVs legadas sem suporte a Chromecast Built-in, o smartphone mantém o servidor HTTP/WebSocket ativo na porta 8088 (`http://<IP_DO_CELULAR>:8088`).
  * O navegador de qualquer TV ou PC pode acessar o endereço e sincronizar via WebSocket com zero apps na televisão.
* **Roda de Pensamento e Handshake de Confirmação:**
  * O diálogo do app no celular (`CastThinkingWheelDialog`) renderiza uma animação contínua ("roda de pensamento") com arcos concêntricos neon giratórios e radar orbital.
  * Botão interativo **"TRANSMITIR"** em destaque para cada TV Chromecast detectada na rede local.
  * O app aguarda a conexão e o envio do pacote `client_ready` da tela cliente.
  * Assim que o handshake é recebido e confirmado (`server_ack`), a roda de pensamento exibe o selo `TELA CLIENTE CONFIRMADA!` e transiciona o smartphone para a mesa de controle (`VinylControlCockpit`).
* **Descoberta Nativa mDNS & Filtro Rigoroso de Telas:**
  * Varredura do apontador `_googlecast._tcp.local` via `multicast_dns`.
  * Filtro de bitmask `VIDEO_OUT` (`ca & 1`) + lista de exclusão de modelos de áudio (`nest mini`, `google home`, `soundbar`).
* **Animação do Halo Neon Circular do Ícone:**
  * Pulsa suavemente aos 2,5s do início se houver telas disponíveis e emite pulso de lembrete a cada 60s enquanto não conectado.

### 3.8 Módulo 8: Predição Determinística, Lados de Vinil, Desambiguação de Coletâneas e Resolução Cache-First (v1.1.01)
* **Arquivos:** [`lib/services/side_estimator.dart`](lib/services/side_estimator.dart), [`lib/services/track_predictor.dart`](lib/services/track_predictor.dart), [`lib/services/prefetch_service.dart`](lib/services/prefetch_service.dart), [`lib/services/tracklist_matcher.dart`](lib/services/tracklist_matcher.dart) e [`lib/services/vinyl_cache_service.dart`](lib/services/vinyl_cache_service.dart)
* **Inferência de Lados Físicos (`SideEstimator`):**
  * Vinis físicos possuem capacidade limitada por face (~22 a 25 min em LP de 33⅓ RPM). O `SideEstimator` resolve o lado de cada faixa por três heurísticas ordenadas:
    1. Metadados oficiais de mídia do catálogo (quando disponíveis no MusicBrainz/Discogs).
    2. Numeração do disco (`A1..A9`, `B1..B9`, `1-01`, `Side A / Track 1`).
    3. Partição contínua pelo ponto médio de duração acumulada (com teto máximo de 25 min por lado).
* **Preditor de Próxima Faixa (`TrackPredictor`):**
  * Classe pura determinística e testável isoladamente.
  * Desambiguação por adjacência e ordem sequencial: compara as faixas já confirmadas na sessão contra os candidatos de tracklist carregados, eliminando releases e coletâneas que não correspondem à ordem real do disco.
  * Classificação de candidatos em `PredictionKind`:
    * `next`: próxima faixa contínua do mesmo lado físico.
    * `alternative`: próxima faixa segundo um release alternativo plausível.
    * `afterNext`: pulo de faixa (agulha saltou para a faixa seguinte).
    * `afterFlip`: primeira faixa do próximo lado físico (B1 após término do lado A).
  * Fim de lado físico (`endOfSide`, `sideLabel`): identifica a última faixa de cada lado físico.
* **Transição de Lado e Estado `waitingEndOfSide`:**
  * Ao terminar a última faixa de um lado físico, o motor não projeta falsamente a primeira faixa do lado B como imediata.
  * O app entra em `waitingEndOfSide` ("🔄 FIM DO LADO A — VIRE O DISCO"), pausa os cronômetros e inicia sondagem silenciosa do microfone a cada 10s/15s (ou resposta instantânea caso o usuário dê um toque na tela).
* **Virada pelo botão com a faixa prevista (`flipSide`, v1.3):**
  * Com a 1ª faixa do novo lado conhecida (`afterFlip` ou tracklist travada), o toque em "Vire o disco" a exibe **na hora** (celular e TV), parada em **0:00 — "aguardando a agulha"** (`isAwaitingNeedle`; a TV recebe `awaitingNeedle` e mantém a agulha no sulco externo).
  * Funciona nas duas ordens: virar o disco antes ou depois do toque. Uma nova sessão (`_sessionId`) invalida a sondagem em andamento e o microfone é liberado (`cancelAndWait`).
  * `_awaitNeedleAndConfirm` escuta em laço: capturas em silêncio mantêm a letra parada; no primeiro som (instante `soundOnsetSeconds` do `AudioLevelAnalyzer`) a letra começa a correr; o reconhecimento do Shazam fixa o timestamp exato ou, se for outra música, troca de faixa. Sem reconhecimento por 90s com música tocando, a previsão é mantida e o fluxo normal segue.
  * Sondagens interrompidas (`CaptureOutcome.cancelled`) não contam mais como "não reconhecido" — era o loop que impedia reconhecer o lado B na v1.2.02.
* **Desambiguação Estrita por Ordem Sequencial (`isSequentialMatch`):**
  * Quando faixas de um artista aparecem em mais de um álbum ou coletânea, o método `TracklistMatcher.isSequentialMatch` valida se a sequência histórica de faixas tocadas na sessão ocorre em posições estritamente crescentes (`idx_next > idx_curr`) dentro da tracklist candidata, respeitando um salto máximo permitido.
  * Coletâneas com faixas em ordem invertida ou divergente são descartadas no preditor (`TrackPredictor`), na resolução de capas (`resolveAlbumCover`) e na busca de cache (`findDiscContainingTracks`).
* **Regra Reforçada de 3 Confirmações Consecutivas em Ordem para Álbum Preferencial:**
  * O app exige pelo menos 3 faixas tocadas na sessão (`_sessionHistory.length >= 3`) e 3 confirmações consecutivas da mesma discografia (`_consecutiveConfirmationsOnAlbum >= 3`), além de validar rigorosamente a ordem sequencial (`isSequentialMatch`) antes de persistir o álbum como `preferredAlbum`. Isso impede que coletâneas concorrentes com ordem diferente sobrescrevam o disco original.
* **Cascata Estrita de Resolução de Letras Cache-First:**
  * Ordem de busca: 1) Memória (prefetch) -> 2) Disco Local (`vinyl_collection.json`) -> 3) Cascata de Provedores de Rede (LRCLIB -> NetEase -> Megalobiz -> Plain text). Zero requisições de rede se a letra já existir no dispositivo.

### 3.9 Módulo 9: Robustez Acústica, Silêncio Inteligente e Aprendizado Local (v1.1.02)
* **Arquivos:** [`lib/services/audio_level_analyzer.dart`](lib/services/audio_level_analyzer.dart), [`lib/engine/prediction_tuning.dart`](lib/engine/prediction_tuning.dart), [`lib/engine/waxclub_engine.dart`](lib/engine/waxclub_engine.dart) e [`lib/services/vinyl_cache_service.dart`](lib/services/vinyl_cache_service.dart)
* **Análise Acústica e Gate de Silêncio (`AudioLevelAnalyzer`):**
  * Processamento de áudio PCM16 mono a 16 kHz em blocos de 100 ms (1.600 amostras por janela).
  * Extração de métricas de energia em dBFS: RMS, pico, mediana e percentil 90 (p90).
  * Limiar adaptativo dinâmico de silêncio: calculado com base no nível musical de referência da faixa (`limiar = referenceMusicDb - 15 dB`, com piso em -45 dBFS). Amostras de intervalo entre faixas ou ruído de agulha são classificadas com precisão sem cortar o áudio (`gate acústico sem trim`).
* **Captura com Retentativas Persistentes (`_captureAndIdentify`):**
  * Política progressiva de retentativa em intervalos definidos (`retryDelaysSeconds = [0, 8, 20, 35, 55, 80]`, com teto global `giveUpAfter = 90s`).
  * Em caso de silêncio acústico, o motor **não consome chamadas de rede ao Shazam**, preservando a letra da música prevista na tela do smartphone e na televisão até que o áudio volte a soar.
  * Elimina o encerramento prematuro no intervalo entre faixas ("Cenário 3").
* **Persistência do Prior de Rotação da Vitrola (`lastStableSpeedFactor`):**
  * Modelo `CachedTurntableState` armazenado na coleção `vinyl_collection.json`.
  * Rotações estáveis (desvio $\le 0.4\%$ entre as amostras confirmatórias 2 e 3) são salvas em disco.
  * Ao abrir o aplicativo ou iniciar nova sessão, o fator salvo é restaurado imediatamente (se atualizado há $\le 30$ dias e com desvio $\le 5\%$), proporcionando compasso instantâneo desde a primeira estrofe sem aguardar os 15s de calibração.
* **Nudge Persistente de Letra e Fonte Preferencial:**
  * Variável desacoplada `_lyricBiasSeconds` para ajustes manuais de sincronia da letra ($\pm 0.5\text{s}$, limitados a $\pm 10\text{s}$).
  * O ajuste fino sobrevive aos realinhamentos acústicos periódicos do microfone (`seekTo`).
  * Persistência automática em cache com debounce de 3 segundos (`CachedTrack.lyricOffsetMs`) e restauração automática ao reproduzir a faixa no futuro.
  * Persistência da fonte de letra que obteve sucesso (`lyricsSource`), priorizando-a em requisições futuras (`preferredSource`).

### 3.10 Módulo 10: Escolha Manual do Disco e Conta Discogs (v1.3.1)
* **Arquivos:** [`lib/services/album_catalog_service.dart`](lib/services/album_catalog_service.dart), [`lib/services/discogs/`](lib/services/discogs/) (`discogs_config.dart`, `discogs_auth_service.dart`, `discogs_tracklist_provider.dart`), [`lib/ui/widgets/album_picker_sheet.dart`](lib/ui/widgets/album_picker_sheet.dart), [`lib/ui/screens/discogs_login_screen.dart`](lib/ui/screens/discogs_login_screen.dart) e `WaxClubEngine.applyUserAlbumChoice`.
* **Fluxo do usuário:** toque na capa → lista de faixas → botão **"Mudar disco"** → janela com todos os discos em que a música aparece (capa, artista, ano, país, chips Atual/Vinil/Coletânea/Ao vivo/N edições), busca livre por texto e a caixa **"Consultar Discogs"**.
* **Caixa "Consultar Discogs":** sem conta conectada, abre o texto com as vantagens (`kDiscogsBenefitsText`) e **OK** leva à **tela de login do Discogs** (WebView). As credenciais ficam guardadas cifradas no aparelho (`flutter_secure_storage`, Keystore do Android) para as próximas vezes, junto com o estado da caixa; "Sair" desconecta.
* **Login:** com as chaves do app (`DiscogsConfig.consumerKey/consumerSecret`, via `--dart-define`), OAuth 1.0a com assinatura PLAINTEXT sobre HTTPS; o retorno `https://waxclub.app/discogs-callback` é interceptado no WebView. Sem as chaves, a tela abre `discogs.com/settings/developers` e o usuário cola o **token pessoal**. Em ambos os casos a conta é validada em `/oauth/identity`.
* **Bases:** Discogs é a **principal** quando a caixa está marcada (busca da faixa pelo artista e também pelas coletâneas "Various"; edições do mesmo *master* agrupadas, preferindo o vinil). **MusicBrainz** é a **reserva**: usada sem Discogs, quando o Discogs falha ou nada encontra (com aviso na tela). Ordem: disco atual, estúdio em vinil, estúdio, singles/ao vivo, coletâneas; do mais antigo ao mais novo.
* **Ao escolher:** a lista de faixas do disco é carregada (com lados A/B e durações), gravada no cache, o disco é **travado**, capa/lado/duração/próxima música são atualizados no celular e na TV, e o disco vira o **padrão do usuário** (`preferredAlbum`) para a música atual e todas as faixas dele — nas próximas sessões o reconhecimento já trava esse disco, mesmo que o Shazam indique uma coletânea.
* **Origem da preferência (`CachedTrack.preferredAlbumSource`):** `'user'` (Mudar disco) ou `'sequence'` (3 faixas seguidas na ordem do disco); a confirmação automática nunca sobrescreve a escolha do usuário.

### 3.10.1 Só Vinil e Minutagem do LP (v1.3.9)
* **Escolha de disco só com vinil LP/EP:** [`album_catalog_service.dart`](lib/services/album_catalog_service.dart) filtra os resultados do Discogs (busca com `format=Vinyl`) e do MusicBrainz por `ReleaseCandidate.isVinylLpOrEp` ([`tracklist_provider.dart`](lib/services/tracklist_provider.dart)): fora CD, digital, fita e singles.
* **Minutagem do LP pela Wikipedia:** [`wikipedia_tracklist_service.dart`](lib/services/wikipedia_tracklist_service.dart) acha o artigo do álbum (en, depois pt), confere o artista e lê os modelos {{Track listing}} / {{Lista de faixas}} (ou listas `# "Título" – 3:45`). `fillDurations` completa as durações ausentes; com `override` (disco que não é vinil) substitui, desde que o artigo case com ao menos metade das faixas. Usado em `AlbumCatalogService.loadTracklist` e no `PrefetchService` (detecção automática, que também passa a preferir prensagens em vinil).
* **Prioridade das durações (modo automático):** lista de faixas do disco (Discogs/MusicBrainz) → Wikipedia → provedor de letras (digital). O Shazam nunca é fonte de minutagem.

### 3.10.2 Textos Traduzíveis e Microfone Ocupado (v1.3.10)
* **Arquivos de tradução:** todos os textos visíveis ficam em [`lib/l10n/app_en.arb`](lib/l10n/app_en.arb) (inglês, padrão). `flutter gen-l10n` gera `lib/l10n/gen/app_localizations.dart` (configurado em `l10n.yaml`, `generate: true` no pubspec). Use `l10n.<chave>` (getter de [`lib/l10n/l10n.dart`](lib/l10n/l10n.dart)); o `MaterialApp` registra os delegates e atualiza `L10n.current` para o motor e os serviços. Novos idiomas = novos `app_<idioma>.arb` (futuros plugins).
* **Regra:** `test/l10n_no_hardcoded_strings_test.dart` reprova texto para o usuário escrito em `lib/ui`; literais técnicos (fontes, chaves) levam `// l10n-ignore`.
* **Microfone ocupado:** [`mic_busy_service.dart`](lib/services/mic_busy_service.dart) + `MicStatusChannel.kt` (canal `com.waxclub.app/mic`, `AudioManager.getActiveRecordingConfigurations()`). No primeiro marco da captura (ainda gravando) o motor guarda `silenced` (Android 10+, `isClientSilenced`) e o número de capturas ativas. `MicStatus.blocksCapture`: silenciado, ou outro app gravando com pico abaixo de −80 dBFS. Se a escuta inicial falhar nessas condições, o status vira `statusMicBusy` (log `mic_blocked`).

### 3.10.3 Reconhecimento do Disco pela Câmera (v1.3.11)
* **Tela:** [`record_scan_screen.dart`](lib/ui/screens/record_scan_screen.dart), aberta pelo ícone de câmera da barra superior. Modos `barcode` (`MobileScanner` com `scanWindow` e lanterna), `catalog` (`ImagePicker` + `TextRecognizer` latino) e `typed`. Guia: [`record_scan_guide.dart`](lib/ui/widgets/record_scan_guide.dart), mostrado uma vez (`UserProfileStore.scanGuideSeen`).
* **Leitura:** [`record_scan_parser.dart`](lib/services/record_scan_parser.dart): `isValidBarcode` (dígito verificador) e `catalogNumberCandidates` (ignora ano, duração, RPM e o próprio código de barras).
* **Busca:** `AlbumCatalogService.byBarcode` / `byCatalogNumber` → Discogs (`searchByBarcode`, `searchByCatalogNumber` com `format=Vinyl`) e MusicBrainz (`barcode:` / `catno:`), só vinil LP/EP, ordenado do mais antigo ao mais novo, sem agrupar edições. `ReleaseCandidate` ganhou `label`, `catalogNumber`, `barcode`.
* **Fluxo:** [`record_found_flow.dart`](lib/ui/screens/record_found_flow.dart): "Add to collection?" → `CollectionEntryScreen` (nota, graus do Discogs em [`discogs_grades.dart`](lib/services/discogs/discogs_grades.dart), observações, opção de adicionar no Discogs por [`discogs_collection_service.dart`](lib/services/discogs/discogs_collection_service.dart)) → `WaxClubEngine.prepareScannedRecord` (lista de faixas no cache + disco padrão de todas as faixas; aplica na hora se uma faixa dele já toca) → "Let's listen?" (sim = `startListening`).
* **Compilação:** `flutter build apk --release --target-platform android-arm,android-arm64`; `android/app/proguard-rules.pro` com `-dontwarn` dos reconhecedores não latinos do ML Kit.

### 3.10.4 Jukebox de Plugins e Botões de Madeira (v1.3.12)
* **Modelo:** [`plugin_catalog.dart`](lib/services/plugins/plugin_catalog.dart): `PluginCategory` (letra, cor, `exclusive`; Language/Display/AI), `PluginInfo` (código = letra + número, `builtIn`/`installable`/`comingSoon`, `locked`), `PluginCatalog.builtIn` e `PluginStore` (instalados e ligados, regra de um idioma por vez, travados sempre ligados, `waxclub_plugins.json`).
* **Tela:** [`plugin_jukebox_screen.dart`](lib/ui/screens/plugin_jukebox_screen.dart) (gabinete com arco de neon, vitrine, mostrador, teclado, prato, cartelas, caixote, legenda, detalhes) e [`seven_inch_record.dart`](lib/ui/widgets/seven_inch_record.dart) (o compacto).
* **Barra superior:** logo/capa no `leading` (toque = lista de faixas, toque longo = copiar logs); título só com a tela larga (≥ 600 dp); botões [`WoodTileButton`](lib/ui/widgets/wood_tile_button.dart) com as artes `assets/images/btn_camera.png`, `btn_collection.png`, `btn_plugins.png`, `btn_help.png`.
* **Nomes na abertura:** `IntroLabelsLayer` fica por cima do Scaffold (a barra corta o que passa da altura dela), mede a posição de cada botão pela `GlobalKey` e mostra `IntroWipeLabel` (revela e apaga da esquerda para a direita) numa linha do tempo única (`AnimationBehavior.preserve`), alternando acima/abaixo.

### 3.10.5 Modo Manual (v1.3.15)
* **Catálogo:** [`recognition_catalog_service.dart`](lib/services/recognition_catalog_service.dart) — iTunes `lookup?upc=` ou `search?entity=album` + `lookup?id=&entity=song`; `evaluate` = metade das faixas. Chamado em `runRecordFoundFlow` depois de `prepareScannedRecord` (que agora trava o disco); não encontrado → `setManualMode(true)`.
* **Motor** (`WaxClubEngine`, bloco "MODO MANUAL"): `startManualPlayback(trackIndex, useMic)`, `startManualPending`, `manualJumpTo`, `stopManual`; `_manualShowTrack` (reaproveita `_showPredictedTrack` sem relógio, duração do LP), `_manualAwaitOnset` + `_captureLevelOnly` (só `AudioLevelAnalyzer`, sem Shazam), `_manualStartAt` (relógio a partir do primeiro som), `_scheduleManualAdvance` (duração − posição ÷ rotação + `manualGapSeconds`), `_manualAdvance` (mesmo lado / fim do lado → `manualPendingIndex` / fim do disco → chave desliga). `_scheduleEndOfTrackListener` e `_scheduleNextSyncCheck` não rodam a escuta automática durante o Modo Manual.
* **Tela:** [`chrome_play_button.dart`](lib/ui/widgets/chrome_play_button.dart), [`manual_start_sheet.dart`](lib/ui/widgets/manual_start_sheet.dart), `VinylStatusFooter.centerButton`, `_onManualPressed` na tela principal; lista de faixas pula de faixa no Modo Manual.

### 3.10.6 Curiosidades (v1.3.16)
* **Serviço:** [`curiosities_service.dart`](lib/services/curiosities_service.dart): busca o artigo (`list=search`, título igual + artista no título ou no trecho), lê o texto (`prop=extracts&explaintext`, só a introdução para faixas) e escolhe frases com `pickFacts` (40–220 caracteres, pontuação por palavras-chave, anos e números; a 1ª frase é a definição). Até 5 do disco e 2 por faixa; cache em `waxclub_curiosities.json`.
* **Tela:** [`curiosities_view.dart`](lib/ui/widgets/curiosities_view.dart): `schedule` (3 s de espera, espaço igual ao longo da duração, no máximo 12 s cada; sem duração, uma a cada 10 s em ciclo) e `visibleAt`; animação de 15% entrando e 15% saindo. Na tela principal, `_curiositiesOrNull` entra como `emptyState` da letra quando há faixa, não há letra e o plugin D2 está ligado; as do disco só na 1ª faixa do lado.

### 3.10.7 Segunda Tela por Smart View / Miracast (v1.3.18)
* **Android:** [`SecondScreenController.kt`](android/app/src/main/kotlin/com/waxclub/app/SecondScreenController.kt) — `DisplayManager.DISPLAY_CATEGORY_PRESENTATION` + `DisplayListener`; `LyricsPresentation` (Presentation com WebView, tela sempre acesa) carrega a página da TV do servidor local. Canal `com.waxclub.app/second_screen`: `state`, `show(url)`, `hide`, `openCastSettings` (`android.settings.CAST_SETTINGS` / `WIFI_DISPLAY_SETTINGS`); eventos `state` para o Flutter.
* **Flutter:** [`second_screen_service.dart`](lib/services/second_screen_service.dart), dono: `CastSyncService.secondScreen` (iniciado em `runInitialBackgroundDiscovery`). Ao surgir a tela, mostra `http://127.0.0.1:8088/?name=<tela>`; a página conecta por WebSocket como qualquer tela e o celular entra no modo painel (`isCastActive`). `disconnect(stopTvApp: true)` esconde a letra e marca `dismissedByUser` até a tela sumir.

### 3.11 Módulo 11: Trilhas Sonoras de Novelas (v1.3.1)
* **Arquivos:** [`lib/services/soundtrack_catalog.dart`](lib/services/soundtrack_catalog.dart) e `assets/catalog/trilhas_novelas.json`.
* **Origem dos dados:** levantamento do site Teledramaturgia / Observatório da TV (índices de trilhas da Globo por período, Malhação, séries/minisséries, Record, SBT, Band, Manchete, Excelsior e Tupi): disco, emissora, ano e faixas com artista. Capas apenas dos LPs (até 1993), baixadas uma vez, recomprimidas (até 400 px, JPEG 82) e hospedadas no GitHub Pages do WaxClub (covers/ (raiz do repositório), publicada como covers/ no repositório INTEGRALIST88/WaxClub); trilhas em CD ficam sem capa própria (vale a do Shazam). Scripts: 	ool/trilhas/crawl.js, durations.js, covers.js, esize_covers.ps1, elink_covers.js. Durações por faixa obtidas na Deezer (reserva iTunes). O script de geração fica fora do app (ferramenta de build).
* **Regra:** ao reconhecer uma música presente numa trilha (mesmo título e artista — duetos aceitam qualquer um dos artistas), e sem disco preferido definido para ela, o motor trava a trilha (`_lockSoundtrack`, `lockedAlbumSource = 'soundtrack'`), grava-a no cache de discos (artista do disco "Trilha sonora", formato "Vinyl LP"/"CD") e usa a lista de faixas para duração e previsão. Se a música está em várias trilhas, vale a mais antiga.
* **Nomes:** padronizados por `tool/trilhas/clean_titles.js` (sem posição/vendagem do ranking e sem a palavra "trilha"; ex.: "O Outro Internacional", "Babilônia Volume 1").
* **Minutagem e lados do selo (v1.3.2):** `tool/trilhas/discogs_labels.js` localiza os LPs da Som Livre (gravadora 13768) na API pública do Discogs pelo nome da novela + tipo e ano, e `apply_label_durations.js` grava a minutagem impressa no selo e o lado real de cada faixa (219 LPs com lados, 116 com minutagem). Correções manuais lidas de fotos do selo ficam em `tool/trilhas/label_overrides.json` e têm prioridade.
* **Lados:** LPs sem lado informado recebem lados A/B estimados pela duração (faixas sem duração entram com a média); CDs ficam todos no lado A (sem virada).
* **Artista por faixa (`TrackEntry.artist`):** usado na previsão da próxima música, na virada do disco e no pré-carregamento de letras (sem o nome da coletânea na busca).

---

## 4. Auditoria de Conformidade com as Solicitações do Usuário

| Requisito / Modificação Solicitada | Situação Atual no Código | Status de Verificação |
|---|---|---|
| **Em pé: música, banda · disco e "a seguir" abaixo do disco na barra superior** | `AppBar.bottom` com `_portraitTrackInfo` quando `compactBar` e há faixa | ✅ Conforme (v1.3.19) |
| **Curiosidades/notícias também na TV; notas do Discogs; sugestão do Modo Manual após ~90 s; Identify deitado** | Pacote `curiosities` (`CastSyncService.sendCuriosities` + página da TV), `AlbumCatalogService.discogsNotes`, `manualSuggested`, layout deitado em `record_scan_screen.dart` | ✅ Conforme (v1.3.19) |
| **Conta WaxClub: login por código no e-mail, sair e apagar a conta** | `AccountService` (`lib/services/account/account_service.dart`) + `AccountScreen`; API `server/api` (`/v1/auth/email/*`, `/v1/me`) | ✅ Conforme (v1.3.20) |
| **Coleção sincronizada com a conta (envio do que mudou, recebimento dos outros aparelhos, o mais recente vence) e audições como cópia de segurança** | `AccountService.sync`, `CollectionService.changedSince/removedSince/applyRemote`; API `/v1/collection/sync`, `/v1/collection?since=`, `/v1/plays` | ✅ Conforme (v1.3.20) |
| **Login obrigatório antes do app (e-mail e senha; Google quando configurado); cadastro com usuário, país, estado e cidade em listas com busca; confirmação do e-mail e esqueci a senha** | `AuthGate`, `SignInScreen`, `SignUpScreen`, `VerifyEmailScreen`, `ForgotPasswordScreen`, `ProfileFormScreen`, `LocationFields` (`lib/ui/screens/auth/`); API `/v1/auth/*`, `/v1/geo/*` (GeoNames) | ✅ Conforme (v1.3.21) |
| **TVs Samsung/LG sem Chromecast por Smart View / Miracast: letra na TV, painel no celular (sem navegador, sem app na TV)** | Android `Presentation` (`SecondScreenController.kt`) + `SecondScreenService` | ✅ Conforme (v1.3.18) |
| **Só inglês: English pré-instalado; outros idiomas e a tradução por IA de notícias/curiosidades virão pelo site** | `PluginCatalog` (L1, A2), aviso na Jukebox | ✅ Conforme (v1.3.17) |
| **Notícias recentes do artista em inglês junto das curiosidades** | [`news_service.dart`](lib/services/news_service.dart) (Google News RSS) + `CuriosityKind.news` | ✅ Conforme (v1.3.17) |
| **Curiosidades do disco e das faixas, animadas, quando não há letra (com fonte, em inglês)** | `CuriositiesService` (Wikipedia) + `CuriositiesView`; plugin D2 embutido | ✅ Conforme no celular (v1.3.16); TV e notas do Discogs pendentes |
| **Modo Manual: verificação no catálogo após o Identify, ▶ cromado, início pelo microfone (só volume), trocas pela minutagem, virar o lado, fim do disco** | `RecognitionCatalogService`, bloco Modo Manual do motor, `ChromePlayButton`, `ManualStartSheet` | ✅ Conforme (v1.3.15) |
| **Chave MANUAL (botão ligado/desligado) junto dos outros; começa desligada e desliga no fim do disco (último lado)** | `isManualMode`/`setManualMode`, `isLastSideOfRecord` em `_enterWaitingEndOfSide` | ✅ Conforme (v1.3.14) |
| **Primeiro botão chamado "Identify" e ajuda com as novidades (barra superior, Identify, coleção, plugins)** | `l10n.camera` = "Identify"; `help_screen.dart` com o tópico "The top bar" | ✅ Conforme (v1.3.13) |
| **Página de plugins em jukebox (Language, Display, AI; discos coloridos; botão ao lado de My Collection)** | `PluginJukeboxScreen` + `PluginStore` + `SevenInchRecord` | ✅ Conforme (v1.3.12) |
| **Botões de madeira (câmera, coleção, plugins, ajuda) com nomes na abertura; logo à esquerda; sem texto em pé** | `WoodTileButton` + `IntroLabelsLayer` | ✅ Conforme (v1.3.12) |
| **Reconhecimento do disco pela câmera (guia, código de barras, nº de catálogo, prensagem, coleção, "Let's listen?")** | `RecordScanScreen` + `record_found_flow.dart` + `prepareScannedRecord` | ✅ Conforme (v1.3.11) |
| **Textos da interface em arquivos de tradução (.arb)** | `lib/l10n/app_en.arb` + gen-l10n; teste reprova texto fixo em `lib/ui` | ✅ Conforme (v1.3.10) |
| **Aviso de microfone ocupado por outro app** | `MicBusyService` + `MicStatusChannel.kt`; mensagem `statusMicBusy` | ✅ Conforme (v1.3.10) |
| **"Change record" mostra só vinil LP ou EP** | Filtro `isVinylLpOrEp` no Discogs (`format=Vinyl`) e no MusicBrainz | ✅ Conforme (v1.3.9) |
| **Minutagem do LP antes da digital (Wikipedia)** | `WikipediaTracklistService` completa/substitui durações; detecção automática prefere vinil | ✅ Conforme (v1.3.9) |
| **Letra no celular com a mesma fonte e apresentação da TV** | `lyrics_list_view.dart` com Inter 800, caixa alta latina, 3 linhas em destaque, 76%/62%, esmaecimento e linha atual centralizada | ✅ Conforme (v1.3.8) |
| **Ícone do app com o rótulo "WaxClub / VINYL SOCIAL CLUB"** | `app_icon.png` gerado da arte original mantendo o selo (`WaxClubWoodIcon.cs`, keepLabel) | ✅ Conforme (v1.3.8) |
| **Ícone de Transmissão presente** | Implementado no topo esquerdo com estados vazado/conectado | ✅ Conforme |
| **Numeração de Versão progressiva a cada build** | Série 1.3 (`v1.3.2+2302`; próximas 1.3.3, 1.3.4...) | ✅ Conforme |
| **Celular se anuncia na rede (`_waxclub._tcp`) para apps de TV** | NsdManager (`PhoneNsdAnnouncer.kt`) + `phone_announcer.dart`; TXT com `ws=/cast`, `path=/`, versão | ✅ Conforme (v1.3.3) |
| **Saudação com nome, My Collection, Help, ícone em madeira e paleta creme/laranja** | `home_greeting.dart`, `collection_service.dart` + `collection_screen.dart`, `help_screen.dart`, `user_profile_store.dart`, `app_theme.dart` (cream/orange/rust) | ✅ Conforme (v1.3.5) |
| **Conexão com apps WaxClub de TV (Fire TV)** | Busca `_waxclub-tv._tcp`/`_vinylyric._tcp`, conexão WebSocket (`connectToHost`), Add by IP testa 8009 e 8088 | ✅ Conforme (v1.3.4) |
| **Nomes limpos e minutagem do selo nas trilhas** | Títulos padronizados; durações e lados do selo via Discogs + foto do selo | ✅ Conforme (v1.3.2) |
| **"Mudar disco" com todos os discos da música e padrão do usuário** | Janela de escolha com busca; disco escolhido travado e gravado como preferido | ✅ Conforme (v1.3.1) |
| **Conta Discogs (caixa, explicação, OK → login, credenciais guardadas)** | Discogs principal + MusicBrainz reserva; credenciais cifradas no aparelho | ✅ Conforme (v1.3.1) |
| **Virada: letra do lado B na hora, correndo a partir da agulha** | `flipSide` exibe a faixa prevista em 0:00, inicia no 1º som e o Shazam corrige | ✅ Conforme (v1.3) |
| **1ª escuta rápida, robusta nas seguintes** | Escuta progressiva 4/8/12s → 8/12s sem recomeçar a gravação | ✅ Conforme (v1.3) |
| **Arquivo de Log de alterações ([`RELEASE_LOG.md`](RELEASE_LOG.md))** | Criado e mantido rigorosamente atualizado a cada versão | ✅ Conforme |
| **Compatibilidade Samsung One UI + Xiaomi (Android 10 ao 14)** | MulticastLock e WifiLock nativos em Kotlin, bloqueio P2P e timeouts resilientes | ✅ Conforme |
| **Analisador de Áudio & Gate de Silêncio (`AudioLevelAnalyzer`)** | RMS em dBFS, p90 e limiar adaptativo sem trim destrutivo | ✅ Conforme (v1.1.02) |
| **Nome Oficial WaxClub (app, ícone e TV)** | Textos visíveis, rótulo Android e letras do ícone corrigidos; identificadores técnicos mantidos | ✅ Conforme (v1.2.03) |
| **Painel da Transmissão em Retrato e Sem Rolagem** | 4 grupos (TV, Tocando agora, Ajustes, Ação), validado por teste em 2 tamanhos | ✅ Conforme (v1.2.03) |
| **Visual em Madeira Escura Entalhada** | Fundo com veio, painéis entalhados e botões em relevo; letra e destaques mantidos | ✅ Conforme (v1.2.03) |
| **Botão "Vire o Disco" Pulsante com Rolagem Automática** | Fim do lado leva o usuário ao botão; virada mantém o disco travado | ✅ Conforme (v1.2.02) |
| **Animação de Virada e Troca de Disco na TV** | Agulha levanta, disco gira 180°, lado/capa trocam no meio, agulha desce no novo início | ✅ Conforme (v1.2.02) |
| **Duração do Catálogo e Descarte de Duração Inconsistente** | Tracklist do disco tem prioridade; posição além da duração descarta o valor errado | ✅ Conforme (v1.2.01) |
| **TV Sem Proteção de Tela** | Screen Wake Lock + vídeo mudo de 1 quadro/s como mídia ativa | ✅ Conforme (v1.2.01) |
| **Selo com Lado do Disco, A Seguir e Rotação na TV** | Letra do lado girando no selo, próxima música e rotação medida | ✅ Conforme (v1.2.01) |
| **Tela da TV com Letra em Prioridade e Fluida** | Interpolação local a 60fps, letra centralizada com 3 linhas em destaque do mesmo tamanho | ✅ Conforme (v1.2.00) |
| **Disco EP com Selo-Capa Girando e Agulha** | Disco 7" no canto, capa circular a 45 RPM no selo, agulha subindo da borda ao selo com o tempo | ✅ Conforme (v1.2.00) |
| **Reconexão Automática da TV** | Heartbeat no receiver-0 e reconexão (2s/5s/10s) sem voltar à tela do celular | ✅ Conforme (v1.2.00) |
| **Letras Sincronizadas em Edições Alternativas** | Busca ampla LRCLIB por artista/título quando a exata só tem texto simples | ✅ Conforme (v1.2.00) |
| **Reconhecimento com Buffer de 12s** | 6s na 1ª tentativa e 12s nas seguintes, como o SongRec | ✅ Conforme (v1.2.00) |
| **Rotação Medida por Regressão (sem travar em 1.000x)** | `TrackSpeedFit` + `TurntableSpeedModel` com incerteza; sem zona morta | ✅ Conforme (v1.1.10) |
| **Letra Realinhada a Cada Escuta Reconhecida** | Checagens aos 20s, +45s e a cada 75s; outra música ouvida → transição imediata | ✅ Conforme (v1.1.10) |
| **Continuidade Após a 2ª Música** | Confirmação preditiva sempre agenda checagens e fim de faixa | ✅ Conforme (v1.1.10) |
| **TV Acompanha a Troca de Faixa** | Faixa prevista e confirmada enviadas à TV | ✅ Conforme (v1.1.10) |
| **Desconectar Fecha o App na TV** | `STOP` do receiver com `sessionId` + limpeza da tela | ✅ Conforme (v1.1.10) |
| **Lista de Transmissão Somente com Telas** | Caixas de som/grupos filtrados (mDNS `ca`, Eureka, modelo) | ✅ Conforme (v1.1.10) |
| **Captura VOICE_RECOGNITION** | Fonte de áudio do Android sem AGC/supressão de ruído | ✅ Conforme (v1.1.10) |
| **Prior de Velocidade Preservado ao Reiniciar a Escuta** | `_resetState` mantém a rotação estável persistida/consolidada em vez de zerá-la | ✅ Conforme (v1.1.09) |
| **Pausa/Retomada Segura (Calibração e Virada de Disco)** | Retomar reagenda a calibração com novo baseline e restaura a espera "Vire o disco" | ✅ Conforme (v1.1.09) |
| **Nudge Gravado em Toda Troca de Faixa e Parada** | `_flushPendingNudge` persiste o ajuste em debounce antes de trocar/reiniciar | ✅ Conforme (v1.1.09) |
| **Descoberta de TVs Somente com Resposta Real** | Dispositivos sem resposta em 8008/8009 não entram na lista; `HttpClient` fechado | ✅ Conforme (v1.1.09) |
| **Versão Única na UI (`kAppVersion`)** | Constante única validada contra o `pubspec.yaml` em teste automatizado | ✅ Conforme (v1.1.09) |
| **Transmissão TV CastV2 Robusta (`CastFrameParser` + auto-PONG)** | Enquadramento protobuf streaming, tolerância a chunks parciais e PONG imediato | ✅ Conforme (v1.1.08) |
| **Registro Reativo de TVs (`CastDeviceRegistry` + Single-Flight)** | Descoberta concorrente unificada, stream reativo e TTL de 120s | ✅ Conforme (v1.1.08) |
| **Diálogo de Faixas do Álbum ao Tocar na Capa ou Título** | Modal completo com tracklist oficial, badges "TOCANDO" e "A SEGUIR" | ✅ Conforme (v1.1.08) |
| **mDNS Preservando Standby e Varredura /24 Sob Demanda** | TVs em espera rotuladas sem descarte; botão "Buscar na rede" e "Adicionar por IP" | ✅ Conforme (v1.1.08) |
| **Isolamento de Rotação Mecânica por Faixa** | Reset de baseline por música, eliminando descompasso acumulado na 3ª faixa | ✅ Conforme (v1.1.07) |
| **Trava de Hardware Estável (`isHardwareSpeedCalibrated`)** | Substituída na v1.1.10 pelo modelo bayesiano: checagens continuam em todas as faixas | 🔄 Revisado (v1.1.10) |
| **Resampler Linear 48k->16k e Reconhecimento Digital Shazam** | Reconhece faixas em áudio digital via headers autênticos iOS e rate real do WAV | ✅ Conforme (v1.1.06) |
| **Descontinuação de Microfones USB (100% Smartphone)** | Microfone interno nativo padrão sem seleção forçada USB | ✅ Conforme (v1.1.06) |
| **Retentativas Persistentes sem Desligamento ("Cenário 3")** | Loop de 90s (`_captureAndIdentify`) sem chamadas Shazam em silêncio | ✅ Conforme (v1.1.02) |
| **Prior de Velocidade do Toca-Discos no Cache** | Salva e restaura `lastStableSpeedFactor` (validade 30d, tolerância $\le 5\%$) | ✅ Conforme (v1.1.02) |
| **Nudge Persistente com Debounce (`lyricBiasSeconds`)** | Imune a realinhamento acústico, salvo em cache com debounce de 3s | ✅ Conforme (v1.1.02) |
| **Fonte Preferencial de Letras Persistida** | Salva e prioriza a fonte bem-sucedida (LRCLIB, NetEase, Megalobiz) | ✅ Conforme (v1.1.02) |
| **Inferência de Lados de Vinil (`SideEstimator`)** | Lados A/B/C/D com suporte a catálogo, numeração e ponto médio | ✅ Conforme (v1.1.00) |
| **Preditor Determinístico Desacoplado (`TrackPredictor`)** | Predição com eliminação por adjacência (next, alternative, afterNext, afterFlip) | ✅ Conforme (v1.1.00) |
| **Exclusão Mútua de Microfone & Tokens de Concorrência** | Priorização `user` vs `background`, cancelamento limpo e preempção | ✅ Conforme (v1.1.05) |
| **Limpeza Explícita de Telemetria (`copyWith` anulável)** | Reset garantido de `sideEndLabel`, `predictedNext`, `trackDuration` | ✅ Conforme (v1.1.05) |
| **Resiliência Assíncrona do Motor (`_guarded`)** | Blindagem contra crashes silenciosos em background com logs estruturados | ✅ Conforme (v1.1.05) |
| **Guarda `isSameTrack` em Mid-Song & Reset de Duração** | Elimina saltos para offset errado e contaminação de duração entre músicas | ✅ Conforme (v1.1.05) |
| **Trava Estrita de Nome e Capa do Disco Físico** | Descarte de álbum/capa do Shazam para manter integridade da sessão do vinil | ✅ Conforme (v1.1.04) |
| **Fim de Lado e Virada de Disco (`waitingEndOfSide`)** | Estado visual "VIRE O DISCO" com sondagem periódica e resposta ao toque | ✅ Conforme (v1.1.00) |
| **Regra de 3 Confirmações Consecutivas em Ordem para Álbum** | Grava `preferredAlbum` apenas após 3 faixas consecutivas na ordem correta | ✅ Conforme (v1.1.01) |
| **Desambiguação Sequencial de Coletâneas (`isSequentialMatch`)** | Descarta coletâneas com ordem diferente da sequência real ouvida | ✅ Conforme (v1.1.01) |
| **Resolução Cache-First de Letras (Memória -> Disco -> Rede)** | Busca no prefetch em memória e cache em disco antes de consultar a rede | ✅ Conforme (v1.1.00) |
| **Nome da Música no Topo & Música a Seguir Embaixo** | Título ativo substitui WaxClub no AppBar; próxima música indicada abaixo | ✅ Conforme (v1.0.010) |
| **Inversão dos Ícones de Informações e Cast** | Info no canto esquerdo (leading); Cast no canto direito (actions) | ✅ Conforme (v1.0.010) |
| **Remoção de Título/Banda no Rodapé & Sem Overflow** | Rodapé exibe apenas telemetria; textos blindados com ellipsis | ✅ Conforme (v1.0.010) |
| **Ocultação de IP na Lista de Aparelhos** | Lista de TVs exibe apenas o nome do aparelho sem endereço IP | ✅ Conforme (v1.0.010) |
| **Realinhamento da letra no timestamp a cada escuta** | Implementado com zero deadband no `_baseOffset` | ✅ Conforme |
| **3ª verificação confirmatória em desvio > 1.5% aos 30s** | Substituída na v1.1.10 pelas checagens de sincronia contínuas | 🔄 Revisado (v1.1.10) |
| **Remoção do campo para digitar IP da TV** | Removido do modal de conexão (busca automática via mDNS/Cast) | ✅ Conforme |
| **Halo neon circular (ao iniciar + 1x por minuto)** | Implementado com timer de 60s e ciclos controlados | ✅ Conforme |
| **Ajuste fino de rotação (Pitch) na tela de controle** | Implementado slider, botões micro-passo e nudge no Cockpit | ✅ Conforme |
| **Botão "Travar Pitch" (Lock Rotation)** | Fixa rotação em 33.3 RPM para vitrolas já estabilizadas | ✅ Conforme |
| **Suavização Ponderada do Desvio (Filtro EMA)** | Substituída na v1.1.10 por regressão + fusão bayesiana | 🔄 Revisado (v1.1.10) |
| **Escuta rápida inicial (3.5s) + Janela Adaptativa (7s)** | 3.5s para resposta instantânea; 7s automático para sinais difíceis | ✅ Conforme |
| **Normalização do Áudio contra Ruído de Agulha** | Filtro passa-altas (~50Hz) anti-rumble e normalização de pico | ✅ Conforme |
| **Predição de Disco & Exibição da Próxima Música** | Mapeamento no prefetch com banner no Cockpit e transição com zero espera | ✅ Conforme |
| **Nomes Reais e Filtragem Estrita (Mi Stick vs TV Desligada)** | Eureka + TLS 8009 descartando `isStandBy == true` e Nest speakers; identifica Mi Stick | ✅ Conforme (v1.0.009) |
| **Descontinuar versão para TV** | Leanback e receptores UDP removidos do AndroidManifest e código; app 100% móvel | ✅ Conforme |
| **Proporção da Capa e Rolagem Macia na TV** | Capa reduzida para 230px (área de letra 70%) e aceleração de rolagem por hardware | ✅ Conforme (v1.0.009) |
| **Compensação de Latência de Transmissão (+400ms Lookahead TV)** | Lookahead de 850ms na TV (+400ms sobre mobile) eliminando delay de áudio/Wi-Fi | ✅ Conforme (v1.0.009) |
| **Ocultação de Letras no Smartphone Durante o Cast** | Celular exibe estritamente o Cockpit de Controle de Vinil; letras apenas na TV | ✅ Conforme (v1.0.009) |
| **Roda de pensamento com feedback real de etapas** | Etapas claras (TLS, LAUNCH, confirmação) e alerta de erro real | ✅ Conforme (v1.0.008) |
| **Blindagem contra Confirmação Prematura** | Confirmação só ocorre com `transportId` real do receiver ativo | ✅ Conforme (v1.0.008) |
| **Remoção de Fallback Silencioso para CC1AD845** | Não mascara falhas; oferece rota de contingência no navegador local | ✅ Conforme (v1.0.008) |
| **Transmissão sem instalar app na TV** | Google Cast oficial (`27687E0B`) + Web Receiver local autônomo (porta 8088) | ✅ Conforme (v1.0.008) |

---

## 5. Próximas Ações e Instruções para Modelos de IA Subsequentes

Para qualquer modelo de inteligência artificial ou desenvolvedor que for continuar a evolução deste projeto:
1. Manter a arquitetura de sincronismo baseada em `WaxClubEngine` (não alterar as fórmulas de `deltaMusica / deltaReal`).
2. O aplicativo é **estritamente para smartphone** — não reintroduzir `LEANBACK_LAUNCHER` no AndroidManifest.
3. Não adicionar dependências binárias que aumentem o tamanho do APK sem necessidade.
4. Manter o registro no [`RELEASE_LOG.md`](RELEASE_LOG.md) e incrementar a versão a cada compilação gerada. Compilar com `flutter build apk --release --target-platform android-arm,android-arm64` (o APK com x86_64 fica ~20 MB maior por causa do ML Kit).
5. **Diretório Obrigatório de Entregáveis:** Todos os arquivos de entrega gerados (pacote ZIP de auditoria, cópia do APK compilado, manual funcional e log de versões) devem ser **obrigatoriamente armazenados na pasta `G:\Meu Drive\WaxClub\`**. No Drive fica **só a versão atual**: a cada deploy, o `deploy.ps1` move os arquivos das versões anteriores para `H:\WaxClub_Arquivo\` (`APKs\`, `Codigo\`, `Documentacao\Manual`, `Documentacao\Release_Log`, `TV\Receptor`, `TV\Capas`). O Google Drive usa o disco C: como cache; com o C: cheio, as cópias para o G: falham.
6. **Identificação com Versão nos Nomes:** Todos os arquivos armazenados nessa pasta devem conter a versão explícita no nome para rastreabilidade (ex: `WaxClub_Source_Audit_vX.X.XXX.zip`, `WaxClub_vX.X.XXX.apk`, `MANUAL_FUNCIONAL_WAXCLUB_vX.X.XXX.md`, `RELEASE_LOG_vX.X.XXX.md`).

## 6. Melhorias Propostas (ainda não implementadas)

Registro de tudo o que foi proposto e combinado com o usuário, em ordem de prioridade. O detalhamento completo fica no documento do cronograma (Claude Docs, seções "Prioridade definida em 12/10/2026" e "Modo Manual").

### 6.1 Cronograma definido pelo usuário

**Nova ordem (13/10/2026):** 1.3.10 `.arb` + aviso de microfone (feito) → 1.3.11 reconhecimento pela câmera (feito) → 1.3.12 Plugin Jukebox e botões de madeira (feito) → 1.3.13 botão "Identify" e ajuda (feito) → 1.3.14 chave MANUAL (feito) → 1.3.15 verificação no catálogo + escuta pela minutagem + ▶ cromado (feito) → 1.3.16 curiosidades (feito no celular; TV pendente) → depois capa e minutagem medida. A conta de login (item 1 abaixo) entra assim que chegarem os dados da Hostinger e do Google. Itens abaixo na ordem original de importância.
1. **Conta + coleção:** login por link mágico (e-mail) e Google, conta opcional, API PHP + MySQL na Hostinger. Na conta: coleção, discos padrão de "Change record" e histórico de audições (tabela de audições; disco conta 1 vez por sessão de 2 h, qualquer faixa ouvida). Perfil social: apelido, e-mail, país e cidade obrigatórios; campos opcionais com visibilidade por campo; 18+. Social v1: perfil público com coleção, seguir, mural "ouvindo agora", busca por cidade/país.
2. **Sincronização com o Discogs nos dois sentidos**, feita pelo celular com o token do usuário. Campos da coleção seguem o Discogs (release_id obrigatório; nota 1–5, estado do disco/capa e observações opcionais).
3. ~~Textos da interface em arquivos `.arb`~~ — **feito na v1.3.10**.
4. **Plugins de idioma:** pacotes só de dados, listados numa página HTML na Hostinger.
5. **Modo Manual (antecipado: 1.3.11 a 1.3.13):**
   * Câmera na barra superior, ao lado de My Collection, com guia de onde apontar em cada modo (código de barras na contracapa, nº de catálogo na lombada/selo, capa, contracapa).
   * Reconhecimento só gratuito: código de barras, nº de catálogo, texto da capa (ML Kit no aparelho), comparação visual com as capas candidatas, índice local de capas conhecidas, contracapa, digitar.
   * Depois do reconhecimento: confirmar a prensagem → "Add to collection?" (termina o cadastro) → "Let's listen?" Sim/Não.
   * Verifica se o disco está no catálogo de reconhecimento do Shazam (≈ Apple Music, via iTunes por código de barras ou artista + álbum, faixa a faixa). Se estiver, segue no automático com o disco travado; se não, avisa e liga o Modo Manual.
   * Chave **MANUAL** na barra superior (feita na v1.3.14): começa desligada e desliga sozinha quando o disco termina (fim da última música do último lado: B num LP simples, último lado num duplo).
   * No Manual, o microfone cromado vira um **▶ cromado**. O microfone só mede volume para achar o começo da música e os silêncios entre faixas; sem microfone, o usuário toca ▶ quando a música começa.
   * Minutagem do LP: Discogs da prensagem → outras prensagens em vinil → MusicBrainz (vinil) → Wikipedia → outras fontes do LP. Durações digitais só em último caso. Não contar com o selo. Minutagem medida pelo microfone tem prioridade e será compartilhada.
   * Letra por plugin opcional; sem plugin ou sem letra, **curiosidades** curtas do disco e das faixas (sempre em inglês), animadas (sobem e esmaecem) no celular e na TV, guardadas no aparelho e depois no banco (tabela compartilhada).

### 6.2 Outras melhorias oferecidas
* ~~Aviso "microfone em uso por outro app"~~ — **feito na v1.3.10**.
* Traduzir também a página da TV (`web_receiver/index.html`), que ainda tem os textos no próprio HTML.
* Atualizar a paleta da página da TV (GitHub Pages) para o creme/laranja/madeira do app.
* Revisar as partes desatualizadas do documento de arquitetura.
* Repositório privado: a página da TV e as capas já estão no site `waxclub.com.br/tv/` (Hostinger); depois de trocar a URL no console do Cast, tirar `index.html` + `covers/` do GitHub Pages e deixar o repositório privado.

### 6.3 Pendências do lado do usuário
* Datas de shows pela cidade do usuário: criar a chave da Ticketmaster Discovery API e/ou pedir o app_id da Bandsintown; pedir a cidade no app até a conta existir (deixado para depois em 13/10/2026).
* Publicar no GitHub (Push origin no GitHub Desktop).
* Atualizar a URL do receptor no console do Google Cast (App ID 27687E0B) para `https://waxclub.com.br/tv/` (site na Hostinger desde 13/10/2026; a cópia no GitHub Pages fica até essa troca).
* App da Fire TV (`H:\Github\WaxClubClient`): renomear para WaxClub, anunciar `_waxclub-tv._tcp` e sincronizar o receptor.
* Hostinger: site `waxclub.com.br` criado (servidor no Brasil) e banco MySQL `waxclub` criado pelo usuário; subdomínio `api.waxclub.com.br` com SSL e a API PHP publicada (código em `server/`, ver `server/README.md`); faltam o `waxclub.env` com a senha do banco (escrito pelo usuário, modelo em `server/waxclub.env.example`), o e-mail `no-reply@` e o projeto OAuth no Google Cloud.
