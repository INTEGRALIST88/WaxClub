# WaxClub — Vinyl Social Club

App Android (Flutter) que ouve o disco de vinil pelo microfone, reconhece a música e mostra a letra sincronizada no celular e na TV (Google Cast), compensando a rotação do toca-discos.

Este repositório guarda:

* **O código do app** (Flutter): `lib/`, `test/`, `android/`, `assets/`, `tool/`.
* **A página da TV**, publicada pelo GitHub Pages em `https://integralist88.github.io/WaxClub/`:
  * `index.html` — receptor do Google Cast (gerado a partir de `web_receiver/index.html` por `tool/sync_tv_receiver.ps1`);
  * `covers/` — capas dos LPs de trilhas de novela usadas pelo app e pela TV.

Documentação: `MANUAL_FUNCIONAL_WAXCLUB.md` (arquitetura e funcionamento) e `RELEASE_LOG.md` (histórico de versões).

Build: `flutter pub get` e `flutter build apk --release`. Deploy (APK, documentos e instalação via ADB): `deploy.ps1`.