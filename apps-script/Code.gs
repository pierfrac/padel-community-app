/**
 * Padel Community web app backend.
 * Configure Script Properties: GOOGLE_CLIENT_ID, ADMIN_EMAILS, CALENDAR_ID (optional).
 * This script is bound to the community spreadsheet.
 */
const HEADERS = {
  Players: ["playerId","displayName","email","skillLevel","preferredSide","active","createdAt","updatedAt"],
  Matches: ["matchId","dateTime","venue","createdBy","status","notes","createdAt","calendarEventId"],
  Registrations: ["registrationId","matchId","playerId","status","createdAt","partnerId"],
  FeedbackPrivate: ["DO_NOT_USE"]
};

function doGet() {
  const t = HtmlService.createTemplateFromFile("Index");
  t.googleClientId = PropertiesService.getScriptProperties().getProperty("GOOGLE_CLIENT_ID") || "";
  return t.evaluate().setTitle("Padel Community").addMetaTag("viewport","width=device-width, initial-scale=1");
}

const BACKEND_VERSION = "2026-10-23.3";
const API_METHODS = ["getAppData","saveProfile","createMatch","registerForMatch","cancelRegistration","completeMatch","cancelMatch","setPartner"];

/** JSON API for the static front end (web/). Body is text/plain JSON to avoid a CORS preflight. */
function doPost(e) {
  let out;
  try {
    const req = JSON.parse(e.postData.contents);
    if (req.method === "version") return ContentService.createTextOutput(JSON.stringify({ok:true,version:BACKEND_VERSION})).setMimeType(ContentService.MimeType.JSON);
    if (API_METHODS.indexOf(req.method) < 0) throw new Error("Operazione non valida.");
    out = {ok:true, result:this[req.method](req.idToken, req.arg)};
  } catch (err) {
    out = {ok:false, error:String(err && err.message || err)};
  }
  return ContentService.createTextOutput(JSON.stringify(out)).setMimeType(ContentService.MimeType.JSON);
}

function setupPadelCommunity() {
  const sid = PropertiesService.getScriptProperties().getProperty("SPREADSHEET_ID");
  const ss = sid ? SpreadsheetApp.openById(sid) : SpreadsheetApp.getActiveSpreadsheet();
  if (!ss) throw new Error("Apri Apps Script dal foglio Google oppure imposta SPREADSHEET_ID nelle Proprietà script.");
  ["Players","Matches","Registrations"].forEach(function(name) {
    let sh = ss.getSheetByName(name);
    if (!sh) sh = ss.insertSheet(name);
    if (sh.getLastRow() === 0) {
      sh.getRange(1,1,1,HEADERS[name].length).setValues([HEADERS[name]]);
      sh.setFrozenRows(1);
    } else {
      const existingCount = sh.getLastColumn();
      const first = sh.getRange(1,1,1,existingCount).getDisplayValues()[0];
      const expectedPrefix = HEADERS[name].slice(0,existingCount);
      if (existingCount > HEADERS[name].length || first.join("|") !== expectedPrefix.join("|"))
        throw new Error("Intestazioni non compatibili nella scheda "+name+". Non sono state sovrascritte.");
      if (existingCount < HEADERS[name].length) {
        sh.getRange(1,existingCount+1,1,HEADERS[name].length-existingCount).setValues([HEADERS[name].slice(existingCount)]);
      }
      sh.setFrozenRows(1);
    }
  });
  return "Struttura pronta. Ora configura GOOGLE_CLIENT_ID e ADMIN_EMAILS nelle Proprietà script.";
}

function getPublicConfig() {
  const p = PropertiesService.getScriptProperties();
  return {googleClientId:p.getProperty("GOOGLE_CLIENT_ID") || "", configured:!!p.getProperty("GOOGLE_CLIENT_ID")};
}

