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
$MinimumFreeGB=8
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
function Get-FreeSpaceGB([string]$Path){
  $probe=$Path
  while($probe -and -not(Test-Path $probe)){ $parent=Split-Path $probe -Parent; if($parent -eq $probe){break}; $probe=$parent }
  if(-not $probe -or -not(Test-Path $probe)){return -1}
  $drive=[IO.Path]::GetPathRoot([IO.Path]::GetFullPath($probe))
  try{$disk=Get-CimInstance Win32_LogicalDisk -Filter ("DeviceID='{0}'" -f $drive.TrimEnd('\'));return [math]::Round($disk.FreeSpace/1GB,2)}catch{return -1}
}
function Get-DirectorySizeGB([string]$Path){
  if(-not(Test-Path $Path)){return 0}
  try{$sum=(Get-ChildItem -LiteralPath $Path -Force -File -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum;return [math]::Round(([double]$sum/1GB),2)}catch{return -1}
}
function Install-Flutter{
  if(Test-Path $Flutter){Write-Log "SDK Flutter gia presente: $FlutterRoot";return}
  New-Item -ItemType Directory -Force -Path $SdkParent | Out-Null
  $free=Get-FreeSpaceGB $SdkParent
  if($free -ge 0 -and $free -lt $MinimumFreeGB){throw "Spazio insufficiente in $SdkParent : disponibili $free GB, richiesti almeno $MinimumFreeGB GB. Cambia disco dal pannello prima di continuare."}
  if($free -ge 0){Write-Log "Spazio libero prima dell'installazione: $free GB. Controllo prudenziale: almeno $MinimumFreeGB GB."}
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
  if(Test-Path $zipPath){
    $zipValid=$false
    try{
      Add-Type -AssemblyName System.IO.Compression.FileSystem
      $archive=[System.IO.Compression.ZipFile]::OpenRead($zipPath)
      $archive.Dispose()
      $zipValid=$true
    }catch{$zipValid=$false}
    if(-not $zipValid){Write-Log 'Archivio precedente incompleto o non valido: lo scarico di nuovo.';Remove-Item $zipPath -Force -ErrorAction SilentlyContinue}
  }
  if(-not (Test-Path $zipPath)){
    $partialPath=$zipPath+'.part'
    Remove-Item -LiteralPath $partialPath -Force -ErrorAction SilentlyContinue
    $expected=-1
    try{$head=[Net.HttpWebRequest]::Create($archiveUrl);$head.Method='HEAD';$head.Timeout=20000;$response=$head.GetResponse();$expected=$response.ContentLength;$response.Close()}catch{}
    if($expected -gt 0){
      $zipGB=[math]::Round($expected/1GB,2)
      Write-Log "Dimensione archivio dichiarata dal server: $zipGB GB."
      $free=Get-FreeSpaceGB $SdkParent
      $needed=[math]::Ceiling(($expected*2.5)/1GB)
      if($free -ge 0 -and $free -lt $needed){throw "Spazio insufficiente: archivio stimato $zipGB GB, disponibili $free GB. Servono circa $needed GB per download ed estrazione. Cambia destinazione e riprova."}
    }else{Write-Log 'Il server non ha dichiarato la dimensione del file; controllo spazio prudenziale gia eseguito.'}
    Write-Log 'Download Flutter in file temporaneo. Non chiudere la finestra.'
    $request=[Net.HttpWebRequest]::Create($archiveUrl);$request.Timeout= [System.Threading.Timeout]::Infinite;$request.ReadWriteTimeout=[System.Threading.Timeout]::Infinite
    $response=$request.GetResponse()
    try{
      $expectedStream=$response.ContentLength
      $inputStream=$response.GetResponseStream()
      $outputStream=New-Object IO.FileStream($partialPath,[IO.FileMode]::Create,[IO.FileAccess]::Write,[IO.FileShare]::None)
      try{
        $buffer=New-Object byte[] (1MB);[long]$received=0;$lastLog=0
        while(($read=$inputStream.Read($buffer,0,$buffer.Length)) -gt 0){
          $outputStream.Write($buffer,0,$read);$received+=$read
          if(($received-$lastLog) -ge 50MB){$mb=[math]::Round($received/1MB);if($expectedStream -gt 0){$pct=[math]::Round(100*$received/$expectedStream,1);Write-Log "Download: $mb MB / $([math]::Round($expectedStream/1MB)) MB ($pct%)."}else{Write-Log "Download: $mb MB ricevuti."};$lastLog=$received}
        }
      }finally{$outputStream.Dispose();$inputStream.Dispose()}
    }finally{$response.Close()}
    if($expected -gt 0 -and (Get-Item $partialPath).Length -ne $expected){throw "Download incompleto: ricevuti $((Get-Item $partialPath).Length) byte, attesi $expected. Il file temporaneo resta disponibile per diagnosi; riprova dopo aver controllato la connessione."}
    Move-Item -LiteralPath $partialPath -Destination $zipPath -Force
    Write-Log "Download completato: $([math]::Round((Get-Item $zipPath).Length/1GB,2)) GB."
  }else{Write-Log 'Archivio ZIP valido gia presente: provo a riutilizzarlo.'}
  Write-Log "Dimensione archivio da estrarre: $([math]::Round((Get-Item $zipPath).Length/1GB,2)) GB."
  Write-Log 'Estrazione SDK. Il file ZIP verra eliminato dopo una verifica riuscita.'
  Expand-Archive -LiteralPath $zipPath -DestinationPath $SdkParent -Force
  if(-not (Test-Path $Flutter)){throw "Estrazione incompleta: non trovo $Flutter. L'archivio e stato conservato per il recupero."}
  Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
  Invoke-Flutter @('--version')
  $sdkSize=Get-DirectorySizeGB $FlutterRoot
  $freeAfter=Get-FreeSpaceGB $SdkParent
  Write-Log "SDK Flutter estratto correttamente. Ingombro SDK stimato: $sdkSize GB. Spazio libero residuo: $freeAfter GB."
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
