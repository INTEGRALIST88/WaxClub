param(
    # Caminho opcional do APK (padrao: saida do 'flutter build apk --release')
    [string]$ApkPath,
    # Publica no Drive sem reinstalar no celular (ex.: o usuario esta testando no aparelho)
    [switch]$SkipInstall
)

$ErrorActionPreference = 'Stop'

# Versao lida do pubspec.yaml (ex.: 1.1.09+2109 -> 1.1.09)
$projectDir = $PSScriptRoot
$pubspec = Get-Content -LiteralPath "$projectDir\pubspec.yaml" -Raw
if ($pubspec -notmatch '(?m)^version:\s*([^+\s]+)') { throw "Versao nao encontrada no pubspec.yaml" }
$version = $Matches[1] -replace '\.0$', ''  # 1.3.0 -> 1.3

$driveDir = "G:\Meu Drive\WaxClub"
# Versoes anteriores saem do Drive a cada deploy e ficam organizadas aqui
$archiveDir = "H:\WaxClub_Arquivo"
$apkSource = if ($ApkPath) { $ApkPath } else { "$projectDir\build\app\outputs\flutter-apk\app-release.apk" }
$apkDest = "$driveDir\WaxClub_v$version.apk"
$zipDest = "$driveDir\WaxClub_Source_Audit_v$version.zip"
$adbPath = "C:\Users\G_Sac\AppData\Local\Android\Sdk\platform-tools\adb.exe"
$deviceSerial = "XOQ8CABI9LZLH6HU"

Write-Host "=== Deploy WaxClub v$version ==="

Write-Host "=== 1. Verificando diretorio do Google Drive ==="
if (-not (Test-Path -LiteralPath $driveDir)) {
    New-Item -ItemType Directory -Path $driveDir -Force | Out-Null
}

Write-Host "=== 1b. Arquivando versoes anteriores em $archiveDir ==="
# Libera o Drive antes de copiar: tudo que tem versao no nome e nao e desta versao vai para o H:, por tipo
function Get-ArchiveFolder([string]$name) {
    switch -Regex ($name) {
        '^VinyLyric_v.*\.apk$'             { return 'APKs\VinyLyric' }
        '^WaxClub_v.*\.apk$'               { return 'APKs\WaxClub' }
        '^VinyLyric_Source_Audit_.*\.zip$' { return 'Codigo\VinyLyric' }
        '^WaxClub_Source_Audit_.*\.zip$'   { return 'Codigo\WaxClub' }
        '^MANUAL_FUNCIONAL_VINYLYRIC.*\.md$' { return 'Documentacao\Manual' }
        '^MANUAL_FUNCIONAL_WAXCLUB_v.*\.md$' { return 'Documentacao\Manual' }
        '^RELEASE_LOG_v.*\.md$'            { return 'Documentacao\Release_Log' }
        '^TV_RECEIVER_index_.*\.html$'     { return 'TV\Receptor' }
        '^TV_RECEIVER_covers_.*\.zip$'     { return 'TV\Capas' }
        default                            { return $null }
    }
}
$archived = 0; $archivedBytes = 0
foreach ($f in Get-ChildItem -LiteralPath $driveDir -File) {
    $sub = Get-ArchiveFolder $f.Name
    if (-not $sub) { continue }
    if ($f.Name -match ('_v' + [regex]::Escape($version) + '\.[a-z]+$')) { continue }  # versao atual fica
    $target = Join-Path $archiveDir $sub
    New-Item -ItemType Directory -Force -Path $target | Out-Null
    try {
        $len = $f.Length
        Move-Item -LiteralPath $f.FullName -Destination (Join-Path $target $f.Name) -Force -ErrorAction Stop
        $archived++; $archivedBytes += $len
    } catch {
        Write-Host "[AVISO] Nao foi possivel arquivar $($f.Name): $($_.Exception.Message)"
    }
}
Write-Host ("[OK] {0} arquivo(s) de versoes anteriores movidos para {1} ({2:N0} MB)." -f $archived, $archiveDir, ($archivedBytes / 1MB))

