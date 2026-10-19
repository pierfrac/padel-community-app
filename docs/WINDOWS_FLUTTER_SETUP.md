# Ambiente Flutter portabile su Windows

Questo progetto può essere compilato e provato in Windows senza installare Flutter a livello di sistema e senza permessi amministrativi, se le policy aziendali consentono il download e l'esecuzione dei programmi.

## Avvio

1. Scarica/clona il repository in una cartella locale corta, per esempio C:\PadelCommunity.
2. Fai doppio clic su PADEL.bat.
3. Al primo avvio il launcher scarica lo SDK Flutter stable ufficiale per Windows, lo estrae in runtime\flutter-sdk\flutter, abilita il target Web e scarica le dipendenze.
4. Il browser apre http://127.0.0.1:7357. Il terminale resta aperto mentre il server è attivo; Ctrl+C lo ferma.

Il download iniziale dello SDK è grande e può richiedere tempo. Le esecuzioni successive riutilizzano lo SDK già scaricato.

## Comandi

- PADEL.bat oppure PADEL.bat web: avvia la preview Web.
- PADEL.bat setup: prepara lo SDK e le dipendenze senza avviare il server.
- PADEL.bat format: formatta il codice Dart locale.
- PADEL.bat analyze: esegue l'analisi statica Flutter.
- PADEL.bat test: esegue i test Flutter.
- PADEL.bat build: esegue flutter build web; l'output è build\web.
- PADEL.bat check: esegue formattazione, analisi, test e build Web in sequenza, senza dipendere da GitHub Actions.
- PADEL.bat doctor: mostra la diagnostica Flutter.
- PADEL.bat clean: elimina solo la cache del progetto, non lo SDK portabile.

Il log del launcher è scritto in logs\flutter-setup.log.

## Cosa serve e cosa no

Per compilare e provare la versione Web non servono Android Studio, un emulatore Android o una installazione di Flutter globale. Il launcher non modifica il PATH di sistema né il registro di Windows. Lo SDK e la cache sono locali al repository e la cartella runtime è esclusa da Git.

La prima esecuzione richiede accesso HTTPS al dominio ufficiale storage.googleapis.com. Proxy, antivirus o policy aziendali possono comunque bloccare il download o l'esecuzione: il fatto di non avere permessi amministrativi non è di per sé un impedimento.

Questo ambiente non compila né installa la versione Android. L'obiettivo iniziale è verificare e provare l'interfaccia Flutter nel browser, anche con la modalità mobile di Chrome.
