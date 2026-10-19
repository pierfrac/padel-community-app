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
  $r3=New-Object System.Windows.Forms.RadioButton;$r3.Text='Riutilizza uno SDK Flutter già installato (cartella con bin\flutter.bat)';$r3.SetBounds(30,260,610,38);$r3.Checked=(Has-Flutter ([string]$S.FlutterRoot));$d.Controls.Add($r3)
  $r2.Add_CheckedChanged({$path.Enabled=($r2.Checked -or $r3.Checked);$browse.Enabled=($r2.Checked -or $r3.Checked)})
  $r3.Add_CheckedChanged({$path.Enabled=($r2.Checked -or $r3.Checked);$browse.Enabled=($r2.Checked -or $r3.Checked)})
  $browse.Add_Click({$f=New-Object System.Windows.Forms.FolderBrowserDialog;$f.Description=if($r3.Checked){'Seleziona la cartella Flutter che contiene bin\flutter.bat'}else{'Seleziona dove creare la sottocartella flutter'};$f.ShowNewFolderButton=$r2.Checked;if($f.ShowDialog($d) -eq 'OK'){if($r2.Checked){$path.Text=Join-Path $f.SelectedPath 'flutter'}else{$path.Text=$f.SelectedPath}}})
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
$header=New-Object System.Windows.Forms.Panel;$header.Dock='Top';$header.Height=116;$header.BackColor=$panel
$logo=New-Object System.Windows.Forms.Label;$logo.Text='PADEL';$logo.Font=New-Object System.Drawing.Font('Segoe UI Black',24);$logo.ForeColor=$ink;$logo.SetBounds(26,16,230,42)
$tag=New-Object System.Windows.Forms.Label;$tag.Text='COMMUNITY  /  LOCAL DEVELOPMENT';$tag.ForeColor=$muted;$tag.SetBounds(30,63,400,22)
$ver=New-Object System.Windows.Forms.Label;$ver.Text='PORTABLE TOOLCHAIN';$ver.TextAlign='MiddleRight';$ver.ForeColor=$green;$ver.SetBounds(650,34,250,28);$header.Controls.AddRange(@($logo,$tag,$ver));$form.Controls.Add($header)
$storage=New-Object System.Windows.Forms.Panel;$storage.SetBounds(24,132,876,72);$storage.Anchor='Top,Left,Right';$storage.BackColor=$panel
$stitle=New-Object System.Windows.Forms.Label;$stitle.Text='RUNTIME LOCATION';$stitle.Font=New-Object System.Drawing.Font('Segoe UI Semibold',9);$stitle.ForeColor=$muted;$stitle.SetBounds(14,8,200,20)
$spath=New-Object System.Windows.Forms.Label;$spath.Text=[string]$S.FlutterRoot;$spath.AutoEllipsis=$true;$spath.SetBounds(14,31,700,26)
$change=New-Object System.Windows.Forms.Button;$change.Text='Cambia...';$change.SetBounds(744,18,115,34);$change.Anchor='Top,Right';$change.FlatStyle='Flat';$change.BackColor=$navy;$change.ForeColor=$ink;$storage.Controls.AddRange(@($stitle,$spath,$change));$form.Controls.Add($storage)
$statusPanel=New-Object System.Windows.Forms.Panel;$statusPanel.SetBounds(24,218,876,74);$statusPanel.Anchor='Top,Left,Right';$statusPanel.BackColor=$panel
$statusTitle=New-Object System.Windows.Forms.Label;$statusTitle.Text='STATO';$statusTitle.ForeColor=$muted;$statusTitle.SetBounds(14,8,90,20)
$statusText=New-Object System.Windows.Forms.Label;$statusText.Text='Pronto. Il runtime verrà controllato al primo avvio.';$statusText.SetBounds(14,34,820,25);$statusText.AutoEllipsis=$true;$statusPanel.Controls.AddRange(@($statusTitle,$statusText));$form.Controls.Add($statusPanel)
$buttons=New-Object System.Windows.Forms.FlowLayoutPanel;$buttons.SetBounds(24,306,876,100);$buttons.Anchor='Top,Left,Right';$buttons.BackColor=$navy;$buttons.WrapContents=$true;$script:ButtonList=@()
function Add-ActionButton([string]$label,[string]$action,[bool]$primary=$false){
  $b=New-Object System.Windows.Forms.Button;$b.Text=$label;$b.Tag=$action;$b.Size=New-Object System.Drawing.Size(164,40);$b.Margin='0,0,10,10';$b.FlatStyle='Flat';$b.FlatAppearance.BorderSize=0
  if($primary){$b.BackColor=$blue;$b.ForeColor=[System.Drawing.Color]::White}else{$b.BackColor=$panel;$b.ForeColor=$ink}
  $actionName=$action;$b.Add_Click({Invoke-Action $actionName}.GetNewClosure());$buttons.Controls.Add($b);$script:ButtonList+=$b
}
Add-ActionButton '▶  Avvia anteprima' 'web' $true;Add-ActionButton 'Prepara ambiente' 'setup';Add-ActionButton 'Verifica tutto' 'check';Add-ActionButton 'Build Web' 'build';Add-ActionButton 'Analisi codice' 'analyze';Add-ActionButton 'Test' 'test';Add-ActionButton 'Formatta codice' 'format';Add-ActionButton 'Diagnostica' 'doctor'
$bottom=New-Object System.Windows.Forms.FlowLayoutPanel;$bottom.Dock='Bottom';$bottom.Height=44;$bottom.Padding='18,5,10,5';$bottom.BackColor=$panel
function Add-LinkButton($label,$handler){$b=New-Object System.Windows.Forms.Button;$b.Text=$label;$b.AutoSize=$true;$b.FlatStyle='Flat';$b.BackColor=$panel;$b.ForeColor=$muted;$b.Add_Click($handler);$bottom.Controls.Add($b)}
Add-LinkButton 'Apri cartella runtime' { $p=Split-Path ([string]$S.FlutterRoot) -Parent;if(-not(Test-Path $p)){New-Item -ItemType Directory -Force -Path $p|Out-Null};Start-Process explorer.exe $p }
Add-LinkButton 'Apri log' { if(Test-Path $LogFile){Start-Process notepad.exe $LogFile}else{[System.Windows.Forms.MessageBox]::Show('Nessun log creato ancora.','Padel Community')|Out-Null} }
Add-LinkButton 'Apri repository' { Start-Process explorer.exe $Root };$form.Controls.Add($bottom)
$logbox=New-Object System.Windows.Forms.RichTextBox;$logbox.SetBounds(24,416,876,218);$logbox.Anchor='Top,Bottom,Left,Right';$logbox.ReadOnly=$true;$logbox.BackColor=[System.Drawing.Color]::FromArgb(10,15,24);$logbox.ForeColor=$ink;$logbox.Font=New-Object System.Drawing.Font('Consolas',9);$logbox.BorderStyle='FixedSingle';$form.Controls.Add($logbox)
$footer=New-Object System.Windows.Forms.Label;$footer.Text='Runtime e log restano fuori dalla cartella Git.';$footer.ForeColor=$muted;$footer.SetBounds(26,640,700,20);$footer.Anchor='Bottom,Left';$form.Controls.Add($footer)
$script:Proc=$null;$script:LogPos=0
function Add-PanelLog([string]$line){if(-not $line.Trim()){return};$c=$ink;if($line -match 'ERRORE|ERROR|Exception|failed|non riuscito'){$c=[System.Drawing.Color]::FromArgb(255,126,126)}elseif($line -match 'OK|completato|ready|Pronto'){$c=[System.Drawing.Color]::FromArgb(103,218,166)};$logbox.SelectionStart=$logbox.TextLength;$logbox.SelectionLength=0;$logbox.SelectionColor=$c;$logbox.AppendText($line+[Environment]::NewLine);$logbox.SelectionStart=$logbox.TextLength;$logbox.ScrollToCaret()}
function Refresh-Log {
 if(Test-Path $LogFile){try{$fs=[System.IO.File]::Open($LogFile,[System.IO.FileMode]::Open,[System.IO.FileAccess]::Read,[System.IO.FileShare]::ReadWrite);if($fs.Length -lt $script:LogPos){$script:LogPos=0};$fs.Seek($script:LogPos,[System.IO.SeekOrigin]::Begin)|Out-Null;$sr=New-Object IO.StreamReader($fs);$new=$sr.ReadToEnd();$script:LogPos=$fs.Position;$sr.Close();$fs.Close();foreach($line in ($new -split '\r?\n')){Add-PanelLog $line}}catch{}}
 if($script:Proc -and $script:Proc.HasExited){$code=$script:Proc.ExitCode;$script:Proc=$null;foreach($b in $script:ButtonList){$b.Enabled=$true};if($code -eq 0){$statusText.Text='Operazione completata.';Add-PanelLog '[panel] Operazione completata.'}else{$statusText.Text="Operazione terminata con errore (codice $code). Apri il log per i dettagli.";Add-PanelLog "[panel] ERRORE: exit code $code"}}
}
$timer=New-Object System.Windows.Forms.Timer;$timer.Interval=700;$timer.Add_Tick({Refresh-Log});$timer.Start()
function Invoke-Action([string]$action){
 if($script:Proc -and -not $script:Proc.HasExited){return}
 if(-not(Test-Path $SettingsFile)){if(-not(Show-StorageWizard)){return}}
 $spath.Text=[string]$S.FlutterRoot
 if(Has-Flutter ([string]$S.FlutterRoot)){$statusText.Text='Flutter già presente: riutilizzo SDK e cache.'}else{$statusText.Text='Flutter non trovato: download nella posizione scelta. Può richiedere diversi GB.'}
 foreach($b in $script:ButtonList){$b.Enabled=$false};Add-PanelLog ("[panel] Avvio operazione: "+$action)
 try{$argList=@('-NoProfile','-ExecutionPolicy','Bypass','-File',('"{0}"' -f $Launcher),'-Action',$action);$script:Proc=Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -WorkingDirectory $Root -WindowStyle Hidden -PassThru -RedirectStandardOutput $OutFile -RedirectStandardError $ErrFile}
 catch{foreach($b in $script:ButtonList){$b.Enabled=$true};$statusText.Text='Impossibile avviare il processo.';Add-PanelLog ("ERRORE: "+$_.Exception.Message)}
}
$change.Add_Click({if(Show-StorageWizard){$spath.Text=[string]$S.FlutterRoot;$statusText.Text='Posizione salvata. Il prossimo avvio userà questo percorso.'}})
$form.Add_Shown({if(-not(Test-Path $SettingsFile)){if(Show-StorageWizard){$spath.Text=[string]$S.FlutterRoot}};if(Test-Path $LogFile){Add-PanelLog 'Log precedente disponibile. Le nuove righe appariranno qui.'}})
[void]$form.ShowDialog()
