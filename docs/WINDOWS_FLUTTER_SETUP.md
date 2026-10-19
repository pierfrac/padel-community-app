# Launcher Windows Padel Community

Il launcher è un pannello grafico Windows basato su PowerShell e Windows Forms: non richiede installazioni aggiuntive o privilegi amministrativi, se le policy del PC consentono l'esecuzione degli script e i download HTTPS.

## Primo avvio

1. Scarica o clona il repository in una cartella locale.
2. Fai doppio clic su PADEL.bat.
3. Nel pannello scegli dove conservare Flutter: cartella utente predefinita, cartella su un altro disco oppure SDK già installato.
4. Premi Avvia anteprima. Il launcher scarica solo ciò che manca, prepara il target Web e apre http://127.0.0.1:7357 nel browser.

## Runtime persistente

La configurazione è salvata in %LOCALAPPDATA%\PadelCommunity\settings.json. Per impostazione predefinita SDK e cache sono in %LOCALAPPDATA%\PadelCommunity\flutter-sdk\; si può invece scegliere una cartella su un altro disco. La cache Pub viene collocata accanto allo SDK scelto. Queste cartelle sono fuori dal repository, quindi cancellare o scaricare nuovamente il codice non richiede di riscaricare lo SDK.

Se si seleziona uno SDK esistente, indicare la cartella che contiene bin\flutter.bat. Non scegliere la cartella bin stessa.

Prima di scaricare, il launcher controlla lo spazio libero e, se il server comunica la dimensione, stima lo spazio necessario per archivio ed estrazione. Se lo spazio e insufficiente si ferma prima di iniziare e chiede di scegliere un altro disco. Il download viene scritto in un file temporaneo e registra avanzamento periodico nel log; solo dopo il trasferimento completo viene rinominato come ZIP. Un download interrotto non viene installato e al tentativo successivo viene scaricato di nuovo. Il launcher valida l'archivio ZIP prima di riutilizzarlo: se il download precedente e incompleto o non valido, lo elimina e lo scarica nuovamente. Se l'estrazione fallisce ma l'archivio e valido, lo conserva per il nuovo tentativo. Dopo l'estrazione verificata, lo ZIP viene eliminato per recuperare spazio. Il log registra anche una stima dell'ingombro dello SDK e lo spazio libero residuo. Flutter mantiene i componenti Web nella cache dello SDK e scarica solo gli artefatti mancanti.

## Pannello

- Avvia anteprima: prepara le dipendenze e avvia l'app nel browser.
- Prepara ambiente: installa/prepara SDK, cache Web e dipendenze senza avviare il server.
- Verifica tutto: format, analyze, test e build Web.
- Build Web, Analisi codice, Test, Formatta codice, Diagnostica: operazioni singole.
- Apri cartella runtime, Apri log, Apri repository: scorciatoie di supporto.

I log e la configurazione sono in %LOCALAPPDATA%\PadelCommunity\. Gli errori sono salvati in logs\flutter-setup.log dentro quella cartella dati.

## Avvio da terminale

Si possono ancora usare PADEL.bat setup, PADEL.bat web, PADEL.bat format, PADEL.bat analyze, PADEL.bat test, PADEL.bat build, PADEL.bat check, PADEL.bat doctor e PADEL.bat clean. Il doppio clic senza argomenti apre il pannello.

## Limiti e verifiche

Il launcher non modifica il PATH di sistema né il registro di Windows. Non serve Android Studio per provare la versione Web. Il primo download resta consistente: il vantaggio è scegliere il disco, non ripetere il download e riutilizzare la cache.

Il pannello e gli script non sono ancora stati eseguiti su una macchina Windows in questa sessione. Verificare sul PC reale prima di considerare il setup collaudato.
