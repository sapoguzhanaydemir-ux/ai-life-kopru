<#
  AI LIFE yürütücü servisi
  Repoyu belirli aralıklarla kontrol eder; bu makineye ait bekleyen emir varsa Claude Code'u çalıştırır.
  Sinyal (heartbeat) ve SAP (ADT) erişim durumunu 'durum-<makine>' dalına yazar.
  Ayarlar (Yürütücü Açık/Kapalı, Aralık) tanimlar/musteriler.md'den okunur; panelden değiştirilir.
  Kullanım: powershell -ExecutionPolicy Bypass -File bekci.ps1 -Makine DEMO21
#>
param([Parameter(Mandatory = $true)][string]$Makine)

$ErrorActionPreference = 'Continue'
$env:GIT_TERMINAL_PROMPT = '0'
$Repo     = Split-Path $PSScriptRoot -Parent
$LogDir   = Join-Path $env:LOCALAPPDATA 'ai-life'
New-Item -ItemType Directory -Force $LogDir | Out-Null
$Log      = Join-Path $LogDir "$Makine.log"
$Label    = ($Makine.ToLower() -replace '[^a-z0-9]+', '-').Trim('-')
$HbDir    = Join-Path $LogDir "durum-$Label"
$SelfHash = (Get-FileHash $PSCommandPath).Hash
$AdtPort  = 2236
$script:sonHata = ''
$script:sonIs   = $null
$lastHb   = [datetime]::MinValue
$lastCode = [datetime]::MinValue

function Log([string]$m) {
  Add-Content $Log ("{0:yyyy-MM-dd HH:mm:ss} {1}" -f (Get-Date), $m) -Encoding UTF8
  if ((Get-Item $Log).Length -gt 1MB) { Move-Item $Log "$Log.old" -Force }
}

function Hucreler([string]$line) { ($line.Trim().Trim('|') -split '\|') | ForEach-Object { $_.Trim() } }

function Ayar {
  $f = Join-Path $Repo 'tanimlar\musteriler.md'
  $lines = @(Get-Content $f -Encoding UTF8 | Where-Object { $_ -match '^\s*\|' -and $_ -notmatch '^\s*\|\s*:?-' })
  if ($lines.Count -lt 2) { return $null }
  $head = @(Hucreler $lines[0])
  foreach ($l in $lines[1..($lines.Count - 1)]) {
    $c = @(Hucreler $l)
    if ($c[0] -eq $Makine) {
      $o = @{}
      for ($i = 0; $i -lt $head.Count; $i++) { $o[$head[$i]] = $c[$i] }
      return $o
    }
  }
  return $null
}

function Bekleyen {
  $n = 0
  foreach ($e in Get-ChildItem (Join-Path $Repo 'emirler') -Filter *.md) {
    if ($e.Name.StartsWith('_')) { continue }
    $f = @{}
    foreach ($l in Get-Content $e.FullName -Encoding UTF8) {
      if ($l -match '^\s*\|\s*([^|]+?)\s*\|\s*([^|]*?)\s*\|\s*$') { $f[$matches[1]] = $matches[2] }
    }
    if ($f['Müşteri'] -eq $Makine -and ($f['Durum'] -eq 'Verildi' -or ($f['Durum'] -eq 'Onay bekliyor' -and $f['Onay']))) { $n++ }
  }
  return $n
}

function AdtAcik {
  try {
    $c = New-Object Net.Sockets.TcpClient
    $ok = $c.ConnectAsync('127.0.0.1', $AdtPort).Wait(1500) -and $c.Connected
    $c.Close(); return $ok
  } catch { return $false }
}

