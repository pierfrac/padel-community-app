# Padel Community - Windows control panel. Windows PowerShell 5.1 / built-in WinForms.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
$Win=$PSScriptRoot; $Root=Split-Path $Win -Parent; $Launcher=Join-Path $Win 'flutter-launcher.ps1'
$DataRoot=Join-Path $env:LOCALAPPDATA 'PadelCommunity'; $SettingsFile=Join-Path $DataRoot 'settings.json'
$LogDir=Join-Path $DataRoot 'logs'; $LogFile=Join-Path $LogDir 'flutter-setup.log'
$OutFile=Join-Path $LogDir 'panel.stdout.log'; $ErrFile=Join-Path $LogDir 'panel.stderr.log'
New-Item -ItemType Directory -Force -Path $DataRoot,$LogDir | Out-Null
$S=@{FlutterRoot=(Join-Path $DataRoot 'flutter-sdk\flutter');SetupComplete=$false}
try { if(Test-Path $SettingsFile){$old=Get-Content $SettingsFile -Raw|ConvertFrom-Json;foreach($p in $old.PSObject.Properties){$S[$p.Name]=$p.Value}} } catch {}
function Save-Settings {$S|ConvertTo-Json|Set-Content -LiteralPath $SettingsFile -Encoding UTF8}
function Has-Flutter([string]$p){return [bool]($p -and (Test-Path (Join-Path $p 'bin\flutter.bat')))}
function Show-StorageWizard {
  $d=New-Object System.Windows.Forms.Form;$d.Text='Padel Community | Ambiente portabile';$d.Size=New-Object System.Drawing.Size(690,430);$d.StartPosition='CenterScreen';$d.FormBorderStyle='FixedDialog';$d.MaximizeBox=$false
  $d.BackColor=[System.Drawing.Color]::FromArgb(18,25,38);$d.ForeColor=[System.Drawing.Color]::FromArgb(235,240,248);$d.Font=New-Object System.Drawing.Font('Segoe UI',10)
  $h=New-Object System.Windows.Forms.Label;$h.Text='Dove teniamo Flutter?';$h.Font=New-Object System.Drawing.Font('Segoe UI Semibold',19);$h.SetBounds(24,18,620,38);$d.Controls.Add($h)
  $sub=New-Object System.Windows.Forms.Label;$sub.Text='SDK, cache Web e pacchetti possono occupare diversi GB. Scegli una posizione persistente, separata dal repository.';$sub.SetBounds(26,62,620,42);$sub.ForeColor=[System.Drawing.Color]::FromArgb(174,187,207);$d.Controls.Add($sub)
  $defaultPath=Join-Path $DataRoot 'flutter-sdk\flutter'
  $r1=New-Object System.Windows.Forms.RadioButton;$r1.Text=('Cartella utente (consigliata)'+[Environment]::NewLine+$defaultPath);$r1.SetBounds(30,120,610,48);$r1.Checked=(-not (Has-Flutter ([string]$S.FlutterRoot)));$d.Controls.Add($r1)
  $r2=New-Object System.Windows.Forms.RadioButton;$r2.Text='Usa una cartella diversa per SDK e cache (disco secondario / esterno)';$r2.SetBounds(30,184,610,26);$d.Controls.Add($r2)
  $path=New-Object System.Windows.Forms.TextBox;$path.Text=[string]$S.FlutterRoot;$path.SetBounds(50,216,485,29);$path.Enabled=$false;$path.BackColor=[System.Drawing.Color]::FromArgb(30,40,57);$path.ForeColor=$d.ForeColor;$d.Controls.Add($path)
  $browse=New-Object System.Windows.Forms.Button;$browse.Text='Sfoglia...';$browse.SetBounds(545,214,100,31);$browse.Enabled=$false;$d.Controls.Add($browse)
  $r3=New-Object System.Windows.Forms.RadioButton;$r3.Text='Riutilizza uno SDK Flutter gia installato (cartella con bin\flutter.bat)';$r3.SetBounds(30,260,610,38);$r3.Checked=(Has-Flutter ([string]$S.FlutterRoot));$d.Controls.Add($r3)
  $r2.Add_CheckedChanged({$path.Enabled=($r2.Checked -or $r3.Checked);$browse.Enabled=($r2.Checked -or $r3.Checked);if($r2.Checked){$path.Text=''}}.GetNewClosure())
  $r3.Add_CheckedChanged({$path.Enabled=($r2.Checked -or $r3.Checked);$browse.Enabled=($r2.Checked -or $r3.Checked);if($r3.Checked){$path.Text=[string]$S.FlutterRoot}}.GetNewClosure())
  $browse.Add_Click({$f=New-Object System.Windows.Forms.FolderBrowserDialog;$f.Description=if($r3.Checked){'Seleziona la cartella Flutter che contiene bin\flutter.bat'}else{'Seleziona dove creare la sottocartella flutter'};$f.ShowNewFolderButton=$r2.Checked;if($f.ShowDialog($d) -eq 'OK'){if($r2.Checked){$path.Text=Join-Path $f.SelectedPath 'flutter'}else{$path.Text=$f.SelectedPath}}}.GetNewClosure())
  $note=New-Object System.Windows.Forms.Label;$note.Text='La scelta viene salvata fuori dal repository. Se riscarichi il codice, il runtime resta al suo posto.';$note.SetBounds(30,310,610,34);$note.ForeColor=[System.Drawing.Color]::FromArgb(120,205,170);$d.Controls.Add($note)
  $ok=New-Object System.Windows.Forms.Button;$ok.Text='Salva posizione';$ok.SetBounds(390,350,140,34);$ok.DialogResult='OK';$ok.BackColor=[System.Drawing.Color]::FromArgb(47,112,219);$ok.ForeColor=[System.Drawing.Color]::White;$ok.FlatStyle='Flat'
  $cancel=New-Object System.Windows.Forms.Button;$cancel.Text='Annulla';$cancel.SetBounds(540,350,100,34);$cancel.DialogResult='Cancel';$d.Controls.AddRange(@($ok,$cancel));$d.AcceptButton=$ok;$d.CancelButton=$cancel
  if($d.ShowDialog() -ne 'OK'){return $false}
  if($r1.Checked){$S.FlutterRoot=$defaultPath}
  elseif($r2.Checked){if(-not $path.Text.Trim()){[System.Windows.Forms.MessageBox]::Show('Seleziona una cartella.','Padel Community')|Out-Null;return $false};$S.FlutterRoot=[System.IO.Path]::GetFullPath($path.Text.Trim())}
  elseif($r3.Checked){if(-not (Has-Flutter $path.Text.Trim())){[System.Windows.Forms.MessageBox]::Show('La cartella non contiene bin\flutter.bat.','Percorso non valido')|Out-Null;return $false};$S.FlutterRoot=[System.IO.Path]::GetFullPath($path.Text.Trim())}
  Save-Settings;return $true
}
$form=New-Object System.Windows.Forms.Form;$form.Text='Padel Community | Launcher';$form.Size=New-Object System.Drawing.Size(940,700);$form.MinimumSize=New-Object System.Drawing.Size(820,620);$form.StartPosition='CenterScreen';$form.Font=New-Object System.Drawing.Font('Segoe UI',10)
$navy=[System.Drawing.Color]::FromArgb(18,25,38);$panel=[System.Drawing.Color]::FromArgb(28,38,55);$ink=[System.Drawing.Color]::FromArgb(235,240,248);$muted=[System.Drawing.Color]::FromArgb(166,181,202);$blue=[System.Drawing.Color]::FromArgb(47,112,219);$green=[System.Drawing.Color]::FromArgb(53,170,126)
$form.BackColor=$navy;$form.ForeColor=$ink
$header=New-Object System.Windows.Forms.Panel;$header.SetBounds(0,0,900,116);$header.Anchor='Top,Left,Right';$header.BackColor=$panel
$logo=New-Object System.Windows.Forms.Label;$logo.Text='PADEL';$logo.Font=New-Object System.Drawing.Font('Segoe UI Black',24);$logo.ForeColor=$ink;$logo.SetBounds(26,16,230,42)
$tag=New-Object System.Windows.Forms.Label;$tag.Text='COMMUNITY  /  LOCAL DEVELOPMENT';$tag.ForeColor=$muted;$tag.SetBounds(30,63,400,22)
$ver=New-Object System.Windows.Forms.Label;$ver.Text='PORTABLE TOOLCHAIN';$ver.TextAlign='MiddleRight';$ver.ForeColor=$green;$ver.SetBounds(650,34,250,28);$header.Controls.AddRange(@($logo,$tag,$ver));$form.Controls.Add($header)
$storage=New-Object System.Windows.Forms.Panel;$storage.SetBounds(24,132,876,72);$storage.Anchor='Top,Left,Right';$storage.BackColor=$panel
$stitle=New-Object System.Windows.Forms.Label;$stitle.Text='RUNTIME LOCATION';$stitle.Font=New-Object System.Drawing.Font('Segoe UI Semibold',9);$stitle.ForeColor=$muted;$stitle.SetBounds(14,8,200,20)
$spath=New-Object System.Windows.Forms.Label;$spath.Text=[string]$S.FlutterRoot;$spath.AutoEllipsis=$true;$spath.SetBounds(14,31,700,26)
$change=New-Object System.Windows.Forms.Button;$change.Text='Cambia...';$change.SetBounds(744,18,115,34);$change.Anchor='Top,Right';$change.FlatStyle='Flat';$change.BackColor=$navy;$change.ForeColor=$ink;$storage.Controls.AddRange(@($stitle,$spath,$change));$form.Controls.Add($storage)
$statusPanel=New-Object System.Windows.Forms.Panel;$statusPanel.SetBounds(24,218,876,74);$statusPanel.Anchor='Top,Left,Right';$statusPanel.BackColor=$panel
$statusTitle=New-Object System.Windows.Forms.Label;$statusTitle.Text='STATO';$statusTitle.ForeColor=$muted;$statusTitle.SetBounds(14,8,90,20)
$statusText=New-Object System.Windows.Forms.Label;$statusText.Text='Pronto. Il runtime verra controllato al primo avvio.';$statusText.SetBounds(14,34,820,25);$statusText.AutoEllipsis=$true;$statusPanel.Controls.AddRange(@($statusTitle,$statusText));$form.Controls.Add($statusPanel)
$script:ButtonList=@()
$script:SessionStartButtons=@{}
$script:SessionStopButtons=@{}
$buttons=New-Object System.Windows.Forms.FlowLayoutPanel
$buttons.SetBounds(24,306,876,48);$buttons.Anchor='Top,Left,Right';$buttons.BackColor=$navy;$buttons.WrapContents=$false
function Add-SessionButton([string]$label,[string]$sessionId,[string]$kind,[bool]$primary=$false){
  $b=New-Object System.Windows.Forms.Button
  $b.Text=$label;$b.Size=New-Object System.Drawing.Size(164,40);$b.Margin='0,0,10,4';$b.FlatStyle='Flat';$b.FlatAppearance.BorderSize=0
  if($primary){$b.BackColor=$blue;$b.ForeColor=[System.Drawing.Color]::White}else{$b.BackColor=$panel;$b.ForeColor=$ink}
  if($kind -eq 'start'){
    $b.Add_Click({Start-Session $sessionId}.GetNewClosure())
    $script:SessionStartButtons[$sessionId]=$b
  }else{
    $b.Enabled=$false
    $b.Add_Click({Stop-Session $sessionId}.GetNewClosure())
    $script:SessionStopButtons[$sessionId]=$b
  }
  $buttons.Controls.Add($b)
}
Add-SessionButton '▶ Start sessione 1' '1' 'start' $true
Add-SessionButton '■ Stop 1' '1' 'stop'
Add-SessionButton '▶ Start sessione 2' '2' 'start' $true
Add-SessionButton '■ Stop 2' '2' 'stop'
$form.Controls.Add($buttons)

