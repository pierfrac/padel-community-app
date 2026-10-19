param(
  [Parameter(Position = 0)]
  [ValidateSet('setup', 'web', 'build', 'analyze', 'test', 'check', 'format', 'doctor', 'clean')]
  [string]$Action = 'web'
)
$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
$Runtime = Join-Path $Root 'runtime'
$SdkParent = Join-Path $Runtime 'flutter-sdk'
$FlutterRoot = Join-Path $SdkParent 'flutter'
$Flutter = Join-Path $FlutterRoot 'bin\flutter.bat'
$LogDir = Join-Path $Root 'logs'
$LogFile = Join-Path $LogDir 'flutter-setup.log'
$Port = 7357
New-Item -ItemType Directory -Force -Path $Runtime, $LogDir | Out-Null
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
try { [Net.WebRequest]::DefaultWebProxy.Credentials = [Net.CredentialCache]::DefaultNetworkCredentials } catch {}
function Write-Log([string]$Message) {
  $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
  Add-Content -Path $LogFile -Value $line
  Write-Host $line
}
function Invoke-Flutter([string[]]$Arguments) {
  Write-Log ("flutter " + ($Arguments -join ' '))
  & $Flutter @Arguments
  if ($LASTEXITCODE -ne 0) { throw "Flutter ha restituito il codice $LASTEXITCODE. Consultare $LogFile." }
}
function Install-Flutter {
  if (Test-Path $Flutter) {
    Write-Log "Flutter SDK gia' presente: $FlutterRoot"
    return
  }
  Write-Log 'Recupero la versione stable di Flutter per Windows.'
  $manifestUrl = 'https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json'
  $manifest = Invoke-RestMethod -Uri $manifestUrl -TimeoutSec 60
  $releaseHash = $manifest.current_release.stable
  $release = $manifest.releases | Where-Object { $_.hash -eq $releaseHash } | Select-Object -First 1
  if (-not $release) {
    $release = $manifest.releases | Where-Object { $_.channel -eq 'stable' } | Sort-Object release_date -Descending | Select-Object -First 1
  }
  if (-not $release -or -not $release.archive) { throw 'Impossibile individuare il pacchetto Flutter stable nel manifest ufficiale.' }
  $baseUrl = ([string]$manifest.base_url).TrimEnd('/')
  $archiveUrl = "$baseUrl/$($release.archive)"
  $zipPath = Join-Path $Runtime 'flutter-windows-stable.zip'
  Write-Log "Versione selezionata: $($release.version)"
  Write-Log "Download ufficiale: $archiveUrl"
  Write-Host 'Il download dello SDK puo'' richiedere tempo e spazio su disco.'
  Invoke-WebRequest -Uri $archiveUrl -OutFile $zipPath -UseBasicParsing -TimeoutSec 0
  Write-Log 'Estrazione dello SDK nella cartella runtime locale.'
  New-Item -ItemType Directory -Force -Path $SdkParent | Out-Null
  Expand-Archive -LiteralPath $zipPath -DestinationPath $SdkParent -Force
  Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
  if (-not (Test-Path $Flutter)) { throw "Lo SDK e' stato estratto ma non trovo $Flutter." }
  Invoke-Flutter @('--version')
  Invoke-Flutter @('config', '--enable-web')
  Invoke-Flutter @('precache', '--web')
  Write-Log 'Flutter per Web installato.'
}
try {
  switch ($Action) {
    'setup' {
      Install-Flutter
      Invoke-Flutter @('--version')
      Invoke-Flutter @('config', '--enable-web')
      Invoke-Flutter @('precache', '--web')
      Invoke-Flutter @('pub', 'get')
      Write-Host ''
      Write-Host 'Setup completato. Esegui PADEL.bat web per avviare l''anteprima.'
    }
    'web' {
      Install-Flutter
      Invoke-Flutter @('config', '--enable-web')
      Invoke-Flutter @('pub', 'get')
      $url = "http://127.0.0.1:$Port"
      Start-Job -ArgumentList $url, $Port -ScriptBlock {
        param($targetUrl, $targetPort)
        for ($i = 0; $i -lt 120; $i++) {
          $client = New-Object System.Net.Sockets.TcpClient
          try {
            $client.Connect('127.0.0.1', [int]$targetPort)
            $client.Close()
            Start-Process $targetUrl
            return
          } catch {
            $client.Close()
            Start-Sleep -Seconds 1
          }
        }
      } | Out-Null
      Write-Host "Anteprima Web: $url"
      Write-Host 'Premi Ctrl+C in questa finestra per fermare il server.'
      Invoke-Flutter @('run', '-d', 'web-server', '--web-hostname', '127.0.0.1', '--web-port', "$Port")
    }
    'build' {
      Install-Flutter
      Invoke-Flutter @('config', '--enable-web')
      Invoke-Flutter @('pub', 'get')
      Invoke-Flutter @('build', 'web')
      Write-Host "Build pronta in: $Root\build\web"
    }
    'format' {
      Install-Flutter
      $Dart = Join-Path $FlutterRoot 'bin\dart.bat'
      Write-Log 'Formatto i file Dart in lib e test.'
      & $Dart format (Join-Path $Root 'lib') (Join-Path $Root 'test')
      if ($LASTEXITCODE -ne 0) { throw "dart format ha restituito il codice $LASTEXITCODE." }
    }
    'analyze' {
      Install-Flutter
      Invoke-Flutter @('pub', 'get')
      Invoke-Flutter @('analyze')
    }
    'test' {
      Install-Flutter
      Invoke-Flutter @('pub', 'get')
      Invoke-Flutter @('test')
    }
    'check' {
      Install-Flutter
      Invoke-Flutter @('config', '--enable-web')
      Invoke-Flutter @('pub', 'get')
      $Dart = Join-Path $FlutterRoot 'bin\dart.bat'
      Write-Log 'Formatto i file Dart in lib e test.'
      & $Dart format (Join-Path $Root 'lib') (Join-Path $Root 'test')
      if ($LASTEXITCODE -ne 0) { throw "dart format ha restituito il codice $LASTEXITCODE." }
      Invoke-Flutter @('analyze')
      Invoke-Flutter @('test')
      Invoke-Flutter @('build', 'web')
      Write-Host "Controlli completati. Build Web: $Root\build\web"
    }
    'doctor' {
      Install-Flutter
      & $Flutter doctor -v
      Write-Host ''
      Write-Host 'Per la preview Web non serve configurare Android Studio o un emulatore.'
    }
    'clean' {
      if (Test-Path (Join-Path $Root 'build')) { Remove-Item (Join-Path $Root 'build') -Recurse -Force }
      if (Test-Path (Join-Path $Root '.dart_tool')) { Remove-Item (Join-Path $Root '.dart_tool') -Recurse -Force }
      Write-Host 'Cache di progetto rimossa. Lo SDK portabile e'' stato conservato.'
    }
  }
} catch {
  Write-Log ("ERRORE: " + $_.Exception.Message)
  Write-Host ''
  Write-Host 'Setup non riuscito. Controlla logs\flutter-setup.log e le policy di rete del PC.' -ForegroundColor Yellow
  exit 1
}
