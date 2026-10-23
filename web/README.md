# Front end statico (web/)

Pagina ospitata su un host gratuito (Netlify, Cloudflare Pages o GitHub Pages). Apps Script resta solo backend per Sheets e Calendar, via `doPost`. I feedback privati vanno nel Drive di ciascun giocatore con scope `drive.file`, direttamente dal browser.

Perché non basta `/exec`: dentro Apps Script la pagina gira su `*.googleusercontent.com`, un'origine che Google rifiuta (`origin_mismatch`). Su un tuo dominio l'origine si può autorizzare.

## Configurazione
1. Pubblica la cartella `web/` sull'host (nessuna build).
2. In Google Cloud Console, nel client OAuth, aggiungi tra le **Origini JavaScript autorizzate** l'origine esatta dell'host (es. `https://tuo-sito.netlify.app`, senza slash finale).
3. Apps Script: Esegui deployment → App web → esegui come **proprietario**, accesso **Chiunque** (necessario per le chiamate `fetch`; l'accesso ai dati è protetto dalla verifica server-side dell'ID token e da `ALLOWED_EMAILS`). Ripubblica una nuova versione dopo aver aggiornato `Code.gs`.
4. Compila `web/config.js` con `googleClientId` e `apiUrl` (URL `/exec`) e ripubblica.
5. Prova: login, profilo, partita, iscrizione, autorizzazione Drive, salvataggio e lettura del feedback.
