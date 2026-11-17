<#
  AI LIFE yürütücü kurulumu (admin gerekmez)
  Kullanım (repo klasöründe): powershell -ExecutionPolicy Bypass -File .\yurutucu\kur.ps1 -Makine DEMO21
#>
param([Parameter(Mandatory = $true)][string]$Makine)

$Repo = Split-Path $PSScriptRoot -Parent
$Startup = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'

if (-not (Test-Path (Join-Path $Repo "makine\$Makine.md"))) { Write-Host "makine\$Makine.md bulunamadı. Makine adı doğru mu?" -ForegroundColor Red; exit 1 }
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) { Write-Host "'claude' komutu bulunamadı. Önce Claude Code CLI kurulmalı." -ForegroundColor Red; exit 1 }

git -C $Repo config user.name "$Makine Yurutucu"
git -C $Repo config user.email 'yurutucu@ai-life.local'
git -C $Repo config pull.rebase true
git -C $Repo config rebase.autoStash true

# Eski yapıyı durdur (GitHub runner + eski bekçi)
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
  Where-Object { $_.CommandLine -match 'bekci\.ps1' -and $_.ProcessId -ne $PID } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Get-Process Runner.Listener, Runner.Worker -ErrorAction SilentlyContinue | Stop-Process -Force
Remove-Item (Join-Path $Startup 'ai-life-runner.cmd') -ErrorAction SilentlyContinue

# Oturum açılınca otomatik başlat
$bekci = Join-Path $PSScriptRoot 'bekci.ps1'
$args1 = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$bekci`" -Makine $Makine"
Set-Content (Join-Path $Startup "ai-life-yurutucu-$Makine.cmd") "start `"`" powershell $args1" -Encoding ASCII

# Şimdi başlat
Start-Process powershell -ArgumentList $args1 -WindowStyle Hidden
Write-Host "Yürütücü kuruldu ve başlatıldı: $Makine" -ForegroundColor Green
Write-Host "Log: $env:LOCALAPPDATA\ai-life\$Makine.log"
