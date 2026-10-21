# Padel Community - Apps Script MVP

Questa cartella contiene lo scheletro iniziale della web app Google Apps Script. Non è ancora una versione pronta per essere distribuita alla community: mancano autenticazione affidabile dei giocatori, iscrizioni alle partite, integrazione Calendar e controlli definitivi per i feedback privati.

## Preparazione

1. Crea un Google Sheet chiamato **Padel Community**.
2. Dal foglio, apri **Estensioni → Apps Script**. È importante creare uno script collegato al foglio, così `SpreadsheetApp.getActiveSpreadsheet()` punta al database corretto.
3. Nel progetto Apps Script crea due file: `Code.gs` e `Index.html`.
4. Copia i contenuti dei file omonimi di questa cartella.
5. Salva ed esegui manualmente `setupPadelCommunity` dall'editor. Autorizza lo script quando Google lo richiede. Questo crea le schede e le intestazioni senza cancellare dati già presenti.
6. Prova `getMatches` dall'interfaccia e verifica che il foglio `Matches` esista.

## Deployment

1. Nell'editor Apps Script seleziona **Esegui deployment → Nuovo deployment → App web**.
2. Scegli con attenzione chi può accedere e se lo script deve essere eseguito come proprietario o come utente che accede.
3. Esegui il deployment e prova l'URL `/exec` in una finestra privata e da un secondo account.
4. Non distribuire il link alla community finché non sono stati verificati identità, autorizzazioni e accesso ai dati.

## Struttura iniziale dei dati

- `Players`: profilo, livello e lato preferito.
- `Matches`: partite proposte.
- `Registrations`: iscrizioni.
- `FeedbackPrivate`: struttura predisposta, ma non esposta da alcuna funzione client.

## Privacy e sicurezza

- La scheda `FeedbackPrivate` non viene restituita dall'API pubblica dell'interfaccia.
- Questo non rende i dati invisibili al proprietario del foglio o agli amministratori con accesso.
- Non inserire giudizi reali finché l'identità del mittente e i controlli di autorizzazione non sono implementati e testati.
- Il campo `createdBy` è volutamente impostato a `pending-identity`: il prototipo non deve fingere di sapere chi ha creato una partita.
- Il prototipo non va pubblicato con accesso anonimo o distribuito come app operativa senza completare i controlli indicati.

## Stato

Prototipo tecnico iniziale: pagina web, lettura delle partite e creazione di una proposta di partita. Non è ancora un'app completa.
