# WaxClub — Vinyl Social Club

App Android (Flutter) que ouve o disco de vinil pelo microfone, reconhece a música e mostra a letra sincronizada no celular e na TV (Google Cast), compensando a rotação do toca-discos.

Este repositório guarda:

* **O código do app** (Flutter): `lib/`, `test/`, `android/`, `assets/`, `tool/`.
* **O site `waxclub.com.br`** (Hostinger), gerado pelo `deploy.ps1` em `build/waxclub_site.zip`:
  * `/` — página inicial (`site/index.html`);
  * `/tv/` — receptor do Google Cast (`web_receiver/index.html`, também embutido no app por `tool/sync_tv_receiver.ps1`);
  * `/tv/covers/` — capas dos LPs de trilhas de novela usadas pelo app e pela TV (pasta `covers/`).
* **Cópia temporária no GitHub Pages** (`https://integralist88.github.io/WaxClub/`: `index.html` + `covers/` na raiz), mantida até a URL do receptor ser trocada para `https://waxclub.com.br/tv/` no Google Cast Developer Console (App ID 27687E0B) e as versões antigas do app saírem de uso.

Documentação: `MANUAL_FUNCIONAL_WAXCLUB.md` (arquitetura e funcionamento) e `RELEASE_LOG.md` (histórico de versões).

Build: `flutter pub get` e `flutter build apk --release`. Deploy (APK, documentos e instalação via ADB): `deploy.ps1`.