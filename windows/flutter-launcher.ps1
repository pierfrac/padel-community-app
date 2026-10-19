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
function Test-FlutterArchive([string]$Path,[string]$ExpectedSha256){
  if(-not (Test-Path -LiteralPath $Path) -or -not $ExpectedSha256){return $false}
  try{
    $actual=(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    if($actual -ne $ExpectedSha256.ToLowerInvariant()){return $false}
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive=[System.IO.Compression.ZipFile]::OpenRead($Path)
    try{$entry=$archive.GetEntry('flutter/bin/flutter.bat');return ($null -ne $entry)}
    finally{$archive.Dispose()}
  }catch{return $false}
}
function Install-Flutter{
  if(Test-Path $Flutter){
    Write-Log "SDK Flutter gia presente: $FlutterRoot"
    return
  }
  New-Item -ItemType Directory -Force -Path $SdkParent | Out-Null
  $free=Get-FreeSpaceGB $SdkParent
  if($free -ge 0 -and $free -lt $MinimumFreeGB){
    throw "Spazio insufficiente in $SdkParent : disponibili $free GB, richiesti almeno $MinimumFreeGB GB. Cambia disco dal pannello prima di continuare."
  }
  if($free -ge 0){Write-Log "Spazio libero prima dell'installazione: $free GB."}

  $manifestUrl='https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json'
  Write-Log 'Cerco la versione stable ufficiale di Flutter per Windows.'
  $manifest=Invoke-RestMethod -Uri $manifestUrl -TimeoutSec 60
  $hash=[string]$manifest.current_release.stable
  $release=$manifest.releases|Where-Object{$_.hash -eq $hash -and $_.channel -eq 'stable'}|Select-Object -First 1
  if(-not $release){throw 'Impossibile individuare la release stable corrente nel manifest ufficiale.'}
  if(-not $release.archive -or [string]$release.sha256 -notmatch '^[A-Fa-f0-9]{64}
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
){
    throw 'Il manifest ufficiale non contiene archivio e checksum SHA-256 validi.'
  }

  $expectedSha256=([string]$release.sha256).ToLowerInvariant()
  $archiveUrl=([string]$manifest.base_url).TrimEnd('/')+'/'+[string]$release.archive
  $zipPath=Join-Path $SdkParent ("flutter-windows-{0}-stable.zip" -f $release.version)
  $partialPath=$zipPath+'.part'
  $legacyZip=Join-Path $SdkParent 'flutter-windows-stable.zip'
  Write-Log "Versione stable selezionata: $($release.version)"
  Write-Log "Archivio ufficiale: $archiveUrl"
  Write-Log "Destinazione persistente: $SdkParent"
  Write-Log "Checksum SHA-256 atteso: $expectedSha256"

  # Compatibilita con la precedente versione del launcher, che usava un nome ZIP generico.
  if(-not (Test-Path -LiteralPath $zipPath) -and (Test-Path -LiteralPath $legacyZip)){
    $legacyValid=Test-FlutterArchive $legacyZip $expectedSha256
    if($legacyValid){
      Move-Item -LiteralPath $legacyZip -Destination $zipPath -Force
      Write-Log 'Archivio generico precedente verificato e riutilizzato.'
    }else{
      Write-Log 'Archivio generico precedente non corrispondente alla release corrente: non verra installato.'
      try{
        $lock=[System.IO.File]::Open($legacyZip,[System.IO.FileMode]::Open,[System.IO.FileAccess]::ReadWrite,[System.IO.FileShare]::None)
        $lock.Dispose()
        Remove-Item -LiteralPath $legacyZip -Force
        Write-Log 'Archivio obsoleto rimosso per evitare di occupare spazio inutilmente.'
      }catch{
        throw "Il vecchio archivio $legacyZip sembra ancora in uso. Interrompi la vecchia installazione e riprova."
      }
    }
  }

  $archiveValid=$false
  if(Test-Path -LiteralPath $zipPath){
    Write-Log 'Verifico checksum e struttura dello ZIP gia presente.'
    $archiveValid=Test-FlutterArchive $zipPath $expectedSha256
    if(-not $archiveValid){
      Write-Log 'Lo ZIP esistente non corrisponde alla release ufficiale o e incompleto: lo elimino.'
      Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
    }
  }

  if(-not $archiveValid){
    $expectedLength=-1
    try{
      $head=[Net.HttpWebRequest]::Create($archiveUrl)
      $head.Method='HEAD'
      $head.Timeout=20000
      $head.AllowAutoRedirect=$true
      $responseHead=$head.GetResponse()
      $expectedLength=$responseHead.ContentLength
      $responseHead.Close()
    }catch{
      Write-Log 'Il server non ha fornito la dimensione con HEAD; usero il checksum ufficiale per validare il download.'
    }

    if($expectedLength -gt 0){
      $zipGB=[math]::Round($expectedLength/1GB,2)
      Write-Log "Dimensione archivio compresso dichiarata: $zipGB GB."
      $free=Get-FreeSpaceGB $SdkParent
      $needed=[math]::Max($MinimumFreeGB,[math]::Ceiling(($expectedLength*3)/1GB))
      if($free -ge 0 -and $free -lt $needed){
        throw "Spazio insufficiente: ZIP compresso $zipGB GB, disponibili $free GB, stima prudenziale richiesta $needed GB. Cambia destinazione dal pannello."
      }
    }else{
      Write-Log "Spazio libero disponibile: $free GB. Procedo senza stima della dimensione, usando SHA-256 per controllare l'integrita."
    }

    $offset=0L
    if(Test-Path -LiteralPath $partialPath){
      $offset=(Get-Item -LiteralPath $partialPath).Length
      if($expectedLength -gt 0 -and $offset -ge $expectedLength){
        Write-Log 'File parziale gia della dimensione attesa: verifico il checksum prima di riscaricare.'
        if((Get-FileHash -LiteralPath $partialPath -Algorithm SHA256).Hash.ToLowerInvariant() -eq $expectedSha256){
          Move-Item -LiteralPath $partialPath -Destination $zipPath -Force
          $archiveValid=Test-FlutterArchive $zipPath $expectedSha256
        }else{
          Remove-Item -LiteralPath $partialPath -Force
          $offset=0L
        }
      }
    }

    if(-not $archiveValid -and -not (Test-Path -LiteralPath $zipPath)){
      Write-Log "Avvio download dell'archivio ufficiale. Il file resta nella cartella runtime, non in TEMP."
      if($offset -gt 0){Write-Log "Riprendo il download dal byte $offset."}
      $request=[Net.HttpWebRequest]::Create($archiveUrl)
      $request.Timeout=[System.Threading.Timeout]::Infinite
      $request.ReadWriteTimeout=[System.Threading.Timeout]::Infinite
      $request.AllowAutoRedirect=$true
      if($offset -gt 0){$request.AddRange([long]$offset)}
      $response=$request.GetResponse()
      try{
        $append=($offset -gt 0 -and [int]$response.StatusCode -eq 206)
        if($offset -gt 0 -and -not $append){
          Write-Log 'Il server non supporta la ripresa per questo download: riparto dal byte zero.'
          $offset=0L
        }
        $mode=if($append){[IO.FileMode]::Append}else{[IO.FileMode]::Create}
        [long]$received=$offset
        $totalLength=$expectedLength
        if($totalLength -le 0 -and $response.ContentLength -gt 0){
          $totalLength=$response.ContentLength
          if($append){$totalLength+=$offset}
        }
        $inputStream=$response.GetResponseStream()
        $outputStream=New-Object IO.FileStream($partialPath,$mode,[IO.FileAccess]::Write,[IO.FileShare]::None)
        try{
          $buffer=New-Object byte[] (1MB)
          [long]$lastLog=$received
          while(($read=$inputStream.Read($buffer,0,$buffer.Length)) -gt 0){
            $outputStream.Write($buffer,0,$read)
            $received+=$read
            if(($received-$lastLog) -ge 25MB){
              $mb=[math]::Round($received/1MB,1)
              if($totalLength -gt 0){
                $pct=[math]::Min(100,[math]::Round(100*$received/$totalLength,1))
                Write-Log "Download: $mb MB / $([math]::Round($totalLength/1MB,1)) MB ($pct%)."
              }else{
                Write-Log "Download: $mb MB ricevuti."
              }
              $lastLog=$received
            }
          }
        }finally{
          $outputStream.Dispose()
          $inputStream.Dispose()
        }
      }finally{$response.Close()}

      if($expectedLength -gt 0 -and (Get-Item -LiteralPath $partialPath).Length -ne $expectedLength){
        throw "Download incompleto: ricevuti $((Get-Item -LiteralPath $partialPath).Length) byte, attesi $expectedLength. Il file resta in .part e il prossimo tentativo proverra a riprendere dal punto raggiunto."
      }
      Write-Log 'Download terminato. Verifico checksum SHA-256 ufficiale...'
      $downloadHash=(Get-FileHash -LiteralPath $partialPath -Algorithm SHA256).Hash.ToLowerInvariant()
      if($downloadHash -ne $expectedSha256){
        Remove-Item -LiteralPath $partialPath -Force -ErrorAction SilentlyContinue
        throw "Il checksum SHA-256 del download non corrisponde al manifest ufficiale. Il file incompleto/corrotto e stato eliminato; premi di nuovo l'azione per riscaricarlo."
      }
      Move-Item -LiteralPath $partialPath -Destination $zipPath -Force
      $archiveValid=Test-FlutterArchive $zipPath $expectedSha256
      if(-not $archiveValid){
        Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
        throw 'Lo ZIP scaricato supera il checksum ma non contiene flutter/bin/flutter.bat. Pacchetto non installato.'
      }
      Write-Log "Download e verifica completati: $([math]::Round((Get-Item -LiteralPath $zipPath).Length/1GB,2)) GB."
    }
  }else{
    Write-Log 'Archivio ZIP corrispondente alla release corrente: riutilizzo dopo checksum verificato.'
  }

  if(-not (Test-Path -LiteralPath $zipPath)){throw 'Archivio Flutter non disponibile dopo il download/verifica.'}
  Write-Log "Estrazione SDK nella cartella persistente: $SdkParent"
  Write-Log "Non chiudere il pannello durante l'estrazione."
  $tar=Get-Command tar.exe -ErrorAction SilentlyContinue
  if($tar){
    & $tar.Source -xf $zipPath -C $SdkParent
    if($LASTEXITCODE -ne 0){throw "tar.exe non e riuscito a estrarre l'archivio (codice $LASTEXITCODE). Lo ZIP verificato e stato conservato per riprovare."}
  }else{
    Expand-Archive -LiteralPath $zipPath -DestinationPath $SdkParent -Force
  }
  if(-not (Test-Path -LiteralPath $Flutter)){
    throw "Estrazione incompleta: non trovo $Flutter. Lo ZIP verificato e stato conservato per riprovare."
  }
  Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
  Invoke-Flutter @('--version')
  $sdkSize=Get-DirectorySizeGB $FlutterRoot
  $freeAfter=Get-FreeSpaceGB $SdkParent
  Write-Log "SDK Flutter verificato. Ingombro SDK stimato: $sdkSize GB. Spazio libero residuo: $freeAfter GB."
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
