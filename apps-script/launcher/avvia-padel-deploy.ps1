$ErrorActionPreference = "Stop"
$NodeVersion = "v22.16.0"
$NodeZipName = "node-$NodeVersion-win-x64.zip"
$NodeUrl = "https://nodejs.org/dist/$NodeVersion/$NodeZipName"
$LauncherDir = $PSScriptRoot
$AppDir = Split-Path -Parent $LauncherDir
$RuntimeDir = Join-Path $AppDir ".runtime"
$NodeHome = Join-Path $RuntimeDir "node-$NodeVersion-win-x64"
$NodeExe = Join-Path $NodeHome "node.exe"
$NpmCmd = Join-Path $NodeHome "npm.cmd"
$ClaspConfig = Join-Path $AppDir ".clasp.json"
$GitHubApi = "https://api.github.com"
$script:GitHubToken = ""

function Pause-Exit { Write-Host ""; Read-Host "Premi INVIO per chiudere" }

function Get-GitHubHeaders([string]$Token) {
  $headers = @{ "Accept"="application/vnd.github+json"; "X-GitHub-Api-Version"="2022-11-28"; "User-Agent"="Padel-Community-Launcher" }
  if (-not [string]::IsNullOrWhiteSpace($Token)) { $headers["Authorization"] = "Bearer $Token" }
  return $headers
}

function ConvertFrom-SecureToken {
  $secure = Read-Host "Token GitHub (PAT, non viene salvato)" -AsSecureString
  $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
  finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
}

function Connect-GitHub {
  Write-Host "Verifico l'accesso GitHub..."
  try {
    $null = Invoke-RestMethod -Method Get -Uri "$GitHubApi/user/repos?per_page=1" -Headers (Get-GitHubHeaders "")
    Write-Host "Connessione GitHub disponibile."
    return
  } catch {
    Write-Host "Accesso GitHub non autenticato: per elencare i repository serve un token."
  }
  $token = ConvertFrom-SecureToken
  if ([string]::IsNullOrWhiteSpace($token)) { throw "Token GitHub vuoto. Operazione annullata." }
  try {
    $user = Invoke-RestMethod -Method Get -Uri "$GitHubApi/user" -Headers (Get-GitHubHeaders $token)
    $null = Invoke-RestMethod -Method Get -Uri "$GitHubApi/user/repos?per_page=1" -Headers (Get-GitHubHeaders $token)
    $script:GitHubToken = $token
    Write-Host "Connesso a GitHub come $($user.login)."
  } catch {
    $script:GitHubToken = ""
    throw "Connessione GitHub non riuscita. Verifica token e permessi sui repository. Dettaglio: $($_.Exception.Message)"
  }
}

function Invoke-GitHubApi([string]$Uri) {
  return Invoke-RestMethod -Method Get -Uri $Uri -Headers (Get-GitHubHeaders $script:GitHubToken)
}

function Select-GitHubRepository {
  Write-Host "Carico i repository accessibili..."
  $all = @(); $page = 1
  do {
    $batch = @(Invoke-GitHubApi "$GitHubApi/user/repos?per_page=100&sort=updated&direction=desc&page=$page")
    $all += $batch; $page++
  } while ($batch.Count -eq 100)
  if ($all.Count -eq 0) { throw "Nessun repository trovato per l'account GitHub autenticato." }
  $sorted = @($all | Sort-Object full_name)
  for ($i=0; $i -lt $sorted.Count; $i++) {
    $visibility = if ($sorted[$i].private) { "privato" } else { "pubblico" }
    Write-Host ("  {0,3} - {1} [{2}]" -f ($i+1), $sorted[$i].full_name, $visibility)
  }
  while ($true) {
    $selection = Read-Host "Numero del repository da cui copiare i sorgenti (Q per annullare)"
    if ($selection -match '^[Qq]$') { throw "Selezione repository annullata." }
    $number=0
    if ([int]::TryParse($selection,[ref]$number) -and $number -ge 1 -and $number -le $sorted.Count) { return $sorted[$number-1] }
    Write-Host "Selezione non valida."
  }
}

function Select-GitHubBranch($Repository) {
  Write-Host "Carico i branch di $($Repository.full_name)..."
  $branches=@(); $page=1
  do {
    $batch = @(Invoke-GitHubApi "$GitHubApi/repos/$($Repository.owner.login)/$($Repository.name)/branches?per_page=100&page=$page")
    $branches += $batch; $page++
  } while ($batch.Count -eq 100)
  if ($branches.Count -eq 0) { throw "Nessun branch disponibile nel repository selezionato." }
  $branches = @($branches | Sort-Object name)
  for ($i=0; $i -lt $branches.Count; $i++) { Write-Host ("  {0,3} - {1}" -f ($i+1), $branches[$i].name) }
  while ($true) {
    $selection = Read-Host "Numero del branch da cui copiare i sorgenti (Q per annullare)"
    if ($selection -match '^[Qq]$') { throw "Selezione branch annullata." }
    $number=0
    if ([int]::TryParse($selection,[ref]$number) -and $number -ge 1 -and $number -le $branches.Count) { return $branches[$number-1].name }
    Write-Host "Selezione non valida."
  }
}

