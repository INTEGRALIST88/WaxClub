# Proposta de Melhorias — Sistema de Predição de Músicas (WaxClub)

> **Documento de Engenharia e Roadmap Técnico**  
> **Módulo Focado:** Motor Preditivo de Faixas (`PrefetchService`, `WaxClubEngine`, `VinylCacheService`)  
> **Objetivo:** Aumentar a precisão da próxima música, eliminar gargalos de rede, respeitar a física dos discos de vinil (Lados A/B) e aperfeiçoar a confirmação acústica.

---

## 1. Contexto e Diagnóstico do Sistema Atual

Atualmente, o WaxClub executa uma previsão de faixas em 4 etapas:
1. **Prefetch em Background:** Consulta o cache local ou a API do MusicBrainz para mapear a tracklist e pré-baixar as letras.
2. **Disparo no Fim da Música:** Acionado quando o tempo da faixa (compensado pelo *pitch drift*) chega a zero.
3. **Exibição Preditiva Imediata:** Exibe a letra da próxima faixa sem tela em branco e sem aguardar o microfone.
4. **Confirmação Silenciosa via Shazam:** Realiza dupla captura em segundo plano para confirmar ou retificar a previsão.

Embora funcional, foram identificados gargalos operacionais e físicos inerentes à audição de discos de vinil que motivam as melhorias a seguir.

---

## 2. Melhorias Propostas

### 🚀 Melhoria 1: Provedor Rápido de Tracklists (iTunes Search API como Primário)
* **Problema Atual:** A API do MusicBrainz impõe limite estrito de 1 requisição por segundo. Para pesquisar a gravação e consultar 2 a 3 lançamentos (releases), o app gasta de 4 a 6 segundos apenas em espera forçada (`await Future.delayed(1s)`).
* **Solução Proposta:**
  * Implementar uma fonte rápida de tracklists antes do MusicBrainz: a **iTunes Search / Lookup API** (`https://itunes.apple.com/search?term=...&entity=album` e `https://itunes.apple.com/lookup?id=...&entity=song`).
  * A API do iTunes é gratuita, aberta, não exige autenticação, não possui rate limit restritivo de 1s e entrega a tracklist oficial completa com ordem numérica das faixas em **menos de 300 ms**.
  * **Estratégia em Cascata:**
    1. Consulta Rápida (iTunes API — resposta sub-segundo).
    2. Consulta Profunda (MusicBrainz — acervo completo de prensagens raras como fallback).

---

### 📀 Melhoria 2: Inteligência de Mídia Física — Divisão de Lado A e Lado B
* **Problema Atual:** O sistema trata a tracklist como uma lista sequencial contínua (ex: faixas 1 a 10). Quando a última faixa do Lado A (faixa 5) termina, o app prevê automaticamente a faixa 6 (início do Lado B). No vinil real, a agulha entra no sulco final (*run-out groove*) e fica girando no vazio.
* **Solução Proposta:**
  * Extrair dos metadados de vinil do MusicBrainz ou inferir pelo número médio de faixas a quebra física de lados (`Side A` / `Side B`, faixas `A1..A5` e `B1..B5`).
  * Ao atingir a última música do Lado A:
    * **Não disparar a reprodução da faixa do Lado B.**
    * Desligar o avanço automático da letra.
    * Exibir no smartphone e na TV o estado: `🔄 FIM DO LADO A — VIRE O DISCO`.
    * Entrar em modo de espera com baixo consumo de energia até a agulha tocar o Lado B.

---

### 🎯 Melhoria 3: Tratamento de Ambiguidade de Coletâneas ("Greatest Hits" vs "Álbum de Estúdio")
* **Problema Atual:** Faixas clássicas consagradas (ex: *"Bohemian Rhapsody"*) estão presentes tanto no álbum de estúdio (*A Night at the Opera*) quanto em coletâneas (*Greatest Hits*) e discos ao vivo. A próxima música depende de qual disco físico específico está na vitrola.
* **Solução Proposta:**
  * Em vez de prever apenas 1 única faixa na primeira execução de um disco desconhecido, o `PrefetchService` deve manter as **2 ou 3 próximas faixas mais prováveis** em memória (`candidateNextTracks`).
  * Se a confirmação acústica da primeira opção falhar no Shazam, o motor verifica imediatamente a segunda opção já pré-carregada na RAM, evitando recomeçar a busca do zero.
  * Uma vez confirmada a 2ª música consecutiva, o sistema fixa o disco exato no cache persistente como **Álbum Preferencial**, eliminando ambiguidades para sempre.

---

### 🎙️ Melhoria 4: Filtro de Energia Sonora para o Sulco de Silêncio (*Inter-Track Gap*)
* **Problema Atual:** Discos de vinil possuem entre 2 a 4 segundos de silêncio e chiado entre as faixas (*inter-track silence gap*). Atualmente, há apenas um atraso fixo de 2 segundos antes de abrir o microfone. Em discos com introduções suaves ou pausas longas, o microfone grava silêncio e a primeira tentativa do Shazam falha.
* **Solução Proposta:**
  * Implementar uma verificação leve de energia sonora (cálculo de amplitude RMS do áudio PCM de 16 kHz capturado nos primeiros instantes).
  * Se o nível sonoro indicar apenas ruído de fundo da sala ou estática mecânica do vinil, o início da janela de amostragem de 5 segundos é aguardado de forma adaptativa até que os acordes musicais realmente comecem.

---

### ⚡ Melhoria 5: Indicador Visual de Pré-Carregamento no Cockpit
* **Problema Atual:** O usuário visualiza apenas o texto `A seguir: [Título]`, sem saber se a letra já está disponível ou se ainda depende de conexão com a internet.
* **Solução Proposta:**
  * Adicionar um badge sutil na interface (`⚡ Pronto em Cache` ou ícone verde de disco sincronizado) quando tanto a tracklist quanto o arquivo `.lrc` da próxima faixa já estiverem 100% gravados em memória local.
  * Oferece transparência e tranquilidade ao ouvinte de que a transição preditiva ocorrerá sem engasgos, mesmo que a internet oscile durante a audição.

---

## 3. Matriz de Priorização e Impacto

| Proposta | Benefício Principal | Complexidade | Prioridade Recomendada |
| :--- | :--- | :---: | :---: |
| **1. Provedor Rápido (iTunes API)** | Reduz tempo de prefetch de ~5s para <300ms | Baixa | **Alta (Fase 1)** |
| **2. Detecção de Lado A e Lado B** | Alinhamento perfeito à experiência física do vinil | Média | **Alta (Fase 1)** |
| **3. Múltiplos Candidatos (Coletâneas)** | Resolução instantânea para faixas clássicas | Média | **Média (Fase 2)** |
| **4. Detecção de Energia Sonora (RMS)** | Elimina falso timeout no silêncio entre faixas | Média | **Média (Fase 2)** |
| **5. Indicador Visual de Cache** | Clareza e feedback visual na interface | Baixa | **Rápida / Imediata** |
