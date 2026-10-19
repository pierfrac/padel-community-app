# Launcher Windows Padel Community

Il launcher è un pannello grafico Windows basato su PowerShell e Windows Forms: non richiede installazioni aggiuntive o privilegi amministrativi, se le policy del PC consentono l'esecuzione degli script e i download HTTPS.

## Primo avvio

1. Scarica o clona il repository in una cartella locale.
2. Fai doppio clic su PADEL.bat.
3. Nel pannello scegli dove conservare Flutter: cartella utente predefinita, cartella su un altro disco oppure SDK già installato.
4. Premi Avvia anteprima. Il launcher scarica solo ciò che manca, genera la cartella `web/` con `flutter create` se assente, prepara il target Web, seleziona una porta locale libera e apre il browser solo dopo aver verificato che `main.dart.js` venga servito con un MIME JavaScript.

## Scaricare il sorgente con un nome breve

GitHub assegna agli ZIP automatici del branch un nome basato sul repository e sul branch; non esiste un'impostazione per personalizzarlo. Il workflow `.github/workflows/padel-zip.yml` crea invece un artifact chiamato `PADEL.zip` a ogni push su `develop`.

Per scaricarlo, apri la pagina [Actions del workflow PADEL ZIP](https://github.com/pierfrac/padel-community-app.-README-iniziale-non/actions/workflows/padel-zip.yml), seleziona l'esecuzione più recente completata e scarica l'artifact `PADEL`. Gli artifact restano disponibili per 14 giorni; dopo ogni aggiornamento del branch ne viene generato uno nuovo. Questa è una copia del sorgente tracciato da Git, senza la cartella interna `.git` e senza file temporanei locali.

## Runtime persistente

La configurazione è salvata in %LOCALAPPDATA%\PadelCommunity\settings.json. Per impostazione predefinita SDK e cache sono in %LOCALAPPDATA%\PadelCommunity\flutter-sdk\; si può invece scegliere una cartella su un altro disco. La cache Pub viene collocata accanto allo SDK scelto. Queste cartelle sono fuori dal repository, quindi cancellare o scaricare nuovamente il codice non richiede di riscaricare lo SDK.

Se si seleziona uno SDK esistente, indicare la cartella che contiene bin\flutter.bat. Non scegliere la cartella bin stessa.

Prima di scaricare, il launcher controlla lo spazio libero e, quando il server comunica la dimensione, stima lo spazio necessario per archivio ed estrazione; se non basta, si ferma prima di iniziare. Lo ZIP viene salvato nella cartella runtime persistente, non in TEMP, con un nome legato alla versione esatta. Il log mostra il progresso ogni 25 MB. Se un download si interrompe, il file .part viene conservato e il tentativo successivo prova a riprendere dal punto raggiunto, se il server supporta le richieste Range. Prima dell'estrazione il launcher confronta SHA-256 con il checksum pubblicato nel manifest ufficiale Flutter e controlla che lo ZIP contenga flutter/bin/flutter.bat. Non riutilizza un archivio di un'altra versione. Dopo l'estrazione verificata, lo ZIP viene eliminato per recuperare spazio. Il log registra anche l'ingombro stimato dello SDK e lo spazio libero residuo. Per l'anteprima sono preparati gli artefatti Web; non viene richiesto Android Studio.

## Pannello

- Start sessione 1 / Stop 1 e Start sessione 2 / Stop 2: gestiscono due anteprime indipendenti su porte diverse.
- Ogni sessione usa una copia di lavoro separata e log dedicati; SDK Flutter e cache Pub vengono condivisi per evitare di riscaricarli.
- Fermare una sessione non interrompe l'altra. Chiudendo il pannello, entrambe le sessioni gestite vengono arrestate.
- Prepara ambiente: prepara SDK, cache Web e dipendenze senza avviare l'app.
- Diagnostica: esegue `flutter doctor`; gli avvisi Android/Visual Studio non impediscono da soli l'anteprima Web.
- Strumenti avanzati: Verifica tutto, Build Web, Analisi codice, Test e Formatta codice.
- Apri cartella runtime, Apri log, Apri repository: scorciatoie di supporto.

I log e la configurazione sono in %LOCALAPPDATA%\PadelCommunity\. Gli errori sono salvati in logs\flutter-setup.log dentro quella cartella dati.

## Avvio da terminale

Si possono ancora usare PADEL.bat setup, PADEL.bat web, PADEL.bat format, PADEL.bat analyze, PADEL.bat test, PADEL.bat build, PADEL.bat check, PADEL.bat doctor e PADEL.bat clean. Il doppio clic senza argomenti apre il pannello.

## Limiti e verifiche

Il launcher non modifica il PATH di sistema né il registro di Windows. Se Git non è già disponibile, scarica MinGit ufficiale in modalità portabile nella cartella dati di PADEL sotto %LOCALAPPDATA%\PadelCommunity, ne verifica il checksum SHA-256 e aggiunge il comando soltanto al PATH del processo. Non serve Android Studio per provare la versione Web. Il pacchetto Windows ufficiale è distribuito come ZIP. Non è stata individuata una versione Windows ufficiale equivalente in 7z/tar.xz più compressa; si evita quindi di introdurre pacchetti non ufficiali. Il peso principale viene dalla distribuzione SDK stessa, non solo dall'installer. Dopo il primo download il launcher riutilizza SDK e cache persistenti.

Il pannello e gli script non sono ancora stati eseguiti su una macchina Windows in questa sessione. Verificare sul PC reale prima di considerare il setup collaudato.