$secondaryButtons=New-Object System.Windows.Forms.FlowLayoutPanel
$secondaryButtons.SetBounds(24,360,876,48);$secondaryButtons.Anchor='Top,Left,Right';$secondaryButtons.BackColor=$navy;$secondaryButtons.WrapContents=$false
$advancedButtons=New-Object System.Windows.Forms.FlowLayoutPanel
$advancedButtons.SetBounds(24,414,876,48);$advancedButtons.Anchor='Top,Left,Right';$advancedButtons.BackColor=$navy;$advancedButtons.WrapContents=$true;$advancedButtons.Visible=$false
function Add-ActionButton([string]$label,[string]$action,[System.Windows.Forms.Control]$targetPanel,[bool]$primary=$false){
  $b=New-Object System.Windows.Forms.Button;$b.Text=$label;$b.Tag=$action;$b.Size=New-Object System.Drawing.Size(164,40);$b.Margin='0,0,10,4';$b.FlatStyle='Flat';$b.FlatAppearance.BorderSize=0
  if($primary){$b.BackColor=$blue;$b.ForeColor=[System.Drawing.Color]::White}else{$b.BackColor=$panel;$b.ForeColor=$ink}
  $actionName=$action;$b.Add_Click({Invoke-Action $actionName}.GetNewClosure());$targetPanel.Controls.Add($b);$script:ButtonList+=$b
}
Add-ActionButton 'Prepara ambiente' 'setup' $secondaryButtons
Add-ActionButton 'Diagnostica' 'doctor' $secondaryButtons
$advancedToggle=New-Object System.Windows.Forms.Button
$advancedToggle.Text='Strumenti avanzati ▸';$advancedToggle.Size=New-Object System.Drawing.Size(164,40);$advancedToggle.Margin='0,0,10,4';$advancedToggle.FlatStyle='Flat';$advancedToggle.FlatAppearance.BorderSize=0;$advancedToggle.BackColor=$panel;$advancedToggle.ForeColor=$muted
$secondaryButtons.Controls.Add($advancedToggle)
Add-ActionButton 'Verifica tutto' 'check' $advancedButtons
Add-ActionButton 'Build Web' 'build' $advancedButtons
Add-ActionButton 'Analisi codice' 'analyze' $advancedButtons
Add-ActionButton 'Test' 'test' $advancedButtons
Add-ActionButton 'Formatta codice' 'format' $advancedButtons
$form.Controls.Add($secondaryButtons);$form.Controls.Add($advancedButtons)
$bottom=New-Object System.Windows.Forms.FlowLayoutPanel;$bottom.Dock='Bottom';$bottom.Height=44;$bottom.Padding='18,5,10,5';$bottom.BackColor=$panel
function Add-LinkButton($label,$handler){$b=New-Object System.Windows.Forms.Button;$b.Text=$label;$b.AutoSize=$true;$b.FlatStyle='Flat';$b.BackColor=$panel;$b.ForeColor=$muted;$b.Add_Click($handler);$bottom.Controls.Add($b)}
Add-LinkButton 'Apri cartella runtime' { $p=Split-Path ([string]$S.FlutterRoot) -Parent;if(-not(Test-Path $p)){New-Item -ItemType Directory -Force -Path $p|Out-Null};Start-Process explorer.exe $p }
Add-LinkButton 'Apri log' { if(Test-Path $LogFile){Start-Process notepad.exe $LogFile}else{[System.Windows.Forms.MessageBox]::Show('Nessun log creato ancora.','Padel Community')|Out-Null} }
Add-LinkButton 'Apri repository' { Start-Process explorer.exe $Root };$form.Controls.Add($bottom)
$logbox=New-Object System.Windows.Forms.RichTextBox;$logbox.SetBounds(24,420,876,214);$logbox.Anchor='Top,Bottom,Left,Right';$logbox.ReadOnly=$true;$logbox.BackColor=[System.Drawing.Color]::FromArgb(10,15,24);$logbox.ForeColor=$ink;$logbox.Font=New-Object System.Drawing.Font('Consolas',9);$logbox.BorderStyle='FixedSingle';$form.Controls.Add($logbox)
$advancedToggle.Add_Click({
  $advancedButtons.Visible=-not $advancedButtons.Visible
  if($advancedButtons.Visible){
    $advancedToggle.Text='Nascondi strumenti'
    $logbox.SetBounds(24,468,876,166)
  }else{
    $advancedToggle.Text='Strumenti avanzati ▸'
    $logbox.SetBounds(24,420,876,214)
  }
}.GetNewClosure())
$footer=New-Object System.Windows.Forms.Label;$footer.Text='Runtime e log restano fuori dalla cartella Git.';$footer.ForeColor=$muted;$footer.SetBounds(26,640,700,20);$footer.Anchor='Bottom,Left';$form.Controls.Add($footer)
$script:Proc=$null;$script:Positions=@{};$script:Sessions=@{}
foreach($f in @($LogFile,$OutFile,$ErrFile)){$script:Positions[$f]=0}
foreach($id in @('1','2')){
  $sessionData=Join-Path $DataRoot ("sessions\session-{0}" -f $id)
  $script:Sessions[$id]=@{
    Id=$id
    Proc=$null
    Port=0
    Workspace=(Join-Path $sessionData 'workspace')
    OutFile=(Join-Path $sessionData 'session.stdout.log')
    ErrFile=(Join-Path $sessionData 'session.stderr.log')
    LogFile=(Join-Path $sessionData 'flutter.log')
    Positions=@{}
  }
  foreach($file in @($script:Sessions[$id].OutFile,$script:Sessions[$id].ErrFile,$script:Sessions[$id].LogFile)){
    $script:Sessions[$id].Positions[$file]=0
  }
}
function Add-PanelLog([string]$line){
 if(-not $line.Trim()){return}
 $c=$ink
 if($line -match 'ERRORE|ERROR|Exception|failed|non riuscito'){$c=[System.Drawing.Color]::FromArgb(255,126,126)}
 elseif($line -match 'OK|completato|ready|Pronto'){$c=[System.Drawing.Color]::FromArgb(103,218,166)}
 $logbox.SelectionStart=$logbox.TextLength;$logbox.SelectionLength=0;$logbox.SelectionColor=$c;$logbox.AppendText($line+[Environment]::NewLine);$logbox.SelectionStart=$logbox.TextLength;$logbox.ScrollToCaret()
}
function Read-NewLines([string]$file,[string]$prefix,[hashtable]$positionStore){
 if(-not(Test-Path $file)){return}
 try{
  if(-not $positionStore.ContainsKey($file)){$positionStore[$file]=0}
  $fs=[System.IO.File]::Open($file,[System.IO.FileMode]::Open,[System.IO.FileAccess]::Read,[System.IO.FileShare]::ReadWrite)
  $pos=[long]$positionStore[$file]
  if($fs.Length -lt $pos){$pos=0}
  $fs.Seek($pos,[System.IO.SeekOrigin]::Begin)|Out-Null
  $sr=New-Object System.IO.StreamReader($fs);$new=$sr.ReadToEnd();$positionStore[$file]=$fs.Position;$sr.Close();$fs.Close()
  foreach($line in ($new -split '\r?\n')){if($line.Trim()){Add-PanelLog ($prefix+$line)}}
 }catch{}
}
function Refresh-Log{
 Read-NewLines $OutFile '[output] ' $script:Positions
 Read-NewLines $ErrFile '[stderr] ' $script:Positions
 if($script:Proc -and $script:Proc.HasExited){
  $script:Proc.WaitForExit();$code=$script:Proc.ExitCode;$script:Proc=$null;if($null -eq $code){$code=0}
  foreach($b in $script:ButtonList){$b.Enabled=$true}
  if($code -eq 0){$statusText.Text='Operazione completata.';Add-PanelLog '[panel] Operazione completata.'}
  else{$statusText.Text="Operazione terminata con errore (codice $code). Apri il log per i dettagli.";Add-PanelLog "[panel] ERRORE: exit code $code"}
 }
 foreach($id in @('1','2')){
  $session=$script:Sessions[$id]
  Read-NewLines $session.OutFile ("[sessione {0}] " -f $id) $session.Positions
  Read-NewLines $session.ErrFile ("[sessione {0} stderr] " -f $id) $session.Positions
  if($session.Proc -and $session.Proc.HasExited){
    $session.Proc.WaitForExit()
    $code=$session.Proc.ExitCode
    $session.Proc=$null
    $script:SessionStartButtons[$id].Enabled=$true
    $script:SessionStopButtons[$id].Enabled=$false
    if($code -eq 0){
      $statusText.Text=("Sessione {0} terminata." -f $id)
      Add-PanelLog ("[panel] Sessione {0} terminata." -f $id)
    }else{
      $statusText.Text=("Sessione {0} terminata con errore (codice {1})." -f $id,$code)
      Add-PanelLog ("[panel] ERRORE sessione {0}: exit code {1}" -f $id,$code)
    }
  }
 }
}
$timer=New-Object System.Windows.Forms.Timer;$timer.Interval=700;$timer.Add_Tick({Refresh-Log});$timer.Start()
function Invoke-Action([string]$action){
 if($script:Proc -and -not $script:Proc.HasExited){return}
 if(-not(Test-Path $SettingsFile)){if(-not(Show-StorageWizard)){return}}
 $spath.Text=[string]$S.FlutterRoot
 if(Has-Flutter ([string]$S.FlutterRoot)){$statusText.Text='Flutter gia presente: riutilizzo SDK e cache.'}else{$statusText.Text='Flutter non trovato: download nella posizione scelta. Puo richiedere diversi GB.'}
 foreach($b in $script:ButtonList){$b.Enabled=$false};$advancedToggle.Enabled=$false
 Add-PanelLog ("[panel] Avvio operazione: "+$action)
 try{
  Remove-Item $OutFile,$ErrFile -Force -ErrorAction SilentlyContinue
  $script:Positions[$OutFile]=0;$script:Positions[$ErrFile]=0
  $argList=@('-NoProfile','-ExecutionPolicy','Bypass','-File',('"{0}"' -f $Launcher),'-Action',$action)
  $script:Proc=Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -WorkingDirectory $Root -WindowStyle Hidden -PassThru -RedirectStandardOutput $OutFile -RedirectStandardError $ErrFile
  $null=$script:Proc.Handle
 }catch{
  foreach($b in $script:ButtonList){$b.Enabled=$true};$advancedToggle.Enabled=$true
  $statusText.Text='Impossibile avviare il processo.'
  Add-PanelLog ("ERRORE: "+$_.Exception.Message)
 }
}

