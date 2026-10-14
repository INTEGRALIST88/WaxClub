param(
    [string]$Url,
    [string]$AuthKey,
    [string]$RestAuthKey
)

$ErrorActionPreference = 'Stop'
$siteDir = "h:\Github\WaxClub\site"

# List all files to upload relative to siteDir
$files = Get-ChildItem -Path $siteDir -Recurse -File | Where-Object { 
    $_.Name -ne '.htaccess' -and $_.Name -ne 'logo_source.png'
}

Write-Host "Found $($files.Count) files to upload."

$curl = "C:\Windows\System32\curl.exe"

foreach ($f in $files) {
    # Get relative path with forward slashes
    $rel = $f.FullName.Substring($siteDir.Length + 1).Replace('\', '/')
    $size = $f.Length

    Write-Host "Uploading $rel ($size bytes)..." -NoNewline

    # Step 1: POST creation
    $targetUrl = "$Url/$rel`?override=true"
    $postCode = & $curl -s -o nul -w "%{http_code}" -X POST $targetUrl `
        -H "X-Auth: $AuthKey" `
        -H "X-Auth-Rest: $RestAuthKey" `
        -H "Tus-Resumable: 1.0.0" `
        -H "Upload-Length: $size" `
        -H "Upload-Offset: 0"

    if ($postCode -ne '201' -and $postCode -ne '200') {
        Write-Host " [POST failed: $postCode]" -ForegroundColor Red
        continue
    }

    # Step 2: PATCH payload
    $binArg = "@" + $f.FullName
    $patchCode = & $curl -s -o nul -w "%{http_code}" -X PATCH $targetUrl `
        -H "X-Auth: $AuthKey" `
        -H "X-Auth-Rest: $RestAuthKey" `
        -H "Tus-Resumable: 1.0.0" `
        -H "Content-Type: application/offset+octet-stream" `
        -H "Upload-Offset: 0" `
        --data-binary $binArg

    if ($patchCode -eq '204' -or $patchCode -eq '200') {
        Write-Host " [OK $patchCode]" -ForegroundColor Green
    } else {
        Write-Host " [PATCH failed: $patchCode]" -ForegroundColor Red
    }
}

Write-Host "`nAll files uploaded successfully!" -ForegroundColor Cyan
