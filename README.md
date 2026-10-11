# vinylyric-tv
VINYLYRIC MOSTRA LETRAS DAS MUSICAS NATV E NO CELULAR DOS SEUS DISCOS 

## Arquitetura e próximos passos

Decisões e planos do projeto (TV, plugins, coleção, contas, plataformas): [docs/ARQUITETURA.md](docs/ARQUITETURA.md).

## Como abrir no celular (mesma rede Wi-Fi do PC)

1. No PC, sirva a pasta do projeto escutando em todas as interfaces (não só `localhost`):
   ```bash
   python -m http.server 8000 --bind 0.0.0.0
   # ou: npx http-server -a 0.0.0.0 -p 8000
   ```
2. Descubra o IP do PC na rede local (`ipconfig` no Windows, `ip a` no Linux, `ifconfig` no macOS), algo como `192.168.0.15`.
3. No celular, conectado ao **mesmo Wi-Fi**, abra `http://192.168.0.15:8000` (use o IP do seu PC, nunca `localhost`).
4. Se não abrir, libere a porta 8000 no firewall do PC (no Windows, permita o Python/Node em "Redes privadas") e confira se o Wi-Fi não tem "isolamento de clientes" ativado.
