/**
 * Padel Community - Google Apps Script MVP scaffold
 *
 * Create this project from Extensions > Apps Script inside the community spreadsheet.
 * This keeps SpreadsheetApp.getActiveSpreadsheet() bound to the intended spreadsheet.
 *
 * SECURITY NOTE:
 * This scaffold intentionally does not expose feedback data through the web API.
 * A sheet hidden from the UI is not a privacy boundary. The spreadsheet owner and
 * administrators may still access its contents. Do not collect sensitive feedback
 * until authentication and access rules have been tested.
 */

const SHEET_HEADERS = {
  Players: ["playerId", "displayName", "email", "skillLevel", "preferredSide", "active", "createdAt"],
  Matches: ["matchId", "dateTime", "venue", "createdBy", "status", "notes", "createdAt"],
  Registrations: ["registrationId", "matchId", "playerId", "status", "createdAt"],
  FeedbackPrivate: ["feedbackId", "matchId", "fromPlayerId", "aboutPlayerId", "wouldPlayAgain", "partnerExperience", "createdAt"]
};

function doGet() {
  return HtmlService.createHtmlOutputFromFile("Index")
    .setTitle("Padel Community")
    .addMetaTag("viewport", "width=device-width, initial-scale=1");
}

/**
 * Run once from the spreadsheet-bound Apps Script editor.
 * Creates missing tabs and headers; does not overwrite existing data.
 */
function setupPadelCommunity() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  if (!ss) throw new Error("Apri Apps Script dal foglio Google Community, tramite Estensioni > Apps Script.");

  Object.keys(SHEET_HEADERS).forEach(function (name) {
    let sheet = ss.getSheetByName(name);
    if (!sheet) sheet = ss.insertSheet(name);
    if (sheet.getLastRow() === 0) {
      sheet.getRange(1, 1, 1, SHEET_HEADERS[name].length).setValues([SHEET_HEADERS[name]]);
      sheet.setFrozenRows(1);
    }
  });

  return "Struttura Padel Community creata. Verifica i permessi prima di pubblicare.";
}

/** Public-safe data only: no email addresses and no private feedback. */
function getMatches() {
  const sheet = getSheet_("Matches");
  if (sheet.getLastRow() < 2) return [];
  const rows = sheet.getRange(2, 1, sheet.getLastRow() - 1, SHEET_HEADERS.Matches.length).getValues();
  return rows
    .filter(function (row) { return row[0] && row[4] !== "cancelled"; })
    .map(function (row) {
      return {
        matchId: String(row[0]),
        dateTime: row[1] instanceof Date ? row[1].toISOString() : String(row[1] || ""),
        venue: String(row[2] || ""),
        status: String(row[4] || "open"),
        notes: String(row[5] || "")
      };
    });
}

/**
 * Prototype action. Deployment must be restricted to the intended community.
 * Before enabling real use, add reliable player identity and membership checks.
 */
function createMatch(input) {
  if (!input || typeof input !== "object") throw new Error("Dati della partita mancanti.");
  const venue = String(input.venue || "").trim();
  const dateTime = String(input.dateTime || "").trim();
  const notes = String(input.notes || "").trim();
  if (!venue || !dateTime) throw new Error("Inserisci campo e data/ora.");
  const parsedDate = new Date(dateTime);
  if (isNaN(parsedDate.getTime())) throw new Error("Data/ora non valida.");

  const sheet = getSheet_("Matches");
  const matchId = Utilities.getUuid();
  const createdAt = new Date();
  sheet.appendRow([matchId, parsedDate, venue, "pending-identity", "open", notes, createdAt]);
  return { matchId: matchId, message: "Partita creata. L'identità del creatore va collegata all'accesso definitivo." };
}

function getSheet_(name) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  if (!ss) throw new Error("Nessun foglio collegato. Crea lo script da Estensioni > Apps Script nel foglio.");
  const sheet = ss.getSheetByName(name);
  if (!sheet) throw new Error("Foglio '" + name + "' non trovato. Esegui prima setupPadelCommunity().");
  return sheet;
}
