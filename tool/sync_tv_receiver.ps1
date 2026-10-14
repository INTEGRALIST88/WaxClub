# Gera lib/services/tv_web_receiver_html.dart a partir de web_receiver/index.html.
# O receptor oficial do Google Cast (GitHub Pages) e a página servida pelo celular ao navegador da TV
# passam a ser o mesmo arquivo; a versão do celular apenas não carrega o SDK do Cast.
# Uso: powershell -ExecutionPolicy Bypass -File tool\sync_tv_receiver.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$html = [IO.File]::ReadAllText((Join-Path $root 'web_receiver\index.html'))

if ($html.Contains("'''")) { throw "index.html contém ''' e não pode ser embutido em raw string Dart." }

# Remove o comentário e a tag do SDK CAF (só existe no runtime do Chromecast)
$browserHtml = [regex]::Replace($html, '(?m)^[ \t]*<!-- Google Cast Application Framework.*?-->\r?\n', '')
$browserHtml = [regex]::Replace($browserHtml, '(?m)^[ \t]*<script src="//www\.gstatic\.com/cast/[^"]*"></script>\r?\n', '')

$dart = @"
// ARQUIVO GERADO por tool/sync_tv_receiver.ps1 a partir de web_receiver/index.html — não editar à mão.

/// Tela de exibição da TV servida localmente pelo smartphone em ``http://<IP_DO_CELULAR>:8088``.
///
/// É o mesmo layout do receptor oficial do Google Cast (web_receiver/index.html), sem o SDK do Cast:
/// no navegador da TV a página se conecta por WebSocket ao celular (``/cast``).
class TvWebReceiverHtml {
  static String build() => _html;

  static const String _html = r'''
"@ + $browserHtml + "''';`n}`n"

[IO.File]::WriteAllText((Join-Path $root 'lib\services\tv_web_receiver_html.dart'), $dart, (New-Object Text.UTF8Encoding $false))
Write-Host "[OK] lib/services/tv_web_receiver_html.dart regenerado."

# Cópia temporária no GitHub Pages (raiz do repositório INTEGRALIST88/WaxClub); o receptor oficial passa a ser
# https://waxclub.com.br/tv/ (Hostinger), publicado pelo ZIP do site gerado no deploy.ps1
[IO.File]::WriteAllText((Join-Path $root 'index.html'), $html, (New-Object Text.UTF8Encoding $false))
Write-Host "[OK] index.html da raiz (GitHub Pages) atualizado."
