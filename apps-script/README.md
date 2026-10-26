# Padel Community · MVP Google Apps Script

Web app mobile-first senza server proprietario né installazione. L'interfaccia gira nel browser; Apps Script gestisce le operazioni condivise; Google Sheets conserva i dati della community; Calendar è opzionale; i feedback personali sono salvati direttamente nel Drive dell'utente con OAuth e non passano dal backend Apps Script.

## Funzioni implementate nel codice

- Accesso Google tramite Google Identity Services e verifica server-side dell'ID token.
- Profili con livelli Bronze, Silver, Silver-Gold, Gold, Gold+ e preferenza destra, sinistra o indifferente.
- Creazione partita e iscrizione automatica di chi la propone.
- Iscrizione/annullamento, limite di quattro iscritti per partita e annullamento della partita da parte di chi l'ha proposta o dell'amministratore.
- Match Score personalizzato: complementarità destra/sinistra, distanza di livello e feedback personale conservato nel Drive dell'utente.
- Feedback post-partita salvato in un file JSON nel Drive personale dell'utente usando lo scope OAuth drive.file. Il backend non riceve il testo o la valutazione.
- Creazione di un evento Calendar da 90 minuti, se viene configurato CALENDAR_ID.
- Allowlist opzionale per limitare la community a indirizzi Gmail approvati.

## Configurazione Google richiesta

Questa configurazione va fatta una sola volta dal proprietario del progetto.

### 1. Crea il foglio
1. Crea un Google Sheet chiamato Padel Community.
2. Apri Estensioni → Apps Script dal foglio.
3. Sostituisci Code.gs e crea Index.html copiando i file in questa cartella.
4. Esegui setupPadelCommunity e autorizza gli accessi richiesti. Le schede Players, Matches e Registrations vengono create o aggiornate conservando i dati esistenti.
5. Se esiste una vecchia scheda FeedbackPrivate creata dal prototipo precedente, non usarla per nuovi feedback. Dopo aver verificato che non contenga dati da conservare, eliminala manualmente: questa versione non la legge né la scrive.

### 2. Crea le credenziali OAuth
1. In Google Cloud Console crea o seleziona un progetto e configura la schermata di consenso OAuth.
2. Abilita Google Drive API per quel progetto.
3. Crea un OAuth Client ID di tipo applicazione web.
4. Aggiungi gli origini autorizzati mostrati dalla pagina di deployment Apps Script. Non aggiungere URL inventati: copia gli origin effettivamente usati dal browser e autorizzali nel client.
5. Copia il Client ID completo.

### 3. Proprietà dello script
Nell'editor Apps Script apri Impostazioni progetto → Proprietà script e crea:

- GOOGLE_CLIENT_ID: il Client ID OAuth appena creato.
- ADMIN_EMAILS: solo per la prima installazione: `setupPadelCommunity` ne copia gli indirizzi nella scheda **Admins** del foglio. Da lì in poi gli amministratori si gestiscono solo nella scheda **Admins** (colonna `email`: scelta da un elenco a tendina con gli indirizzi della scheda Players; colonna `community`: scelta dalla scheda **Communities**). Chi gestisce più community ha una riga per ciascuna. Finché la scheda non ha righe vale ancora ADMIN_EMAILS.
- COMMUNITY_NAME (facoltativa): nome di questa community, di default `Telespadel`.