function getAppData(idToken) {
  const user = verifyUser_(idToken);
  const players = readRows_("Players").filter(r => r.playerId && truthy_(r.active)).map(function(r) {
    return {playerId:String(r.playerId),displayName:String(r.displayName || "Giocatore"),skillLevel:String(r.skillLevel || "Da definire"),preferredSide:String(r.preferredSide || "indifferent"),active:true};
  });
  const registrations = readRows_("Registrations").filter(r => r.registrationId && String(r.status) === "joined").map(function(r) {
    return {registrationId:String(r.registrationId),matchId:String(r.matchId),playerId:String(r.playerId),status:String(r.status),partnerId:String(r.partnerId || "")};
  });
  const matches = readRows_("Matches").filter(r => r.matchId && String(r.status) !== "cancelled").map(function(r) {
    return {matchId:String(r.matchId),dateTime:iso_(r.dateTime),venue:String(r.venue || ""),status:String(r.status || "open"),notes:String(r.notes || ""),createdBy:String(r.createdBy || ""),registeredCount:0};
  });
  const counts = {};
  registrations.forEach(r => counts[r.matchId]=(counts[r.matchId]||0)+1);
  matches.forEach(m => m.registeredCount=counts[m.matchId]||0);
  const mine = players.find(p => p.playerId === user.playerId) || null;
  return {user:{email:user.email,playerId:user.playerId,isAdmin:user.isAdmin},me:mine,players:players,matches:matches,registrations:registrations};
}

function saveProfile(idToken, input) {
  const user = verifyUser_(idToken);
  input = input || {};
  const name = clean_(input.displayName,80);
  const level = clean_(input.skillLevel,30);
  const side = clean_(input.preferredSide,20);
  const allowedLevels = ["Bronze","Silver","Silver-Gold","Gold","Gold+"];
  if (!name || allowedLevels.indexOf(level)<0 || ["right","left","indifferent"].indexOf(side)<0)
    throw new Error("Inserisci nome, livello e lato preferito.");
  const sh=sheet_("Players"), rows=readRows_("Players");
  const existing=rows.find(r=>String(r.playerId)===user.playerId);
  const values=[user.playerId,name,user.email,level,side,true,existing?existing.createdAt:new Date(),new Date()];
  if(existing) sh.getRange(existing._row,1,1,values.length).setValues([values]); else sh.appendRow(values);
  return {message:"Profilo salvato.",playerId:user.playerId};
}

function createMatch(idToken,input) {
  const user=verifyUser_(idToken); input=input||{};
  const venue=clean_(input.venue,120), dateText=clean_(input.dateTime,80), notes=clean_(input.notes,500);
  if(!venue||!dateText) throw new Error("Inserisci campo e data/ora.");
  const date=new Date(dateText); if(isNaN(date.getTime())||date.getTime()<Date.now()-60000) throw new Error("Scegli una data futura valida.");
  const id=Utilities.getUuid(), created=new Date();
  let eventId="";
  const calendarId=PropertiesService.getScriptProperties().getProperty("CALENDAR_ID");
  if(calendarId) {
    try {
      const calendar=CalendarApp.getCalendarById(calendarId);
      if(!calendar) throw new Error("Calendario non accessibile: verifica CALENDAR_ID e permessi.");
      const event=calendar.createEvent("Padel Community · "+venue,date,new Date(date.getTime()+90*60000),{description:"Partita proposta da "+user.email+(notes?"\n\n"+notes:"")});
      eventId=event.getId();
    } catch(err) { throw new Error("Partita non salvata: errore Calendar. "+err.message); }
  }
  sheet_("Matches").appendRow([id,date,venue,user.playerId,"open",notes,created,eventId]);
  sheet_("Registrations").appendRow([Utilities.getUuid(),id,user.playerId,"joined",created,""]);
  return {matchId:id,message:calendarId?"Partita creata e aggiunta al calendario.":"Partita creata. Calendar non è ancora configurato."};
}

