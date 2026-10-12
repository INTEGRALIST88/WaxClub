# Recomprime as capas baixadas (até 400x400 px, JPEG qualidade 82) para hospedagem no GitHub Pages.
# Uso: powershell -File resize_covers.ps1 -Source <pasta das capas baixadas> -Dest <web_receiver\covers>
param(
  [Parameter(Mandatory = $true)][string]$Source,
  [Parameter(Mandatory = $true)][string]$Dest,
  [int]$MaxSize = 400,
  [long]$Quality = 82
)
Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force $Dest | Out-Null
$codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$params = New-Object System.Drawing.Imaging.EncoderParameters(1)
$params.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, $Quality)
$total = 0; $count = 0; $failed = 0
Get-ChildItem $Source -File | Where-Object { $_.Extension -match '^\.(jpe?g|png|gif|webp)$' } | ForEach-Object {
  $out = Join-Path $Dest ($_.BaseName + '.jpg')
  try {
    $img = [System.Drawing.Image]::FromFile($_.FullName)
    $scale = [Math]::Min(1.0, $MaxSize / [Math]::Max($img.Width, $img.Height))
    $w = [int][Math]::Round($img.Width * $scale); $h = [int][Math]::Round($img.Height * $scale)
    $bmp = New-Object System.Drawing.Bitmap($w, $h)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.Clear([System.Drawing.Color]::Black)
    $g.DrawImage($img, 0, 0, $w, $h)
    $bmp.Save($out, $codec, $params)
    $g.Dispose(); $bmp.Dispose(); $img.Dispose()
    $total += (Get-Item $out).Length; $count++
  } catch {
    $failed++
    Write-Host "falhou: $($_.Exception.Message) - $out"
  }
}
"{0} capas, {1:N1} MB, {2} falhas" -f $count, ($total / 1MB), $failed