### Inviti nella community (solo amministratori)
Nella scheda Profilo, riquadro «Strumenti amministratore»: scrivi fino a 20 email (arriva il link d'invito, funziona con qualsiasi account Google) oppure crea un link da condividere via WhatsApp, copia o QR code. La scheda **Invites** del foglio tiene traccia di inviti e ingressi.
- ALLOWED_EMAILS (opzionale ma consigliato per il pilota): elenco di email autorizzate separate da virgole. Se vuoto, qualsiasi account Google che raggiunge il deployment può registrarsi.
- CALENDAR_ID (opzionale): ID del calendario condiviso sul quale creare gli eventi. Il proprietario dello script deve poter modificare quel calendario.

### 4. Pubblica
1. Seleziona Esegui deployment → Nuovo deployment → App web.
2. Esegui come proprietario dello script, così i giocatori non devono avere accesso diretto al foglio dati.
3. Per un test controllato scegli l'accesso più restrittivo che consente agli account del gruppo di aprire l'app; la disponibilità delle opzioni dipende dal tipo di account Google.
4. Pubblica e copia il link che termina in /exec.
5. Prova con due account Google diversi: login, creazione profilo, creazione partita, iscrizione e feedback. Verifica anche che il feedback compaia nel Drive del solo account che l'ha lasciato e che non venga scritto nelle schede condivise.

Link da inviare su WhatsApp: l'URL /exec della web app. Non il link del foglio e non il link dell'editor Apps Script.

## Privacy dei feedback

Il feedback viene scritto dal browser direttamente nel Drive personale del giocatore con il suo token OAuth. Non viene inviato a una funzione Apps Script e non viene salvato in Sheets o Calendar. Il Match Score personalizzato viene calcolato nel browser leggendo quel file privato.

Limiti e condizioni:
- Il file è privato per impostazione predefinita, ma il giocatore può scegliere di condividerlo manualmente dal proprio Drive.
- Il proprietario del progetto non riceve i feedback attraverso l'app; Google gestisce comunque il servizio Drive secondo i propri termini.
- Lo scope richiesto è drive.file, non l'accesso generale a tutto il Drive.
- Se l'utente revoca l'autorizzazione Drive, può continuare a usare le partite ma non potrà leggere/salvare feedback né applicarli al Match Score.
- Prima di raccogliere dati reali, verificare il flusso OAuth e la privacy con account di prova.

## Limiti del prototipo da conoscere

- Il codice è stato scritto nel repository ma non è stato eseguito nel tuo account Google. Non esiste ancora un URL pubblico /exec generato da questo progetto.
- Google OAuth Client ID, consenso, origini autorizzate e API Drive devono essere configurati dal proprietario.
- Calendar funziona solo dopo aver impostato CALENDAR_ID e concesso allo script accesso al calendario. L'evento viene creato per 90 minuti; la gestione di prenotazioni ufficiali del circolo e alternative proposte non è ancora implementata.
- Il Match Score è una prima formula euristica, non un rating competitivo e non usa il risultato della partita. I feedback sono direzionali e personali.
- Il sistema non include ancora notifiche email/push, flusso amministrativo completo per le prenotazioni ufficiali o cancellazione dei dati del profilo.
- Google Apps Script ha quote e limiti di esecuzione. È una soluzione adeguata per un gruppo piccolo/medio, non una garanzia di capacità illimitata.
- Prima del rilascio va eseguito un test reale con più account e controllata la schermata del consenso OAuth.

## Tabelle

- Players: profilo pubblico essenziale, email per gestione e livello/lato.
- Matches: partite proposte e ID evento Calendar opzionale.
- Registrations: iscrizioni alle partite.
- Feedback: file JSON separato nel Drive di ciascun utente, non una scheda condivisa.
## Inviti via email e promemoria
- Chi viene invitato a una partita (giocatore della community messo in un posto) riceve una email con il link per accettare. Le email partono dall'account che possiede lo script.
- Dopo 24 ore senza risposta: se la partita è a più di 4 giorni parte un promemoria; se è entro 4 giorni l'invito viene annullato, il posto si libera e l'organizzatore riceve un avviso.
- Il controllo gira ogni ora con un trigger. Va attivato una volta: nell'editor esegui `installTriggers` e accetta i nuovi permessi (invio email e trigger), poi ripubblica con "Nuova versione".
- Proprietà script opzionale `APP_URL`: indirizzo del sito usato nei link delle email (di default quello su GitHub Pages).
- Limite: un account Gmail personale può inviare circa 100 email al giorno con Apps Script.

### Avviso (disclaimer)
Il testo mostrato in fondo all'app e nelle email d'invito sta nella scheda **Settings** del foglio, riga `disclaimer`, colonna `value`. `setupPadelCommunity` lo crea con il testo predefinito; modificalo lì. Cella vuota = testo predefinito.