function Sync-BranchSources {
  Connect-GitHub
  $repository = Select-GitHubRepository
  $branch = Select-GitHubBranch $repository
  $files = @("Code.gs","Index.html","appsscript.json",".claspignore")
  Write-Host ""
  Write-Host "Repository: $($repository.full_name)"
  Write-Host "Branch: $branch"
  Write-Host "Scarico e verifico tutti i file prima di sostituire i sorgenti locali..."
  $stage = Join-Path $RuntimeDir ("source-stage-" + [Guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Force -Path $stage | Out-Null
  try {
    foreach ($name in $files) {
      $encodedBranch = [Uri]::EscapeDataString($branch)
      $uri = "$GitHubApi/repos/$($repository.owner.login)/$($repository.name)/contents/apps-script/$name" + "?ref=" + $encodedBranch
      $item = Invoke-GitHubApi $uri
      if ($item.type -ne "file" -or -not $item.download_url) { throw "Il percorso apps-script/$name non esiste come file nel branch '$branch'." }
      $destination = Join-Path $stage $name
      Invoke-WebRequest -Uri $item.download_url -OutFile $destination -Headers (Get-GitHubHeaders $script:GitHubToken)
      if (-not (Test-Path $destination) -or (Get-Item $destination).Length -eq 0) { throw "Download vuoto o fallito per $name." }
      Write-Host "  Verificato: $name"
    }
    foreach ($name in $files) { Copy-Item -LiteralPath (Join-Path $stage $name) -Destination (Join-Path $AppDir $name) -Force }
    Write-Host "Sorgenti sincronizzati. .clasp.json e .runtime restano intatti."
  } finally {
    if (Test-Path $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
    $script:GitHubToken = ""
  }
}

try {
  Write-Host "Padel Community - deploy helper"
  Write-Host "Node.js portable: $NodeVersion"
  if (-not (Test-Path $NodeExe)) {
    New-Item -ItemType Directory -Force -Path $RuntimeDir | Out-Null
    $ZipPath = Join-Path $RuntimeDir $NodeZipName
    Write-Host "Scarico Node.js portable dal sito ufficiale..."
    Invoke-WebRequest -Uri $NodeUrl -OutFile $ZipPath
    Expand-Archive -LiteralPath $ZipPath -DestinationPath $RuntimeDir -Force
    Remove-Item -LiteralPath $ZipPath -Force
  }
  if (-not (Test-Path $NodeExe) -or -not (Test-Path $NpmCmd)) { throw "Runtime Node.js incompleto. Elimina apps-script\.runtime e riavvia il launcher." }
  $env:PATH = "$NodeHome;$env:PATH"
  Write-Host "Node: $(& $NodeExe --version)"
  if (-not (Test-Path $ClaspConfig)) {
    Write-Host "Manca apps-script\.clasp.json."
    Write-Host "Copia .clasp.json.example in .clasp.json e inserisci il tuo Script ID."
    Write-Host "Non condividere né committare il file .clasp.json reale."
    Pause-Exit; exit 1
  }
  Write-Host "Scegli un'operazione:"
  Write-Host "  1 - Login Google (prima configurazione)"
  Write-Host "  2 - Seleziona repository/branch GitHub e carica su Apps Script"
  Write-Host "  3 - Verifica versione Node/npm"
  Write-Host "  Q - Esci"
  $Choice = Read-Host "Operazione"
  switch ($Choice.ToUpperInvariant()) {
    "1" { & $NpmCmd exec --yes --package=@google/clasp -- clasp login; if ($LASTEXITCODE -ne 0) { throw "Login clasp non riuscito." } }
    "2" {
      Write-Host "I sorgenti locali Code.gs, Index.html, appsscript.json e .claspignore verranno sostituiti."
      Write-Host "La configurazione .clasp.json e il runtime portable non verranno toccati."
      Write-Host "Il push non pubblica una nuova versione /exec e non configura i permessi Google."
      $Confirm = Read-Host "Per continuare scrivi PUSH"
      if ($Confirm -cne "PUSH") { Write-Host "Operazione annullata."; Pause-Exit; exit 0 }
      Sync-BranchSources
      & $NpmCmd exec --yes --package=@google/clasp -- clasp push
      if ($LASTEXITCODE -ne 0) { throw "clasp push non riuscito." }
    }
    "3" { & $NodeExe --version; & $NpmCmd --version }
    "Q" { exit 0 }
    default { Write-Host "Scelta non valida."; Pause-Exit; exit 1 }
  }
  Write-Host "Operazione terminata. Verifica sempre l'esito riportato sopra."
  Pause-Exit
} catch {
  Write-Host ""
  Write-Host "ERRORE: $($_.Exception.Message)" -ForegroundColor Red
  Pause-Exit
  exit 1
}
