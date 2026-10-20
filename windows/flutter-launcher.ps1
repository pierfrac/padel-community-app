param(
  [Parameter(Position = 0)]
  [ValidateSet('setup','web','build','analyze','test','check','format','doctor','clean')]
  [string]$Action = 'web',
  [string]$ProjectRoot,
  [int]$RequestedPort = 0,
  [string]$LogPath,
  [ValidateSet('google-admin','player')]
  [string]$TestRole = 'player',
  [string]$TestUserId = '',
  [string]$GoogleClientId = ''
)
$ErrorActionPreference='Stop'
$DefaultRoot=Split-Path $PSScriptRoot -Parent
$Root=if([string]::IsNullOrWhiteSpace($ProjectRoot)){$DefaultRoot}else{[IO.Path]::GetFullPath($ProjectRoot)}
if(-not (Test-Path -LiteralPath $Root -PathType Container)){throw "Cartella progetto non trovata: $Root"}
if($RequestedPort -ne 0 -and ($RequestedPort -lt 1024 -or $RequestedPort -gt 65535)){throw "Porta richiesta non valida: $RequestedPort"}
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
$LogFile=if([string]::IsNullOrWhiteSpace($LogPath)){Join-Path $LogDir 'flutter-setup.log'}else{[IO.Path]::GetFullPath($LogPath)}
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
function Add-GitRuntimeToPath([string]$GitHome){
  # Preserve the intended order: cmd\git.exe is the stable entry point.
  $dirs=@(
    (Join-Path $GitHome 'cmd'),
    (Join-Path $GitHome 'ucrt64\bin'),
    (Join-Path $GitHome 'mingw64\bin'),
    (Join-Path $GitHome 'usr\bin')
  )
  $existing=@($env:PATH -split ';' | ForEach-Object{$_.TrimEnd('\')})
  $prefix=New-Object System.Collections.Generic.List[string]
  foreach($dir in $dirs){
    if((Test-Path -LiteralPath $dir) -and $existing -notcontains $dir.TrimEnd('\')){
      $prefix.Add($dir)
    }
  }
  if($prefix.Count -gt 0){$env:PATH=($prefix -join ';')+';'+$env:PATH}
}
function Ensure-Git{
  $systemGit=Get-Command git.exe -ErrorAction SilentlyContinue
  if($systemGit){
    Write-Log "Git gia disponibile: $($systemGit.Source)"
    return
  }

  # MinGit is an official, portable Git for applications. Keep it in PADEL's user-data folder
  # and only amend PATH inside the current launcher process.
  $toolsRoot=Join-Path $DataRoot 'tools'
  $gitHome=Join-Path $toolsRoot 'mingit'
  $gitExe=Join-Path $gitHome 'cmd\git.exe'
  $gitZip=Join-Path $toolsRoot 'MinGit-2.56.0.2-64-bit.zip'
  $gitPart=$gitZip+'.part'
  $gitUrl='https://github.com/git-for-windows/git/releases/download/v2.56.0.windows.2/MinGit-2.56.0.2-64-bit.zip'
  $gitSha256='da35e72aa21c005a5a0d298cfbae110bc1609a815730ea0dde84b01a1b3cd3be'

  if(-not (Test-Path -LiteralPath $gitExe)){
    New-Item -ItemType Directory -Force -Path $toolsRoot | Out-Null
    $validZip=$false
    if(Test-Path -LiteralPath $gitZip){
      $validZip=((Get-FileHash -LiteralPath $gitZip -Algorithm SHA256).Hash.ToLowerInvariant() -eq $gitSha256)
    }
    if(-not $validZip){
      Remove-Item -LiteralPath $gitZip,$gitPart -Force -ErrorAction SilentlyContinue
      Write-Log 'Git non trovato. Scarico MinGit portabile ufficiale (circa 38 MB); non installa Git a livello di sistema.'
      $request=[Net.HttpWebRequest]::Create($gitUrl)
      $request.Timeout=[System.Threading.Timeout]::Infinite
      $request.ReadWriteTimeout=[System.Threading.Timeout]::Infinite
      $request.AllowAutoRedirect=$true
      $response=$request.GetResponse()
      try{
        $expectedLength=$response.ContentLength
        $inputStream=$response.GetResponseStream()
        $outputStream=New-Object IO.FileStream($gitPart,[IO.FileMode]::Create,[IO.FileAccess]::Write,[IO.FileShare]::None)
        try{
          $buffer=New-Object byte[] (1MB)
          [long]$received=0
          [long]$lastLog=0
          while(($read=$inputStream.Read($buffer,0,$buffer.Length)) -gt 0){
            $outputStream.Write($buffer,0,$read)
            $received+=$read
            if(($received-$lastLog) -ge 5MB){
              Write-Log ("Download MinGit: {0:N1} MB ricevuti." -f ($received/1MB))
              $lastLog=$received
            }
          }
        }finally{
          $outputStream.Dispose()
          $inputStream.Dispose()
        }
      }finally{$response.Close()}

      if($expectedLength -gt 0 -and (Get-Item -LiteralPath $gitPart).Length -ne $expectedLength){
        throw "Download MinGit incompleto: ricevuti $((Get-Item -LiteralPath $gitPart).Length) byte, attesi $expectedLength. Premi di nuovo l'azione per riprovare."
      }
      $actualHash=(Get-FileHash -LiteralPath $gitPart -Algorithm SHA256).Hash.ToLowerInvariant()
      if($actualHash -ne $gitSha256){
        Remove-Item -LiteralPath $gitPart -Force -ErrorAction SilentlyContinue
        throw 'Il checksum SHA-256 di MinGit non corrisponde alla release ufficiale. Download rifiutato.'
      }
      Move-Item -LiteralPath $gitPart -Destination $gitZip -Force
      Write-Log 'Archivio MinGit verificato con SHA-256.'
    }else{
      Write-Log 'Archivio MinGit gia presente e verificato.'
    }

    $stage=Join-Path $toolsRoot 'mingit-staging'
    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $stage | Out-Null
    Expand-Archive -LiteralPath $gitZip -DestinationPath $stage -Force
    $stagedGit=Join-Path $stage 'cmd\git.exe'
    if(-not (Test-Path -LiteralPath $stagedGit)){
      Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
      throw 'Il pacchetto MinGit ufficiale non contiene cmd\git.exe nella struttura attesa; non verra attivato.'
    }
    if(Test-Path -LiteralPath $gitHome){Remove-Item -LiteralPath $gitHome -Recurse -Force}
    Move-Item -LiteralPath $stage -Destination $gitHome
    Remove-Item -LiteralPath $gitZip -Force -ErrorAction SilentlyContinue
    Write-Log "MinGit portabile installato in $gitHome."
  }

  Add-GitRuntimeToPath $gitHome
  if(-not (Get-Command git.exe -ErrorAction SilentlyContinue)){
    throw "MinGit e presente ma PowerShell non riesce a trovare git.exe in $gitHome."
  }
  $gitVersion=& $gitExe --version 2>&1
  if($LASTEXITCODE -ne 0){throw "MinGit non si avvia correttamente: $gitVersion"}
  Write-Log "Git disponibile per Flutter: $gitVersion"
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
  if(-not $release.archive -or [string]$release.sha256 -notmatch '^[A-Fa-f0-9]{64}$'){
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

  # Recupera anche il .part creato dalla versione precedente del launcher.
  $legacyPartial=$legacyZip+'.part'
  if(-not (Test-Path -LiteralPath $partialPath) -and (Test-Path -LiteralPath $legacyPartial)){
    Write-Log 'Trovato un download parziale della versione precedente: controllo che non sia ancora in uso.'
    try{
      $partialLock=[System.IO.File]::Open($legacyPartial,[System.IO.FileMode]::Open,[System.IO.FileAccess]::ReadWrite,[System.IO.FileShare]::None)
      $partialLock.Dispose()
      Move-Item -LiteralPath $legacyPartial -Destination $partialPath -Force
      Write-Log 'Download parziale trasferito al nome versionato; il prossimo tentativo proverra a riprenderlo.'
    }catch{
      throw "Il file parziale $legacyPartial sembra ancora in uso. Interrompi il vecchio processo PowerShell e riprova."
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
function Get-FreeLoopbackPort([int]$StartPort=7357,[int]$EndPort=7399,[int]$SeedPort=7357){
  if($StartPort -gt $EndPort){throw 'Intervallo di porte non valido.'}
  $count=$EndPort-$StartPort+1
  for($offset=0;$offset -lt $count;$offset++){
    $candidate=$StartPort+((($SeedPort-$StartPort)+$offset)%$count)
    $listener=$null
    try{
      $listener=[System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback,$candidate)
      $listener.Start()
      return $candidate
    }catch{
      # Port is unavailable; try the next local port.
    }finally{
      if($listener){try{$listener.Stop()}catch{}}
    }
  }
  throw "Nessuna porta libera trovata tra $StartPort e $EndPort per l'anteprima Web."
}
function Open-BrowserWhenWebReady([string]$TargetUrl,[int]$TargetPort,[string]$LogPath){
  Start-Job -ArgumentList $TargetUrl,$TargetPort,$LogPath -ScriptBlock {
    param($url,$port,$logPath)
    for($attempt=0;$attempt -lt 180;$attempt++){
      $rootResponse=$null
      $scriptResponse=$null
      try{
        $rootRequest=[Net.HttpWebRequest]::Create($url+'/')
        $rootRequest.Timeout=2500
        $rootRequest.ReadWriteTimeout=2500
        $rootResponse=$rootRequest.GetResponse()
        $rootStatus=[int]$rootResponse.StatusCode
        $rootResponse.Close()
        $rootResponse=$null

        if($rootStatus -ge 200 -and $rootStatus -lt 400){
          $scriptRequest=[Net.HttpWebRequest]::Create($url+'/main.dart.js')
          $scriptRequest.Timeout=2500
          $scriptRequest.ReadWriteTimeout=2500
          $scriptResponse=$scriptRequest.GetResponse()
          $mime=[string]$scriptResponse.ContentType
          $scriptResponse.Close()
          $scriptResponse=$null
          if($mime -match '(?i)(javascript|ecmascript)'){
            Add-Content -LiteralPath $logPath -Encoding UTF8 -Value ("[{0}] main.dart.js pronto (Content-Type: {1}); apro il browser su {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$mime,$url)
            Start-Process $url
            return
          }
        }
      }catch{
        # Flutter may still be compiling or the dev server may not be ready.
        if($_.Exception.Response){try{$_.Exception.Response.Close()}catch{}}
      }finally{
        if($rootResponse){try{$rootResponse.Close()}catch{}}
        if($scriptResponse){try{$scriptResponse.Close()}catch{}}
      }
      Start-Sleep -Seconds 1
    }
    Add-Content -LiteralPath $logPath -Encoding UTF8 -Value ("[{0}] ERRORE: il server non ha restituito main.dart.js con MIME JavaScript entro 180 secondi. Verificare la console del comando flutter run e riprovare." -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
  } | Out-Null
}
function Ensure-WebPlatform{
  $webIndex=Join-Path $Root 'web\index.html'
  if(Test-Path -LiteralPath $webIndex){
    Write-Log 'Scaffolding Web gia presente.'
    return
  }
  Write-Log 'Scaffolding Web mancante: lo genero con flutter create.'
  Push-Location $Root
  try{
    Invoke-Flutter @('create','--platforms=web','--project-name=padel_community_app','.')
  }finally{
    Pop-Location
  }
  if(-not (Test-Path -LiteralPath $webIndex)){
    throw "Flutter create non ha generato il file richiesto: $webIndex"
  }
  Write-Log 'Scaffolding Web pronto.'
}
function Ensure-Toolchain{
  # Multiple preview sessions may start at nearly the same time. Serialize
  # Git/Flutter provisioning so two processes never extract or download the SDK together.
  $mutex=[System.Threading.Mutex]::new($false,'Local\PadelCommunityToolchain')
  $ownsMutex=$false
  try{
    try{$ownsMutex=$mutex.WaitOne([TimeSpan]::FromMinutes(20))}
    catch [System.Threading.AbandonedMutexException]{
      $ownsMutex=$true
      Write-Log 'Recuperato il lock della toolchain lasciato da un processo terminato.'
    }
    if(-not $ownsMutex){throw 'Timeout: un altro processo sta installando Git o Flutter. Riprova tra poco.'}
    Ensure-Git
    Install-Flutter
  }finally{
    if($ownsMutex){$mutex.ReleaseMutex()}
    $mutex.Dispose()
  }
}
function Set-GoogleWebClientIdMetaTag([string]$ClientId){
  if([string]::IsNullOrWhiteSpace($ClientId)){return}
  $index=Join-Path $Root 'web\\index.html'
  if(-not (Test-Path -LiteralPath $index)){throw "Web index non trovato per configurare Google Sign-In: $index"}
  $html=[IO.File]::ReadAllText($index)
  $safeClientId=[System.Net.WebUtility]::HtmlEncode($ClientId.Trim())
  $meta='<meta name="google-signin-client_id" content="{0}">' -f $safeClientId
  if($html -match '(?is)<meta\\s+name=["'']google-signin-client_id["''][^>]*>'){
    $html=[regex]::Replace($html,'(?is)<meta\\s+name=["'']google-signin-client_id["''][^>]*>',$meta,1)
  }elseif($html -match '(?is)<head[^>]*>'){
    $html=[regex]::Replace($html,'(?is)<head[^>]*>','function Prepare-Web{
'+[Environment]::NewLine+'  '+$meta,1)
  }else{
    throw "Non trovo il tag <head> in $index per configurare Google Sign-In."
  }
  [IO.File]::WriteAllText($index,$html,[System.Text.UTF8Encoding]::new($false))
  Write-Log 'Google OAuth Web Client ID inserito nel solo workspace di test; il valore non viene scritto nel sorgente del repository.'
}
function Prepare-Web{
  # Sessions have separate project folders but share the Flutter SDK/cache.
  # Serialize SDK setup so two launches cannot update the Web cache concurrently.
  $mutex=[System.Threading.Mutex]::new($false,'Local\PadelCommunityPrepareWeb')
  $ownsMutex=$false
  try{
    try{$ownsMutex=$mutex.WaitOne([TimeSpan]::FromMinutes(15))}
    catch [System.Threading.AbandonedMutexException]{
      $ownsMutex=$true
      Write-Log 'Recuperato il lock di preparazione lasciato da un processo terminato.'
    }
    if(-not $ownsMutex){throw 'Timeout: un altro processo sta ancora preparando Flutter Web. Riprova tra poco.'}
    Invoke-Flutter @('config','--enable-web')
    Ensure-WebPlatform
    Invoke-Flutter @('precache','--web')
    Invoke-Flutter @('pub','get')
  }finally{
    if($ownsMutex){$mutex.ReleaseMutex()}
    $mutex.Dispose()
  }
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
  Ensure-Toolchain
  switch($Action){
    'setup' { Prepare-Web; Write-Log 'Setup completato. Premi Avvia anteprima nel pannello.' }
    'web' {
      Prepare-Web
      if($TestRole -eq 'google-admin' -and -not [string]::IsNullOrWhiteSpace($GoogleClientId)){
        Set-GoogleWebClientIdMetaTag $GoogleClientId
      }
      if($RequestedPort -gt 0){
        $Port=Get-FreeLoopbackPort $RequestedPort $RequestedPort $RequestedPort
      }else{
        $portSeed=Get-Random -Minimum 7357 -Maximum 7400
        $Port=Get-FreeLoopbackPort 7357 7399 $portSeed
      }
      $url="http://localhost:$Port"
      Write-Log "Porta libera selezionata per l'anteprima: $Port"
      Write-Log 'Apriro il browser solo quando main.dart.js sara servito come JavaScript, non quando risponde soltanto la porta TCP.'
      Open-BrowserWhenWebReady $url $Port $LogFile
      Write-Log "Anteprima Web in avvio: $url"
      $runArguments=@('run','-d','web-server','--web-hostname','127.0.0.1','--web-port',"$Port")
      if($TestRole -eq 'google-admin'){
        $runArguments+=('--dart-define=PADEL_TEST_ROLE=google-admin')
        $runArguments+=("--dart-define=PADEL_GOOGLE_CLIENT_ID={0}" -f $GoogleClientId)
        Write-Log 'Sessione admin: richiesto login Google reale. L autorizzazione amministrativa resta simulata in questa anteprima locale.'
      }elseif(-not [string]::IsNullOrWhiteSpace($TestUserId)){
        $runArguments+=("--dart-define=PADEL_TEST_ROLE={0}" -f $TestRole)
        $runArguments+=("--dart-define=PADEL_TEST_USER_ID={0}" -f $TestUserId)
        Write-Log ("Identita giocatore di test locale: {0}. Non e un account Google." -f $TestUserId)
      }
      Invoke-Flutter $runArguments
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
