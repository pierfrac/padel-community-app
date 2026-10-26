# Padel Community · MVP Google Apps Script

Web app mobile-first senza server proprietario né installazione. L'interfaccia gira nel browser; Apps Script gestisce le operazioni condivise; Google Sheets conserva i dati della community; Calendar è opzionale; i feedback personali sono salvati direttamente nel Drive dell'utente con OAuth e non passano dal backend Apps Script.

## Funzioni implementate nel codice

- Accesso Google tramite Google Identity Services e verifica server-side dell'ID token.
- Profili con livelli Bronze, Silver, Silver-Gold, Gold, Gold+, sesso (Uomo/Donna, visibile solo al giocatore e agli amministratori) e posizione in campo: Sinistro, Destro o Mancino (il mancino gioca a destra). I profili precedenti, con "indifferente" o senza sesso, risultano incompleti.
- Banner non bloccante in cima alla pagina per chi non ha ancora indicato sesso e posizione.
- Area organizzatori (solo ADMIN_EMAILS): elenco dei profili incompleti con contatore e messaggio di sollecito da copiare per WhatsApp; lista email manuale per chi non è ancora nell'app; invio email in ccn con anteprima.
- Creazione partita e iscrizione automatica di chi la propone.
- Iscrizione/annullamento, limite di quattro iscritti per partita e annullamento della partita da parte di chi l'ha proposta o dell'amministratore.
- Match Score personalizzato: compatibilità tra le posizioni dei compagni, distanza di livello e feedback personale conservato nel Drive dell'utente. Punteggio base 50; modificatore di coppia: Mancino+Sinistro +10, Destro+Sinistro +10, Mancino+Destro −10, Destro+Destro −25, Sinistro+Sinistro −25, Mancino+Mancino −25. I valori sono provvisori e stanno nella tabella `PAIR_MODIFIERS` di `Code.gs` e nella funzione `pairModifier` del front end.
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
- ADMIN_EMAILS: email Gmail dell'amministratore, in minuscolo.
- ALLOWED_EMAILS (opzionale ma consigliato per il pilota): elenco di email autorizzate separate da virgole. Se vuoto, qualsiasi account Google che raggiunge il deployment può registrarsi.
- CALENDAR_ID (opzionale): ID del calendario condiviso sul quale creare gli eventi. Il proprietario dello script deve poter modificare quel calendario.
- APP_URL (opzionale, consigliato): indirizzo pubblico della pagina web dell'app (non l'URL /exec). Serve a inserire nelle email il link all'app e alle singole partite.
- SUPPORT_EMAIL (opzionale): indirizzo per i problemi indicato in ogni email e usato come risposta. Se manca, si usa pfcardillo-debutelespadel@gmail.com.

### Dopo l'aggiornamento del codice
1. Esegui di nuovo `setupPadelCommunity`: aggiunge le colonne `gender` ed `emailOptOut` alla scheda Players e crea la scheda MailList, senza toccare i dati esistenti. Autorizza anche il nuovo permesso di invio email.
2. Ripubblica una nuova versione del deployment.

## Email degli organizzatori

- Le email partono dall'account proprietario dello script. I destinatari sono sempre in ccn; il proprietario compare nel campo A perché Apps Script richiede almeno un destinatario.
- Per ogni invio l'app mostra un'anteprima con numero di destinatari, numero di invii e quota giornaliera rimasta, e rifiuta l'invio se la quota non basta.
- In fondo a ogni email vengono aggiunti il contatto per i problemi, la nota sulla riservatezza e come non ricevere più email: rispondere STOP oppure disattivare l'opzione nel profilo. Chi ha disattivato l'opzione è sempre escluso. Per chi è solo nella lista manuale basta toglierlo dalla lista.
- Selezione dei destinatari: tutti; solo profili incompleti; per partita aperta, con i giocatori più compatibili con chi è già iscritto. La lista manuale è usata solo con "Tutti".
- Limiti di Google Apps Script verificati nella [documentazione ufficiale](https://developers.google.com/apps-script/guides/services/quotas): 50 destinatari per messaggio, quindi gruppi da 49 in ccn più l'indirizzo del proprietario; per gli account gmail.com 100 destinatari al giorno, per Google Workspace 1.500. Con un account gmail.com un invio a circa 100 persone può non rientrare in un solo giorno: l'anteprima lo segnala e si può dividere su più giorni.

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
- Il sistema non include ancora notifiche automatiche (le email partono solo dall'area organizzatori) né push, flusso amministrativo completo per le prenotazioni ufficiali o cancellazione dei dati del profilo.
- Google Apps Script ha quote e limiti di esecuzione. È una soluzione adeguata per un gruppo piccolo/medio, non una garanzia di capacità illimitata.
- Prima del rilascio va eseguito un test reale con più account e controllata la schermata del consenso OAuth.

## Tabelle

- Players: profilo pubblico essenziale, email per gestione e livello/lato.
- Matches: partite proposte e ID evento Calendar opzionale.
- Registrations: iscrizioni alle partite.
- Feedback: file JSON separato nel Drive di ciascun utente, non una scheda condivisa.