Write-Host "=== 2. Copiando APK Release ==="
if (-not (Test-Path -LiteralPath $apkSource)) {
    throw "Arquivo APK nao encontrado em $apkSource. Rode 'flutter build apk --release --target-platform android-arm,android-arm64' antes."
}
Copy-Item -LiteralPath $apkSource -Destination $apkDest -Force
$sizeMb = [math]::Round((Get-Item -LiteralPath $apkDest).Length / 1MB, 2)
Write-Host "[OK] APK v$version copiado para $apkDest ($sizeMb MB)"

Write-Host "=== 3. Copiando Documentacao ==="
Copy-Item -LiteralPath "$projectDir\RELEASE_LOG.md" -Destination "$driveDir\RELEASE_LOG.md" -Force
Copy-Item -LiteralPath "$projectDir\RELEASE_LOG.md" -Destination "$driveDir\RELEASE_LOG_v$version.md" -Force
Copy-Item -LiteralPath "$projectDir\MANUAL_FUNCIONAL_WAXCLUB.md" -Destination "$driveDir\MANUAL_FUNCIONAL_WAXCLUB.md" -Force
Copy-Item -LiteralPath "$projectDir\MANUAL_FUNCIONAL_WAXCLUB.md" -Destination "$driveDir\MANUAL_FUNCIONAL_WAXCLUB_v$version.md" -Force
Write-Host "[OK] Documentacao atualizada no Google Drive."

# Site waxclub.com.br (Hostinger): pagina inicial + receptor da TV em /tv/ + capas dos LPs em /tv/covers/.
# O ZIP e publicado pelo plugin da Hostinger (o deploy apaga a raiz do site e extrai o ZIP; subdominios ficam).
$siteDir = Join-Path $projectDir "build\waxclub_site"
$siteZip = Join-Path $projectDir "build\waxclub_site.zip"
if (Test-Path -LiteralPath $siteDir) { Remove-Item -LiteralPath $siteDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path "$siteDir\tv" | Out-Null
# (o waxclub.env da API fica FORA do public_html; o deploy por ZIP apagaria um arquivo deixado na raiz)
foreach ($f in @('index.html', 'logo.png', '.htaccess')) {
    Copy-Item -LiteralPath "$projectDir\site\$f" -Destination "$siteDir\$f" -Force
}
Copy-Item -LiteralPath "$projectDir\web_receiver\index.html" -Destination "$siteDir\tv\index.html" -Force
if (Test-Path "$projectDir\covers") { Copy-Item -LiteralPath "$projectDir\covers" -Destination "$siteDir\tv\covers" -Recurse -Force }
if (Test-Path -LiteralPath $siteZip) { Remove-Item -LiteralPath $siteZip -Force }
# tar do Windows (bsdtar): caminhos com "/" no ZIP; o Compress-Archive do PowerShell 5.1 grava "\" e quebra no Linux
& (Join-Path $env:SystemRoot 'System32\tar.exe') -a -c -f $siteZip -C $siteDir index.html logo.png .htaccess tv
if ($LASTEXITCODE -ne 0) { throw "Falha ao gerar o ZIP do site (tar, codigo $LASTEXITCODE)." }
Remove-Item -LiteralPath $siteDir -Recurse -Force
Write-Host ("[OK] Site gerado: {0} ({1:N1} MB) - publicar na Hostinger (waxclub.com.br)." -f $siteZip, ((Get-Item -LiteralPath $siteZip).Length / 1MB))

Write-Host "=== 4. Gerando ZIP limpo da auditoria de codigo ==="
# O Gradle do build que acabou de rodar segura arquivos em android\.gradle (checksums.lock): encerra antes de copiar
$gradlew = Join-Path $projectDir "android\gradlew.bat"
if (Test-Path -LiteralPath $gradlew) {
    Push-Location (Join-Path $projectDir "android")
    try { & $gradlew --stop *> $null } catch {}
    Pop-Location
}
# Usa H:\ (disco com espaco) quando disponivel; o C:\ costuma estar cheio
$tempRoot = if (Test-Path -LiteralPath "H:\") { "H:\" } else { $env:TEMP }
$tempZipDir = Join-Path $tempRoot "waxclub_source_v$version"
$localZip = Join-Path $tempRoot "WaxClub_Source_Audit_v$version.zip"
if (Test-Path -LiteralPath $tempZipDir) { Remove-Item -LiteralPath $tempZipDir -Recurse -Force }
if (Test-Path -LiteralPath $localZip) { Remove-Item -LiteralPath $localZip -Force }
New-Item -ItemType Directory -Path $tempZipDir -Force | Out-Null

$itemsToInclude = @(
    "lib",
    "android",
    "test",
    "web_receiver",
    "assets",
    "tool",
    "pubspec.yaml",
    "pubspec.lock",
    "analysis_options.yaml",
    "README.md",
    "RELEASE_LOG.md",
    "MANUAL_FUNCIONAL_WAXCLUB.md"
)

foreach ($item in $itemsToInclude) {
    $fullPath = Join-Path $projectDir $item
    if (-not (Test-Path -LiteralPath $fullPath)) { continue }
    if ($item -eq "android") {
        # Sem as pastas de cache/build (podem estar presas por outro programa, ex.: checksums.lock do Gradle)
        & robocopy $fullPath (Join-Path $tempZipDir "android") /E /XD .gradle build .kotlin .idea /NFL /NDL /NJH /NJS /NP | Out-Null
        if ($LASTEXITCODE -ge 8) { throw "Falha ao copiar a pasta android (robocopy $LASTEXITCODE)." }
        $global:LASTEXITCODE = 0
    } else {
        Copy-Item -LiteralPath $fullPath -Destination $tempZipDir -Recurse -Force
    }
}

# Remove artefatos de build/cache do Android que nao fazem parte do codigo-fonte
foreach ($junk in @("android\.gradle", "android\app\build", "android\build", "android\.kotlin")) {
    $junkPath = Join-Path $tempZipDir $junk
    if (Test-Path -LiteralPath $junkPath) { Remove-Item -LiteralPath $junkPath -Recurse -Force }
}
# Despejos de memória do Java/Gradle (.hprof, centenas de MB) e logs de falha da JVM
# (filtro por nome com Where-Object: no PowerShell 5.1, -Include é ignorado junto com -LiteralPath)
Get-ChildItem -LiteralPath $tempZipDir -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like '*.hprof' -or $_.Name -like 'hs_err_pid*.log' -or $_.Name -like 'replay_pid*.log' } |
    ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force }

