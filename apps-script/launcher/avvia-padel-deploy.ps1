$ErrorActionPreference = "Stop"

# Portable runtime only: no system-wide Node.js installation.
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

function Pause-Exit {
  Write-Host ""
  Read-Host "Premi INVIO per chiudere"
}

try {
  Write-Host "Padel Community - deploy helper"
  Write-Host "Node.js portable: $NodeVersion"
  Write-Host ""

  if (-not (Test-Path $NodeExe)) {
    New-Item -ItemType Directory -Force -Path $RuntimeDir | Out-Null
    $ZipPath = Join-Path $RuntimeDir $NodeZipName
    Write-Host "Scarico Node.js portable dal sito ufficiale..."
    Invoke-WebRequest -Uri $NodeUrl -OutFile $ZipPath
    Write-Host "Estraggo Node.js nella cartella locale del progetto..."
    Expand-Archive -LiteralPath $ZipPath -DestinationPath $RuntimeDir -Force
    Remove-Item -LiteralPath $ZipPath -Force
  }

  if (-not (Test-Path $NodeExe) -or -not (Test-Path $NpmCmd)) {
    throw "Runtime Node.js incompleto. Elimina apps-script\.runtime e riavvia il launcher."
  }

  $env:PATH = "$NodeHome;$env:PATH"
  Write-Host "Node: $(& $NodeExe --version)"
  Write-Host ""

  if (-not (Test-Path $ClaspConfig)) {
    Write-Host "Manca apps-script\.clasp.json."
    Write-Host "Copia .clasp.json.example in .clasp.json e inserisci il tuo Script ID."
    Write-Host "Non condividere né committare il file .clasp.json reale."
    Pause-Exit
    exit 1
  }

  Write-Host "Scegli un'operazione:"
  Write-Host "  1 - Login Google (prima configurazione)"
  Write-Host "  2 - Carica i file su Apps Script (clasp push)"
  Write-Host "  3 - Verifica versione Node/npm"
  Write-Host "  Q - Esci"
  $Choice = Read-Host "Operazione"

  switch ($Choice.ToUpperInvariant()) {
    "1" {
      & $NpmCmd exec --yes --package=@google/clasp -- clasp login
      if ($LASTEXITCODE -ne 0) { throw "Login clasp non riuscito." }
    }
    "2" {
      Write-Host "ATTENZIONE: clasp push aggiorna i sorgenti del progetto Apps Script."
      Write-Host "Non pubblica una nuova versione /exec e non configura i permessi Google."
      $Confirm = Read-Host "Per continuare scrivi PUSH"
      if ($Confirm -cne "PUSH") { Write-Host "Operazione annullata."; Pause-Exit; exit 0 }
      & $NpmCmd exec --yes --package=@google/clasp -- clasp push
      if ($LASTEXITCODE -ne 0) { throw "clasp push non riuscito." }
    }
    "3" {
      & $NodeExe --version
      & $NpmCmd --version
    }
    "Q" { exit 0 }
    default { Write-Host "Scelta non valida."; Pause-Exit; exit 1 }
  }

  Write-Host ""
  Write-Host "Operazione terminata. Verifica sempre l'esito riportato sopra."
  Pause-Exit
}
catch {
  Write-Host ""
  Write-Host "ERRORE: $($_.Exception.Message)" -ForegroundColor Red
  Pause-Exit
  exit 1
}