function registerForMatch(idToken,input) {
  const user=verifyUser_(idToken); input=input||{};
  const matchId=clean_(input.matchId,80);
  const lock=LockService.getScriptLock();
  lock.waitLock(10000);
  try {
    const match=readRows_("Matches").find(r=>String(r.matchId)===matchId&&String(r.status)!=="cancelled");
    if(!match) throw new Error("Partita non trovata.");
    if(String(match.status)==="completed") throw new Error("La partita è già conclusa.");
    if(new Date(match.dateTime).getTime()<Date.now()) throw new Error("Non puoi iscriverti a una partita già iniziata.");
    const regs=readRows_("Registrations");
    if(regs.some(r=>String(r.matchId)===matchId&&String(r.playerId)===user.playerId&&String(r.status)==="joined")) throw new Error("Sei già iscritto a questa partita.");
    const active=regs.filter(r=>String(r.matchId)===matchId&&String(r.status)==="joined");
    if(active.length>=4) throw new Error("La partita è già completa.");
    sheet_("Registrations").appendRow([Utilities.getUuid(),matchId,user.playerId,"joined",new Date(),""]);
    return {message:"Iscrizione registrata."};
  } finally {
    lock.releaseLock();
  }
}

function cancelRegistration(idToken,input) {
  const user=verifyUser_(idToken); const matchId=clean_(input&&input.matchId,80);
  const sh=sheet_("Registrations"), regs=readRows_("Registrations");
  const row=regs.find(r=>String(r.matchId)===matchId&&String(r.playerId)===user.playerId&&String(r.status)==="joined");
  if(!row) throw new Error("Non risulti iscritto a questa partita.");
  sh.getRange(row._row,4).setValue("cancelled");
  sh.getRange(row._row,6).setValue("");
  regs.filter(r=>String(r.matchId)===matchId&&String(r.partnerId||"")===user.playerId).forEach(r=>sh.getRange(r._row,6).setValue(""));
  return {message:"Iscrizione annullata."};
}

function setPartner(idToken,input) {
  const user=verifyUser_(idToken); input=input||{};
  const matchId=clean_(input.matchId,80), partnerId=clean_(input.partnerId,80);
  const lock=LockService.getScriptLock();
  lock.waitLock(10000);
  try {
    const sh=sheet_("Registrations");
    const regs=readRows_("Registrations").filter(r=>String(r.matchId)===matchId&&String(r.status)==="joined");
    const mine=regs.find(r=>String(r.playerId)===user.playerId);
    if(!mine) throw new Error("Devi prima iscriverti alla partita.");
    const oldId=String(mine.partnerId||"");
    if(oldId) { const o=regs.find(r=>String(r.playerId)===oldId&&String(r.partnerId||"")===user.playerId); if(o) sh.getRange(o._row,6).setValue(""); }
    sh.getRange(mine._row,6).setValue("");
    if(!partnerId) return {message:"Compagno fisso rimosso."};
    if(partnerId===user.playerId) throw new Error("Non puoi scegliere te stesso.");
    const other=regs.find(r=>String(r.playerId)===partnerId);
    if(!other) throw new Error("Il compagno scelto non è iscritto a questa partita.");
    const op=String(other.partnerId||"");
    if(op&&op!==user.playerId) throw new Error("Il compagno scelto ha già un compagno fisso.");
    sh.getRange(mine._row,6).setValue(partnerId);
    sh.getRange(other._row,6).setValue(user.playerId);
    return {message:"Compagno fisso impostato."};
  } finally {
    lock.releaseLock();
  }
}

function completeMatch(idToken,input) {
  const user=verifyUser_(idToken); const matchId=clean_(input&&input.matchId,80);
  const sh=sheet_("Matches"), matches=readRows_("Matches");
  const row=matches.find(r=>String(r.matchId)===matchId);
  if(!row) throw new Error("Partita non trovata.");
  if(!user.isAdmin&&String(row.createdBy)!==user.playerId) throw new Error("Solo chi ha proposto la partita o un amministratore può segnarla come conclusa.");
  if(String(row.status)==="cancelled") throw new Error("Una partita annullata non può essere conclusa.");
  const start=new Date(row.dateTime);
  if(isNaN(start.getTime())||Date.now()<start.getTime()+90*60000) throw new Error("La partita può essere segnata conclusa dopo l'orario previsto di fine (90 minuti).");
  sh.getRange(row._row,5).setValue("completed");
  return {message:"Partita segnata come conclusa. Ora i partecipanti possono lasciare il feedback privato."};
}