# SAP erişimi VS Code ADT eklentisinden gelir: VS Code kapalıysa simge durumunda başlat (son oturumu geri yükler)
function VsCodeAyakta {
  if (AdtAcik) { return }
  if (((Get-Date) - $script:lastCode).TotalMinutes -lt 5) { return }
  $script:lastCode = Get-Date
  if (Get-Process Code -ErrorAction SilentlyContinue) {
    $script:sonHata = "VS Code açık ama SAP bağlantısı (ADT, port $AdtPort) kapalı. Sisteme giriş yapılmış mı?"
    return
  }
  $exe = @("$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe", "$env:ProgramFiles\Microsoft VS Code\Code.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
  if (-not $exe) { $script:sonHata = 'VS Code bulunamadı'; return }
  Start-Process $exe -WindowStyle Minimized
  Log 'VS Code arka planda başlatıldı (ADT için)'
}

function Sinyal($ayar, [bool]$calisiyor = $false) {
  try {
    if (-not (Test-Path (Join-Path $HbDir '.git'))) {
      $url = git -C $Repo remote get-url origin
      git clone -q --depth 1 $url $HbDir 2>&1 | Out-Null
      git -C $HbDir checkout -q --orphan "durum-$Label" 2>&1 | Out-Null
      git -C $HbDir rm -rfq . 2>&1 | Out-Null
      git -C $HbDir config user.name "$Makine Yurutucu"
      git -C $HbDir config user.email 'yurutucu@ai-life.local'
    }
    $d = [ordered]@{
      makine    = $Makine
      zaman     = (Get-Date).ToString('o')
      yurutucu  = if ($ayar) { $ayar['Yürütücü'] } else { '' }
      aralik    = $script:aralik
      calisiyor = $calisiyor
      adt       = (AdtAcik)
      sonIs     = $script:sonIs
      sonHata   = $script:sonHata
      surum     = $SelfHash.Substring(0, 7)
    }
    [IO.File]::WriteAllText((Join-Path $HbDir 'durum.json'), ($d | ConvertTo-Json -Depth 4), (New-Object Text.UTF8Encoding $false))
    git -C $HbDir add durum.json 2>&1 | Out-Null
    git -C $HbDir rev-parse -q --verify HEAD 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { git -C $HbDir commit -q --amend -m sinyal 2>&1 | Out-Null }
    else { git -C $HbDir commit -q -m sinyal 2>&1 | Out-Null }
    $po = git -C $HbDir -c credential.interactive=never push -f origin "HEAD:refs/heads/durum-$Label" 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { Log "Sinyal push hatası: $($po.Trim())" }
  } catch { Log "Sinyal gönderilemedi: $_" }
}

$script:aralik = 60
Log "Yürütücü başladı ($Makine, sürüm $($SelfHash.Substring(0,7)))"

while ($true) {
  $ayar = $null
  try {
    $out = git -C $Repo pull -q --rebase 2>&1
    if ($LASTEXITCODE -ne 0) { $script:sonHata = "git pull: $out"; Log $script:sonHata }

    # Bekçi güncellendiyse kendini yeniden başlat
    if ((Get-FileHash $PSCommandPath).Hash -ne $SelfHash) {
      Log 'Yürütücü güncellendi, yeniden başlatılıyor'
      Start-Process powershell -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Makine $Makine" -WindowStyle Hidden
      exit
    }

    $ayar = Ayar
    if ($ayar -and $ayar['Aralık (sn)'] -match '^\d+$') { $script:aralik = [math]::Max(15, [int]$ayar['Aralık (sn)']) }
    $acik = $ayar -and $ayar['Yürütücü'] -ne 'Kapalı' -and $ayar['Aktif'] -ne 'Hayır'

    if ($acik) { VsCodeAyakta }
    if ($script:sonHata -like '*ADT, port*' -and (AdtAcik)) { $script:sonHata = '' }
    $n = 0
    if ($acik) { $n = Bekleyen }
    if ($n -gt 0 -and -not (AdtAcik)) {
      $m = "$n emir bekliyor ama SAP bağlantısı (ADT, port $AdtPort) kapalı. VS Code açık ve sisteme girişli mi?"
      if ($script:sonHata -ne $m) { Log $m }
      $script:sonHata = $m; $n = 0
    }
    if ($n -gt 0) {
      Log "$n emir bekliyor, ajan başlatılıyor"
      Sinyal $ayar $true; $lastHb = Get-Date
      Push-Location $Repo
      $sonuc = & claude -p "emirleri işle (makine: $Makine)" --allowedTools "mcp__adt" "Bash(git:*)" "Read" "Edit" "Write" 2>&1 | Out-String
      $kod = $LASTEXITCODE
      Pop-Location
      $ozet = ($sonuc.Trim() -replace '\s+', ' ')
      if ($ozet.Length -gt 400) { $ozet = $ozet.Substring(0, 400) + '…' }
      $script:sonIs = [ordered]@{ zaman = (Get-Date).ToString('o'); emir = $n; ozet = $ozet }
      if ($kod -ne 0) { $script:sonHata = "Ajan çıkış kodu $kod"; Log "$($script:sonHata): $ozet" }
      else { $script:sonHata = ''; Log "Ajan bitti: $ozet" }
      Sinyal $ayar $false; $lastHb = Get-Date
    }
  } catch {
    $script:sonHata = "$_"; Log "Hata: $_"
  }
  if (((Get-Date) - $lastHb).TotalSeconds -ge 120) { Sinyal $ayar $false; $lastHb = Get-Date }
  Start-Sleep -Seconds $script:aralik
}