function Find-SessionPort{
  $first=7357;$last=7399;$count=$last-$first+1;$seed=Get-Random -Minimum $first -Maximum ($last+1)
  for($offset=0;$offset -lt $count;$offset++){
    $candidate=$first+(($seed-$first+$offset)%$count)
    $listener=$null
    try{
      $listener=[System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback,$candidate)
      $listener.Start()
      return $candidate
    }catch{}finally{if($listener){try{$listener.Stop()}catch{}}}
  }
  throw 'Nessuna porta libera disponibile tra 7357 e 7399.'
}
function Sync-SessionWorkspace([hashtable]$session){
  New-Item -ItemType Directory -Force -Path (Split-Path $session.Workspace -Parent),$session.Workspace | Out-Null
  $robocopy=Join-Path $env:SystemRoot 'System32\robocopy.exe'
  $args=@(
    $Root,$session.Workspace,'/MIR','/R:1','/W:1','/NFL','/NDL','/NJH','/NJS','/NP',
    '/XD','.git','.dart_tool','build','.idea','.vscode','runtime','logs'
  )
  & $robocopy @args | Out-Null
  $code=$LASTEXITCODE
  if($code -ge 8){throw "Impossibile preparare la copia di lavoro della sessione $($session.Id) (robocopy $code)."}
  Add-PanelLog ("[panel] Copia isolata aggiornata: sessione {0}" -f $session.Id)
}
function Start-Session([string]$id){
  $session=$script:Sessions[$id]
  if($session.Proc -and -not $session.Proc.HasExited){return}
  if(-not(Test-Path $SettingsFile)){if(-not(Show-StorageWizard)){return}}
  try{
    $script:SessionStartButtons[$id].Enabled=$false
    $script:SessionStopButtons[$id].Enabled=$false
    $statusText.Text=("Preparazione sessione {0}..." -f $id)
    Add-PanelLog ("[panel] Preparo sessione {0}..." -f $id)
    Sync-SessionWorkspace $session

    Remove-Item $session.OutFile,$session.ErrFile,$session.LogFile -Force -ErrorAction SilentlyContinue
    foreach($file in @($session.OutFile,$session.ErrFile,$session.LogFile)){$session.Positions[$file]=0}
    $port=Find-SessionPort
    $launcherArgs=@(
      '-NoProfile','-ExecutionPolicy','Bypass',
      '-File',('"{0}"' -f $Launcher),
      '-Action','web',
      '-ProjectRoot',('"{0}"' -f $session.Workspace),
      '-RequestedPort',"$port",
      '-LogPath',('"{0}"' -f $session.LogFile)
    )
    $session.Proc=Start-Process -FilePath 'powershell.exe' -ArgumentList $launcherArgs -WorkingDirectory $session.Workspace -WindowStyle Hidden -PassThru -RedirectStandardOutput $session.OutFile -RedirectStandardError $session.ErrFile
    $null=$session.Proc.Handle
    $session.Port=$port
    $script:SessionStartButtons[$id].Enabled=$false
    $script:SessionStopButtons[$id].Enabled=$true
    $statusText.Text=("Sessione {0} in avvio su http://127.0.0.1:{1}" -f $id,$port)
    Add-PanelLog ("[panel] Sessione {0} partita sulla porta {1}." -f $id,$port)
  }catch{
    $session.Proc=$null
    $script:SessionStartButtons[$id].Enabled=$true
    $script:SessionStopButtons[$id].Enabled=$false
    $statusText.Text=("Avvio sessione {0} non riuscito." -f $id)
    Add-PanelLog ("[panel] ERRORE sessione {0}: {1}" -f $id,$_.Exception.Message)
  }
}
function Stop-Session([string]$id){
  $session=$script:Sessions[$id]
  if(-not $session.Proc -or $session.Proc.HasExited){
    $session.Proc=$null
    $script:SessionStartButtons[$id].Enabled=$true
    $script:SessionStopButtons[$id].Enabled=$false
    return
  }
  Add-PanelLog ("[panel] Arresto sessione {0} sulla porta {1}..." -f $id,$session.Port)
  try{
    $taskkill=Join-Path $env:SystemRoot 'System32\taskkill.exe'
    & $taskkill /PID $session.Proc.Id /T /F | Out-Null
    $null=$session.Proc.WaitForExit(5000)
    Read-NewLines $session.OutFile ("[sessione {0}] " -f $id) $session.Positions
    Read-NewLines $session.ErrFile ("[sessione {0} stderr] " -f $id) $session.Positions
    $session.Proc=$null
    $script:SessionStartButtons[$id].Enabled=$true
    $script:SessionStopButtons[$id].Enabled=$false
    $statusText.Text=("Sessione {0} arrestata." -f $id)
    Add-PanelLog ("[panel] Sessione {0} arrestata." -f $id)
  }catch{
    $statusText.Text=("Errore arrestando sessione {0}." -f $id)
    Add-PanelLog ("[panel] ERRORE stop sessione {0}: {1}" -f $id,$_.Exception.Message)
  }
}
$change.Add_Click({if(Show-StorageWizard){$spath.Text=[string]$S.FlutterRoot;$statusText.Text='Posizione salvata. Il prossimo avvio usera questo percorso.'}})
$form.Add_Shown({if(-not(Test-Path $SettingsFile)){if(Show-StorageWizard){$spath.Text=[string]$S.FlutterRoot}};if(Test-Path $LogFile){Add-PanelLog 'Log precedente disponibile. Le nuove righe appariranno qui.'}})
$form.Add_FormClosing({
  foreach($id in @('1','2')){Stop-Session $id}
  if($script:Proc -and -not $script:Proc.HasExited){
    try{
      $taskkill=Join-Path $env:SystemRoot 'System32\taskkill.exe'
      & $taskkill /PID $script:Proc.Id /T /F | Out-Null
      $null=$script:Proc.WaitForExit(3000)
    }catch{}
  }
})
[void]$form.ShowDialog()