function cancelMatch(idToken,input) {
  const user=verifyUser_(idToken); const matchId=clean_(input&&input.matchId,80);
  const sh=sheet_("Matches"), matches=readRows_("Matches");
  const row=matches.find(r=>String(r.matchId)===matchId);
  if(!row) throw new Error("Partita non trovata.");
  if(!user.isAdmin&&String(row.createdBy)!==user.playerId) throw new Error("Solo chi ha proposto la partita o un amministratore può annullarla.");
  sh.getRange(row._row,5).setValue("cancelled");
  const eventId=String(row.calendarEventId||"");
  if(eventId) {
    const calId=PropertiesService.getScriptProperties().getProperty("CALENDAR_ID");
    if(calId) { try { const cal=CalendarApp.getCalendarById(calId); const ev=cal&&cal.getEventById(eventId); if(ev) ev.deleteEvent(); } catch(e) {} }
  }
  return {message:"Partita annullata."};
}

/** Calendar events use the configured community calendar; no private feedback is written to Sheets. */
function verifyUser_(idToken) {
  if(!idToken) throw new Error("Accedi con Google per continuare.");
  const props=PropertiesService.getScriptProperties(), clientId=props.getProperty("GOOGLE_CLIENT_ID");
  if(!clientId) throw new Error("Configurazione incompleta: manca GOOGLE_CLIENT_ID nelle Proprietà script.");
  const response=UrlFetchApp.fetch("https://oauth2.googleapis.com/tokeninfo?id_token="+encodeURIComponent(idToken),{muteHttpExceptions:true});
  if(response.getResponseCode()!==200) throw new Error("Accesso Google non verificato. Ricarica la pagina e accedi di nuovo.");
  const token=JSON.parse(response.getContentText());
  if(token.aud!==clientId||token.email_verified!=="true"||!token.email||!token.sub) throw new Error("Credenziali Google non valide per questa app.");
  const exp=Number(token.exp||0); if(exp*1000<Date.now()) throw new Error("Sessione Google scaduta. Accedi di nuovo.");
  const email=String(token.email).toLowerCase();
  const allowedEmails=(props.getProperty("ALLOWED_EMAILS")||"").split(",").map(s=>s.trim().toLowerCase()).filter(Boolean);
  if(allowedEmails.length && allowedEmails.indexOf(email)<0) throw new Error("Questo account non è ancora abilitato alla community. Chiedi all'amministratore di aggiungere la tua Gmail.");
  const adminEmails=(props.getProperty("ADMIN_EMAILS")||"").split(",").map(s=>s.trim().toLowerCase()).filter(Boolean);
  return {email:email,playerId:"google:"+token.sub,isAdmin:adminEmails.indexOf(email)>=0};
}

function readRows_(name) {
  const sh=sheet_(name); if(sh.getLastRow()<2) return [];
  const headers=HEADERS[name];
  return sh.getRange(2,1,sh.getLastRow()-1,headers.length).getValues().map(function(row,i){
    const o={_row:i+2}; headers.forEach((h,j)=>o[h]=row[j]); return o;
  });
}
function sheet_(name) {
  const id=PropertiesService.getScriptProperties().getProperty("SPREADSHEET_ID");
  const ss=id?SpreadsheetApp.openById(id):SpreadsheetApp.getActiveSpreadsheet(); if(!ss) throw new Error("Collega lo script al foglio dati o imposta SPREADSHEET_ID.");
  const sh=ss.getSheetByName(name); if(!sh) throw new Error("Scheda "+name+" assente. Esegui setupPadelCommunity().");
  return sh;
}
function clean_(v,max) { return String(v==null?"":v).trim().replace(/[<>]/g,"").slice(0,max); }
function truthy_(v) { return v===true||String(v).toLowerCase()==="true"||v===1; }
function iso_(v) { if(!v)return ""; const d=v instanceof Date?v:new Date(v); return isNaN(d.getTime())?String(v):d.toISOString(); }