Compress-Archive -Path "$tempZipDir\*" -DestinationPath $localZip -Force
Remove-Item -LiteralPath $tempZipDir -Recurse -Force

Copy-Item -LiteralPath $localZip -Destination $zipDest -Force
Remove-Item -LiteralPath $localZip -Force
$zipSizeMb = [math]::Round((Get-Item -LiteralPath $zipDest).Length / 1MB, 2)
Write-Host "[OK] Arquivo ZIP gerado: $zipDest ($zipSizeMb MB)"

Write-Host "=== 5. Instalando no Smartphone Xiaomi via ADB ==="
if ($SkipInstall) {
    Write-Host "[--] Instalacao pulada (-SkipInstall). APK disponivel no Google Drive."
} elseif (Test-Path -LiteralPath $adbPath) {
    $devices = & $adbPath devices
    if ($devices -match $deviceSerial) {
        Write-Host "Instalando APK no dispositivo $deviceSerial..."
        & $adbPath -s $deviceSerial install -r $apkDest
        if ($LASTEXITCODE -ne 0) { throw "Falha na instalacao via ADB (codigo $LASTEXITCODE)." }
        Write-Host "[OK] Instalacao concluida no dispositivo Xiaomi."
    } else {
        Write-Host "[AVISO] Dispositivo Xiaomi ($deviceSerial) nao conectado via ADB. APK disponivel no Google Drive."
    }
} else {
    Write-Host "[AVISO] ADB nao encontrado no caminho esperado."
}
