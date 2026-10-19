param(
  [Parameter(Position = 0)]
  [ValidateSet('setup','web','build','analyze','test','check','format','doctor','clean')]
  [string]$Action = 'web'
)
$ErrorActionPreference='Stop'
$Root=Split-Path $PSScriptRoot -Parent
$DataRoot=Join-Path $env:LOCALAPPDATA 'PadelCommunity'
$SettingsFile=Join-Path $DataRoot 'settings.json'
$LogDir=Join-Path $DataRoot 'logs'
New-Item -ItemType Directory -Force -Path $DataRoot,$LogDir | Out-Null
$S=@{FlutterRoot=(Join-Path $DataRoot 'flutter-sdk\flutter')}
try{if(Test-Path $SettingsFile){$j=Get-Content $SettingsFile -Raw|ConvertFrom-Json;foreach($p in $j.PSObject.Properties){$S[$p.Name]=$p.Value}}}catch{}
$FlutterRoot=[IO.Path]::GetFullPath([string]$S.FlutterRoot)
$SdkParent=Split-Path $FlutterRoot -Parent
$Flutter=Join-Path $FlutterRoot 'bin\flutter.bat'
$Dart=Join-Path $FlutterRoot 'bin\dart.bat'
$LogFile=Join-Path $LogDir 'flutter-setup.log'
$PubCache=Join-Path $SdkParent 'pub-cache'
$Port=7357
$env:PUB_CACHE=$PubCache
try{[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12}catch{}
try{[Net.WebRequest]::DefaultWebProxy.Credentials=[Net.CredentialCache]::DefaultNetworkCredentials}catch{}
function Write-Log([string]$Message){
  $line='[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$Message
  Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
  Write-Output $line
}
function Invoke-Flutter([string[]]$Arguments){
  Write-Log ('flutter '+($Arguments -join ' '))
  & $Flutter @Arguments
  if($LASTEXITCODE -ne 0){throw "Flutter ha restituito il codice $LASTEXITCODE. Consultare $LogFile."}
}
function Install-Flutter{
  if(Test-Path $Flutter){Write-Log "SDK Flutter gia presente: $FlutterRoot";return}
  New-Item -ItemType Directory -Force -Path $SdkParent | Out-Null
  $manifestUrl='https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json'
  Write-Log 'Cerco la versione stable ufficiale di Flutter per Windows.'
  $manifest=Invoke-RestMethod -Uri $manifestUrl -TimeoutSec 60
  $hash=$manifest.current_release.stable
  $release=$manifest.releases|Where-Object{$_.hash -eq $hash}|Select-Object -First 1
  if(-not $release){$release=$manifest.releases|Where-Object{$_.channel -eq 'stable'}|Sort-Object release_date -Descending|Select-Object -First 1}
  if(-not $release -or -not $release.archive){throw 'Impossibile individuare il pacchetto Flutter stable nel manifest ufficiale.'}
  $archiveUrl=([string]$manifest.base_url).TrimEnd('/')+'/'+$release.archive
  $zipPath=Join-Path $SdkParent 'flutter-windows-stable.zip'
  Write-Log "Versione selezionata: $($release.version)"
  Write-Log "Destinazione persistente: $SdkParent"
  if((Test-Path $zipPath) -and (Get-Item $zipPath).Length -lt 100MB){Remove-Item $zipPath -Force}
  if(-not (Test-Path $zipPath)){
    Write-Log 'Download Flutter: il file e grande, attendere il completamento.'
    Invoke-WebRequest -Uri $archiveUrl -OutFile $zipPath -UseBasicParsing -TimeoutSec 0
  }else{Write-Log 'Archivio di download gia presente: provo a riutilizzarlo.'}
  Write-Log 'Estrazione SDK. Il file ZIP verra eliminato dopo una verifica riuscita.'
  Expand-Archive -LiteralPath $zipPath -DestinationPath $SdkParent -Force
  if(-not (Test-Path $Flutter)){throw "Estrazione incompleta: non trovo $Flutter. L'archivio e stato conservato per il recupero."}
  Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
  Invoke-Flutter @('--version')
  Write-Log 'SDK Flutter estratto correttamente.'
}
function Prepare-Web{
  Invoke-Flutter @('config','--enable-web')
  Invoke-Flutter @('precache','--web')
  Invoke-Flutter @('pub','get')
}
function Run-Format{
  Write-Log 'Formatto i file Dart in lib e test.'
  & $Dart format (Join-Path $Root 'lib') (Join-Path $Root 'test')
  if($LASTEXITCODE -ne 0){throw "dart format ha restituito il codice $LASTEXITCODE."}
}
try{
  if($Action -eq 'clean'){
    if(Test-Path (Join-Path $Root 'build')){Remove-Item (Join-Path $Root 'build') -Recurse -Force}
    if(Test-Path (Join-Path $Root '.dart_tool')){Remove-Item (Join-Path $Root '.dart_tool') -Recurse -Force}
    Write-Log 'Cache di progetto rimossa. SDK e cache persistenti sono stati conservati.'
    exit 0
  }
  Install-Flutter
  switch($Action){
    'setup' { Prepare-Web; Write-Log 'Setup completato. Premi Avvia anteprima nel pannello.' }
    'web' {
      Prepare-Web
      $url="http://127.0.0.1:$Port"
      Start-Job -ArgumentList $url,$Port -ScriptBlock {
        param($targetUrl,$targetPort)
        for($i=0;$i -lt 120;$i++){
          $client=New-Object System.Net.Sockets.TcpClient
          try{$client.Connect('127.0.0.1',[int]$targetPort);$client.Close();Start-Process $targetUrl;return}
          catch{$client.Close();Start-Sleep -Seconds 1}
        }
      }|Out-Null
      Write-Log "Anteprima Web: $url"
      Invoke-Flutter @('run','-d','web-server','--web-hostname','127.0.0.1','--web-port',"$Port")
    }
    'build' { Prepare-Web;Invoke-Flutter @('build','web');Write-Log "Build pronta: $Root\build\web" }
    'format' { Run-Format }
    'analyze' { Invoke-Flutter @('pub','get');Invoke-Flutter @('analyze') }
    'test' { Invoke-Flutter @('pub','get');Invoke-Flutter @('test') }
    'check' { Prepare-Web;Run-Format;Invoke-Flutter @('analyze');Invoke-Flutter @('test');Invoke-Flutter @('build','web');Write-Log "Controlli completati. Build Web: $Root\build\web" }
    'doctor' { & $Flutter doctor -v;if($LASTEXITCODE -ne 0){throw "flutter doctor ha restituito il codice $LASTEXITCODE."} }
  }
}catch{
  Write-Log ('ERRORE: '+$_.Exception.Message)
  Write-Output "Setup non riuscito. Apri il pannello Padel e consulta: $LogFile"
  exit 1
}
