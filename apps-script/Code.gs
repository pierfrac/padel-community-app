/**
 * Padel Community web app backend.
 * Configure Script Properties: GOOGLE_CLIENT_ID, ADMIN_EMAILS, CALENDAR_ID (optional).
 * This script is bound to the community spreadsheet.
 */
const HEADERS = {
  Players: ["playerId","displayName","email","skillLevel","preferredSide","active","createdAt","updatedAt","photoUrl","gender","consentAt","consentVersion"],
  Matches: ["matchId","dateTime","venue","createdBy","status","notes","createdAt","calendarEventId","lineup"],
  Registrations: ["registrationId","matchId","playerId","status","createdAt","partnerId"],
  Shares: ["shareId","matchId","token","label","createdBy","createdAt","openedAt","lastOpenAt","opens","devices","playerId","claimedAt","kind","responses"],
  Devices: ["deviceId","playerId","firstSeen","lastSeen"],
  Communities: ["name","note"],
  Admins: ["email","community","note"],
  Invites: ["email","community","invitedBy","invitedAt","token","joinedAt","label","joins"],
  FeedbackPrivate: ["DO_NOT_USE"]
};

function doGet() {
  // Opening the /exec address in a browser shows which backend version is published.
  return ContentService.createTextOutput(JSON.stringify({ok:true,app:"Padel Community",version:BACKEND_VERSION})).setMimeType(ContentService.MimeType.JSON);
}

const BACKEND_VERSION = "2026-10-26.7";
/** Version of the privacy notice shown in the app: bump it when the text changes to ask for consent again. */
const CONSENT_VERSION = "2026-10-26";
/** Name of this community; override with the COMMUNITY_NAME script property when another community gets its own backend. */
const DEFAULT_COMMUNITY = "Telespadel";
const GENDERS = ["male","female","other"];
const API_METHODS = ["getAppData","saveProfile","createMatch","registerForMatch","cancelRegistration","completeMatch","cancelMatch","setPartner","setLineup","resetAllData","inviteToCommunity","createCommunityLink","lookupEmail","createShareLink","trackOpen","respondToLink","forgetDevice"];

/** JSON API for the static front end (web/). Body is text/plain JSON to avoid a CORS preflight. */
var CURRENT_INVITE_TOKEN = "";
var CURRENT_DEVICE = "";
function doPost(e) {
  let out;
  try {
    const req = JSON.parse(e.postData.contents);
    CURRENT_INVITE_TOKEN = String(req.inviteToken || "").slice(0,80);
    CURRENT_DEVICE = String(req.device || "").slice(0,16);
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
  ["Players","Matches","Registrations","Shares","Devices","Communities","Admins","Invites"].forEach(function(name) {
    let sh = ss.getSheetByName(name);
    if (!sh) sh = ss.insertSheet(name);
    if (sh.getLastRow() === 0) {
      sh.getRange(1,1,1,HEADERS[name].length).setValues([HEADERS[name]]);
      sh.setFrozenRows(1);
      if (name === "Communities") sh.getRange(2,1,1,2).setValues([[communityName_(),"community attuale"]]);
      if (name === "Admins") {
        // First run: start from the old ADMIN_EMAILS property; from now on the sheet is the single list.
        const old = (PropertiesService.getScriptProperties().getProperty("ADMIN_EMAILS")||"").split(",").map(function(x){ return x.trim().toLowerCase(); }).filter(Boolean);
        if (old.length) sh.getRange(2,1,old.length,3).setValues(old.map(function(em){ return [em,communityName_(),"da ADMIN_EMAILS"]; }));
      }
    } else {
      // Width of the header row only: stray notes in far columns or lower rows must not break the check.
      const row1 = sh.getRange(1,1,1,sh.getMaxColumns()).getDisplayValues()[0].map(function(v){ return String(v).trim(); });
      let existingCount = row1.length;
      while (existingCount > 0 && !row1[existingCount-1]) existingCount--;
      const first = row1.slice(0,existingCount);
      const expectedPrefix = HEADERS[name].slice(0,existingCount);
      if (existingCount === 0 || existingCount > HEADERS[name].length || first.join("|") !== expectedPrefix.join("|"))
        throw new Error("Intestazioni non compatibili nella scheda "+name+". Trovate: ["+first.join(", ")+"]. Attese: ["+HEADERS[name].join(", ")+"]. Non è stato modificato nulla. Se la scheda contiene solo dati di prova, eliminala (clic destro sulla scheda → Elimina) e riesegui setupPadelCommunity.");
      if (existingCount < HEADERS[name].length) {
        sh.getRange(1,existingCount+1,1,HEADERS[name].length-existingCount).setValues([HEADERS[name].slice(existingCount)]);
      }
      sh.setFrozenRows(1);
    }
  });
  applyLookups_(ss);
  return "Struttura pronta. Ora configura GOOGLE_CLIENT_ID nelle Proprietà script. Gli amministratori si gestiscono nella scheda Admins.";
}

/** Drop-down lists in the sheet so addresses and community names are picked, not typed: no typos. */
function applyLookups_(ss) {
  try {
    const players = ss.getSheetByName("Players"), comms = ss.getSheetByName("Communities"), admins = ss.getSheetByName("Admins"), invites = ss.getSheetByName("Invites");
    const rule = function(range, msg) { return SpreadsheetApp.newDataValidation().requireValueInRange(range, true).setAllowInvalid(false).setHelpText(msg).build(); };
    if (admins && players) admins.getRange("A2:A1000").setDataValidation(rule(players.getRange("C2:C1000"), "Scegli un indirizzo dalla scheda Players (la persona deve essere già nella community)."));
    if (admins && comms) admins.getRange("B2:B1000").setDataValidation(rule(comms.getRange("A2:A100"), "Scegli una community dalla scheda Communities."));
    if (invites && comms) invites.getRange("B2:B1000").setDataValidation(rule(comms.getRange("A2:A100"), "Scegli una community dalla scheda Communities."));
  } catch(err) { console.log("Elenchi a tendina non applicati: " + err); }
}
function communityName_() { return PropertiesService.getScriptProperties().getProperty("COMMUNITY_NAME") || DEFAULT_COMMUNITY; }
/** Admins live in the "Admins" sheet (column email; column community empty or equal to this community). Until that sheet has rows, the old ADMIN_EMAILS property still works. */
function isAdminEmail_(email) {
  let rows = null;
  try { rows = readRows_("Admins"); } catch(e) {}
  if (rows && rows.length) {
    const c = communityName_().toLowerCase();
    return rows.some(function(r){ const rc = String(r.community||"").trim().toLowerCase(); return String(r.email||"").trim().toLowerCase() === email && (!rc || rc === c); });
  }
  return (PropertiesService.getScriptProperties().getProperty("ADMIN_EMAILS")||"").split(",").map(function(s){ return s.trim().toLowerCase(); }).filter(Boolean).indexOf(email) >= 0;
}
function readInvites_() { try { return readRows_("Invites"); } catch(e) { return []; } }
function hasCommunityInvite_(email) {
  const c = communityName_().toLowerCase();
  return readInvites_().some(function(r){ return String(r.community||"").toLowerCase() === c && ((CURRENT_INVITE_TOKEN && String(r.token) === CURRENT_INVITE_TOKEN) || String(r.email||"").trim().toLowerCase() === email); });
}
function communityLink_(token) {
  const base = PropertiesService.getScriptProperties().getProperty("APP_URL") || DEFAULT_APP_URL;
  return base + "?community=" + encodeURIComponent(communityName_()) + "&t=" + encodeURIComponent(token);
}
function sendCommunityInvite_(email, token, inviterName) {
  const c = communityName_(), link = communityLink_(token);
  mail_(email, "🎾 " + inviterName + " ti invita nella community " + c,
    "<p>Ciao,</p><p><b>" + esc_(inviterName) + "</b> ti invita a entrare nella community di padel <b>" + esc_(c) + "</b>: qui si organizzano le partite e si vede chi c'è.</p>" +
    "<p><a href=\"" + esc_(link) + "\">Entra in " + esc_(c) + "</a>, <b>accedi con Google</b> e compila il tuo profilo (nome, livello, lato preferito). Va bene qualsiasi account Google, anche diverso da questo indirizzo (" + esc_(email) + "): il link riconosce il tuo invito.</p>" +
    "<p style=\"color:#666;font-size:13px\">Non serve una Gmail: se non hai un account Google puoi crearne uno con un indirizzo email già tuo: <a href=\"https://accounts.google.com/signup\">accounts.google.com/signup</a>.</p>");
}
/** Admin only: invites people to the community without any match. */
function inviteToCommunity(idToken,input) {
  const user = verifyUser_(idToken); input = input || {};
  if (!user.isAdmin) throw new Error("Solo un amministratore può invitare nella community.");
  const raw = Array.isArray(input.emails) ? input.emails : String(input.emails||"").split(/[\s,;]+/);
  const emails = []; const seen = {};
  raw.forEach(function(x){ const e = String(x||"").trim().toLowerCase(); if (e && !seen[e]) { seen[e] = 1; emails.push(e); } });
  if (!emails.length) throw new Error("Scrivi almeno un indirizzo email.");
  if (emails.length > 20) throw new Error("Massimo 20 indirizzi per volta.");
  const lock = LockService.getScriptLock(); lock.waitLock(10000);
  try {
    const members = {}; readRows_("Players").forEach(function(r){ const e = String(r.email||"").trim().toLowerCase(); if (e) members[e] = 1; });
    const invites = readInvites_(), c = communityName_(), sh = sheet_("Invites");
    const me = readRows_("Players").find(function(r){ return String(r.playerId) === user.playerId; });
    const inviter = me ? String(me.displayName||"") : "Un amministratore";
    const out = {sent:[],resent:[],already:[],invalid:[],noQuota:[]};
    emails.forEach(function(e) {
      if (!/^[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+$/.test(e)) { out.invalid.push(e); return; }
      if (members[e]) { out.already.push(e); return; }
      let quota = 1; try { quota = MailApp.getRemainingDailyQuota(); } catch(err) {}
      if (quota < 1) { out.noQuota.push(e); return; }
      const old = invites.find(function(r){ return String(r.community||"").toLowerCase() === c.toLowerCase() && String(r.email||"").trim().toLowerCase() === e; });
      if (old) { sendCommunityInvite_(e, String(old.token), inviter); out.resent.push(e); return; }
      const token = Utilities.getUuid();
      sh.appendRow([e, c, user.playerId, new Date(), token, "", "", 0]);
      sendCommunityInvite_(e, token, inviter);
      out.sent.push(e);
    });
    const parts = [];
    if (out.sent.length) parts.push(out.sent.length + " inviti inviati");
    if (out.resent.length) parts.push(out.resent.length + " inviti rimandati");
    if (out.already.length) parts.push(out.already.length + " già nella community");
    if (out.invalid.length) parts.push(out.invalid.length + " indirizzi non validi (" + out.invalid.join(", ") + ")");
    if (out.noQuota.length) parts.push(out.noQuota.length + " non inviati: limite giornaliero di email raggiunto");
    return {message: parts.join(", ") + ".", result: out};
  } finally {
    lock.releaseLock();
  }
}
/** Admin only: a link for WhatsApp / QR / copy, usable by many people (no email needed). */
function createCommunityLink(idToken,input) {
  const user = verifyUser_(idToken); input = input || {};
  if (!user.isAdmin) throw new Error("Solo un amministratore può creare un link di invito.");
  const label = clean_(input.label,40) || "Link community";
  const token = Utilities.getUuid();
  sheet_("Invites").appendRow(["", communityName_(), user.playerId, new Date(), token, "", label, 0]);
  return {token:token,label:label,url:communityLink_(token)};
}
/** Called when a profile is saved: single-address invites become "joined"; a shared link counts one more person (only for a brand new profile). */
function markInviteJoined_(user,isNew) {
  try {
    const sh = sheet_("Invites");
    readInvites_().forEach(function(r){
      const byToken = !!CURRENT_INVITE_TOKEN && String(r.token) === CURRENT_INVITE_TOKEN, byEmail = !!String(r.email||"").trim() && String(r.email).trim().toLowerCase() === user.email;
      if (!byToken && !byEmail) return;
      approveEmail_(user.email);
      if (String(r.email||"").trim()) { if (!String(r.joinedAt||"")) sh.getRange(r._row, 6).setValue(new Date()); }
      else if (isNew) { sh.getRange(r._row, 8).setValue((Number(r.joins)||0)+1); if (!String(r.joinedAt||"")) sh.getRange(r._row, 6).setValue(new Date()); }
    });
  } catch(e) {}
}

function getPublicConfig() {
  const p = PropertiesService.getScriptProperties();
  return {googleClientId:p.getProperty("GOOGLE_CLIENT_ID") || "", configured:!!p.getProperty("GOOGLE_CLIENT_ID")};
}

function getAppData(idToken) {
  const user = verifyUser_(idToken);
  claimShare_(user);
  rememberDevice_(user);
  const players = readRows_("Players").filter(r => r.playerId && truthy_(r.active)).map(function(r) {
    return {playerId:String(r.playerId),displayName:String(r.displayName || "Giocatore"),skillLevel:String(r.skillLevel || "Da definire"),preferredSide:String(r.preferredSide || "indifferent"),photoUrl:safePhoto_(r.photoUrl),active:true};
  });
  const registrations = readRows_("Registrations").filter(r => r.registrationId && String(r.status) === "joined").map(function(r) {
    return {registrationId:String(r.registrationId),matchId:String(r.matchId),playerId:String(r.playerId),status:String(r.status),partnerId:String(r.partnerId || "")};
  });
  const matches = readRows_("Matches").filter(r => r.matchId && String(r.status) !== "cancelled").map(function(r) {
    return {matchId:String(r.matchId),dateTime:iso_(r.dateTime),venue:String(r.venue || ""),status:String(r.status || "open"),notes:String(r.notes || ""),createdBy:String(r.createdBy || ""),lineup:publicLineup_(parseLineup_(r.lineup),user,r.createdBy),registeredCount:0};
  });
  const counts = {};
  registrations.forEach(r => counts[r.matchId]=(counts[r.matchId]||0)+1);
  const sharesBy=sharesByMatch_(user,players);
  matches.forEach(m => { m.shares=(sharesBy[m.matchId]||[]).filter(sh=>user.isAdmin||m.createdBy===user.playerId||sh.mine); m.registeredCount=counts[m.matchId]||0; m.seatsTaken=m.lineup?m.lineup.filter(x=>x.playerId||x.name).length:m.registeredCount; });
  const mine = players.find(p => p.playerId === user.playerId) || null;
  if (mine) { const row=readRows_("Players").find(r=>String(r.playerId)===user.playerId); mine.gender=row?String(row.gender||""):""; mine.consentAt=row&&row.consentAt?iso_(row.consentAt):""; mine.consentOk=!!row&&profileComplete_(row); mine.complete=mine.consentOk; }
  const inviteStatus=!CURRENT_INVITE_TOKEN?"":(matches.some(m=>m.lineup&&m.lineup.some(x=>x.mine&&!x.playerId))?"ok":(readInvites_().some(r=>String(r.token)===CURRENT_INVITE_TOKEN)?"community":"used"));
  const invites=user.isAdmin?readInvites_().map(r=>({email:String(r.email||""),invitedAt:iso_(r.invitedAt),joined:!!String(r.joinedAt||""),label:String(r.label||""),joins:Number(r.joins)||0,link:String(r.email||"").trim()?"":communityLink_(String(r.token))})):[];
  return {user:{email:user.email,playerId:user.playerId,isAdmin:user.isAdmin},community:communityName_(),communityInvites:invites,me:mine,players:players,matches:matches,registrations:registrations,inviteStatus:inviteStatus};
}

function saveProfile(idToken, input) {
  const user = verifyUser_(idToken);
  input = input || {};
  const name = clean_(input.displayName,80);
  const level = clean_(input.skillLevel,30);
  const side = clean_(input.preferredSide,20);
  const allowedLevels = ["Bronze","Silver","Silver-Gold","Gold","Gold+"];
  const gender = clean_(input.gender,10);
  if (!name || allowedLevels.indexOf(level)<0 || ["right","left","indifferent"].indexOf(side)<0)
    throw new Error("Inserisci nome, livello e lato preferito.");
  if (GENDERS.indexOf(gender)<0) throw new Error("Scegli maschio, femmina o altro.");
  const sh=sheet_("Players"), rows=readRows_("Players");
  const existing=rows.find(r=>String(r.playerId)===user.playerId);
  const hasConsent=existing&&String(existing.consentVersion||"")===CONSENT_VERSION&&existing.consentAt;
  if (!hasConsent&&input.gdpr!==true) throw new Error("Per salvare il profilo devi accettare l'informativa privacy.");
  const photo=input.showPhoto===true?safePhoto_(user.picture):"";
  const consentAt=hasConsent?existing.consentAt:new Date();
  const values=[user.playerId,name,user.email,level,side,true,existing?existing.createdAt:new Date(),new Date(),photo,gender,consentAt,CONSENT_VERSION];
  if(existing) sh.getRange(existing._row,1,1,values.length).setValues([values]); else sh.appendRow(values);
  markInviteJoined_(user,!existing);
  return {message:"Profilo salvato.",playerId:user.playerId};
}

function createMatch(idToken,input) {
  const user=verifyUser_(idToken); input=input||{};
  const profile=requireProfile_(user);
  const venue=clean_(input.venue,120), dateText=clean_(input.dateTime,80), notes=clean_(input.notes,500);
  if(!venue||!dateText) throw new Error("Inserisci campo e data/ora.");
  const date=new Date(dateText); if(isNaN(date.getTime())||date.getTime()<Date.now()-60000) throw new Error("Scegli una data futura valida.");
  const lineup=buildLineup_(input.lineup,user,profile,null,null);
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
  sheet_("Matches").appendRow([id,date,venue,user.playerId,"open",notes,created,eventId,JSON.stringify(lineup)]);
  sheet_("Registrations").appendRow([Utilities.getUuid(),id,user.playerId,"joined",created,""]);
  sendInvites_({matchId:id,venue:venue,date:date},profile.displayName,lineup.newInvites);
  sendEmailInvites_({matchId:id,venue:venue,date:date},profile.displayName,lineup.newEmailInvites);
  sendOrganizerSummary_({matchId:id,venue:venue,date:date},user.email,profile.displayName,lineup);
  return {matchId:id,message:calendarId?"Partita creata e aggiunta al calendario.":"Partita creata. Calendar non è ancora configurato."};
}

function registerForMatch(idToken,input) {
  const user=verifyUser_(idToken); input=input||{};
  const profile=requireProfile_(user);
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
    const lineup=parseLineup_(match.lineup);
    let slot=-1;
    if(lineup) {
      slot=lineup.findIndex(x=>x.playerId===user.playerId);
      if(slot<0) { slot=lineup.findIndex(x=>x.email&&(x.email===user.email||(CURRENT_INVITE_TOKEN&&x.token===CURRENT_INVITE_TOKEN))); if(slot>=0) { approveEmail_(user.email); lineup[slot]={playerId:user.playerId,name:String(profile.displayName||""),invitedAt:"",reminded:false,email:"",token:""}; sheet_("Matches").getRange(match._row,9).setValue(JSON.stringify(lineup)); } }
      if(slot<0) { slot=lineup.findIndex(x=>!x.playerId&&!x.email&&x.name&&sameName_(x.name,profile.displayName)); if(slot>=0) { lineup[slot]={playerId:user.playerId,name:String(profile.displayName||""),invitedAt:"",reminded:false,email:"",token:""}; sheet_("Matches").getRange(match._row,9).setValue(JSON.stringify(lineup)); } }
      if(slot<0) { slot=pickSlot_(lineup,String(profile.preferredSide||"")); if(slot<0) throw new Error("La partita è già completa."); lineup[slot]={playerId:user.playerId,name:String(profile.displayName||""),invitedAt:"",reminded:false,email:"",token:""}; sheet_("Matches").getRange(match._row,9).setValue(JSON.stringify(lineup)); }
    } else if(active.length>=4) throw new Error("La partita è già completa.");
    sheet_("Registrations").appendRow([Utilities.getUuid(),matchId,user.playerId,"joined",new Date(),""]);
    notifyJoin_(match,profile,user);
    return {message:"Iscrizione registrata."};
  } finally {
    lock.releaseLock();
  }
}

/** A guest typed by the organizer ("Massimiliano") is the same person as a player who registers as "Massimiliano" or "Massimiliano R.". */
function normName_(t) { return String(t||"").toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g,"").replace(/[^a-z0-9 ]/g," ").replace(/\s+/g," ").trim(); }
function sameName_(a,b) {
  a=normName_(a); b=normName_(b); if(!a||!b) return false;
  if(a===b) return true;
  return a.length>=3&&b.length>=3&&(b.indexOf(a+" ")===0||a.indexOf(b+" ")===0);
}
/** Tells the organizer that somebody took a seat (not for the organizer's own registration). */
function notifyJoin_(match,profile,user) {
  try {
    if(String(match.createdBy)===user.playerId) return;
    const org=playerMap_()[String(match.createdBy)]; if(!org||!org.email) return;
    const info={matchId:String(match.matchId),venue:String(match.venue),date:new Date(match.dateTime)};
    const lu=parseLineup_(sheet_("Matches").getRange(match._row,9).getValue()), taken=lu?lu.filter(x=>x.playerId||x.name||x.email).length:0;
    mail_(org.email,"✅ "+profile.displayName+" ha accettato: partita di padel del "+whenText_(info.date),
      "<p>Ciao "+esc_(org.name)+",</p><p><b>"+esc_(profile.displayName)+"</b> si è iscritto alla partita di <b>"+esc_(info.venue)+"</b>, "+esc_(whenText_(info.date))+".</p>"+(lu?"<p>Posti occupati: "+taken+" su 4.</p>":"")+"<p><a href=\""+esc_(appLink_(info))+"\">Apri la partita</a></p>");
  } catch(err) { console.log("Notifica iscrizione non inviata: "+err); }
}
/** Tells everybody who is registered that the match has been marked as completed (feedback can now be left). */
function notifyCompleted_(row) {
  try {
    const pm=playerMap_(), info={matchId:String(row.matchId),venue:String(row.venue),date:new Date(row.dateTime)};
    readRows_("Registrations").filter(r=>String(r.matchId)===info.matchId&&String(r.status)==="joined").forEach(function(r){
      const p=pm[String(r.playerId)]; if(!p||!p.email) return;
      mail_(p.email,"🎾 Partita conclusa: lascia il tuo feedback",
        "<p>Ciao "+esc_(p.name)+",</p><p>la partita di <b>"+esc_(info.venue)+"</b>, "+esc_(whenText_(info.date))+", è stata segnata come conclusa.</p><p><a href=\""+esc_(appLink_(info))+"\">Apri la partita</a> e lascia il tuo feedback privato sui compagni: resta nel tuo Google Drive.</p>");
    });
  } catch(err) { console.log("Notifica partita conclusa non inviata: "+err); }
}

function cancelRegistration(idToken,input) {
  const user=verifyUser_(idToken); const matchId=clean_(input&&input.matchId,80);
  const sh=sheet_("Registrations"), regs=readRows_("Registrations");
  const row=regs.find(r=>String(r.matchId)===matchId&&String(r.playerId)===user.playerId&&String(r.status)==="joined");
  if(!row) throw new Error("Non risulti iscritto a questa partita.");
  sh.getRange(row._row,4).setValue("cancelled");
  sh.getRange(row._row,6).setValue("");
  regs.filter(r=>String(r.matchId)===matchId&&String(r.partnerId||"")===user.playerId).forEach(r=>sh.getRange(r._row,6).setValue(""));
  const mrow=readRows_("Matches").find(r=>String(r.matchId)===matchId), lu=mrow&&parseLineup_(mrow.lineup);
  if(lu) { const i=lu.findIndex(x=>x.playerId===user.playerId); if(i>=0) { lu[i]={playerId:"",name:"",invitedAt:"",reminded:false,email:"",token:""}; sheet_("Matches").getRange(mrow._row,9).setValue(JSON.stringify(lu)); } }
  return {message:"Iscrizione annullata."};
}

function setLineup(idToken,input) {
  const user=verifyUser_(idToken); input=input||{};
  const matchId=clean_(input.matchId,80);
  const lock=LockService.getScriptLock();
  lock.waitLock(10000);
  try {
    const row=readRows_("Matches").find(r=>String(r.matchId)===matchId);
    if(!row||String(row.status)==="cancelled") throw new Error("Partita non trovata.");
    if(!user.isAdmin&&String(row.createdBy)!==user.playerId) throw new Error("Solo chi ha proposto la partita può cambiare la formazione.");
    if(String(row.status)==="completed") throw new Error("La partita è già conclusa.");
    const joined=readRows_("Registrations").filter(r=>String(r.matchId)===matchId&&String(r.status)==="joined").map(r=>String(r.playerId));
    const lineup=buildLineup_(input.lineup,{playerId:String(row.createdBy)},null,joined,parseLineup_(row.lineup));
    sheet_("Matches").getRange(row._row,9).setValue(JSON.stringify(lineup));
    const ownerRow=readRows_("Players").find(r=>String(r.playerId)===String(row.createdBy));
    sendInvites_({matchId:String(row.matchId),venue:String(row.venue),date:new Date(row.dateTime)},ownerRow?String(ownerRow.displayName):"L'organizzatore",lineup.newInvites.filter(id=>joined.indexOf(id)<0));
    sendEmailInvites_({matchId:String(row.matchId),venue:String(row.venue),date:new Date(row.dateTime)},ownerRow?String(ownerRow.displayName):"L'organizzatore",lineup.newEmailInvites);
    return {message:"Formazione aggiornata."};
  } finally {
    lock.releaseLock();
  }
}

const DEFAULT_APP_URL = "https://pierfrac.github.io/padel-community-app/";
const INVITE_REMINDER_AFTER_MS = 24*60*60*1000;
const REMINDER_MIN_DAYS_LEFT = 4;

function esc_(t) { return String(t==null?"":t).replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c])); }
function appLink_(m,token) {
  const base=PropertiesService.getScriptProperties().getProperty("APP_URL")||DEFAULT_APP_URL;
  return base+"?match="+encodeURIComponent(m.matchId)+"&v="+encodeURIComponent(m.venue)+"&d="+encodeURIComponent(new Date(m.date).toISOString())+(token?"&t="+encodeURIComponent(token):"");
}
function whenText_(d) { return Utilities.formatDate(new Date(d),Session.getScriptTimeZone(),"dd/MM/yyyy 'alle' HH:mm"); }
function mail_(to,subject,html) {
  try { if(!to) return; MailApp.sendEmail({to:String(to),subject:subject,htmlBody:html,name:"Padel Community"}); }
  catch(err) { console.log("Email non inviata a "+to+": "+err); }
}
function playerMap_() {
  const map={}; readRows_("Players").forEach(r=>{ map[String(r.playerId)]={name:String(r.displayName||""),email:String(r.email||"")}; }); return map;
}
function sendEmailInvites_(match,organizerName,invites) {
  if(!invites||!invites.length) return;
  try {
    invites.forEach(function(inv){ const email=inv.email, link=appLink_(match,inv.token);
      mail_(email,"🎾 "+organizerName+" ti ha invitato a una partita di padel",
        "<p>Ciao,</p><p><b>"+esc_(organizerName)+"</b> ti ha invitato a una partita di padel:</p>"+
        "<p><b>"+esc_(match.venue)+"</b><br>"+esc_(whenText_(match.date))+"</p>"+
        "<p>Ti abbiamo riservato un posto. Per prenderlo: <a href=\""+esc_(link)+"\">apri la partita</a>, <b>accedi con Google</b>, salva il tuo profilo (nome, livello e lato preferito) e premi “Accetta invito”. Puoi usare qualsiasi account Google, anche diverso da questo indirizzo ("+esc_(email)+"): il link riconosce il tuo invito.</p>"+
        "<p style=\"color:#666;font-size:13px\">Non serve una Gmail: va bene qualsiasi account Google (anche di lavoro o scuola). Se non ne hai uno, puoi crearne uno con questo stesso indirizzo email o con un altro: <a href=\"https://accounts.google.com/signup\">accounts.google.com/signup</a> (scegli «Usa il mio indirizzo email attuale»).</p>"+
        "<p style=\"color:#666;font-size:13px\">Se non rispondi entro 24 ore: se la partita è tra più di "+REMINDER_MIN_DAYS_LEFT+" giorni ti mandiamo un promemoria, altrimenti il posto viene liberato e l'organizzatore viene avvisato.</p>");
    });
  } catch(err) { console.log("Inviti email non inviati: "+err); }
}
function sendInvites_(match,organizerName,playerIds) {
  if(!playerIds||!playerIds.length) return;
  try { sendInvitesUnsafe_(match,organizerName,playerIds); }
  catch(err) { console.log("Inviti non inviati: "+err); }
}
function sendInvitesUnsafe_(match,organizerName,playerIds) {
  const pm=playerMap_();
  playerIds.forEach(function(id){
    const p=pm[id]; if(!p||!p.email) return;
    mail_(p.email,"🎾 "+organizerName+" ti ha invitato a una partita di padel",
      "<p>Ciao "+esc_(p.name)+",</p><p><b>"+esc_(organizerName)+"</b> ti ha invitato a una partita di padel:</p>"+
      "<p><b>"+esc_(match.venue)+"</b><br>"+esc_(whenText_(match.date))+"</p>"+
      "<p>Ti abbiamo riservato un posto. <a href=\""+esc_(appLink_(match))+"\">Apri la partita e premi “Accetta invito”</a>.</p>"+
      "<p style=\"color:#666;font-size:13px\">Se non rispondi entro 24 ore: se la partita è tra più di "+REMINDER_MIN_DAYS_LEFT+" giorni ti mandiamo un promemoria, altrimenti il posto viene liberato e l'organizzatore viene avvisato.</p>");
  });
}

/** Rules and management info, used in the organizer email (same content as the in-app popup). */
function manageInfoHtml_() {
  return "<p><b>Inviti</b><br>Chi inviti dalla community riceve un'email e un posto riservato. Se non risponde entro 24 ore: con la partita a più di "+REMINDER_MIN_DAYS_LEFT+" giorni gli arriva un promemoria; con la partita entro "+REMINDER_MIN_DAYS_LEFT+" giorni l'invito viene annullato, il posto torna libero e ricevi un avviso.</p>"+
    "<p><b>Gestione</b><br>Dalla scheda della partita puoi usare “Modifica formazione” (cambia i posti, ma non chi è già iscritto), “Segna conclusa” (dopo l'orario di fine) e “Annulla partita”.</p>"+
    "<p><b>Cancellazioni</b><br>Chi è iscritto può annullare la propria iscrizione: il posto si libera. Se annulli la partita sparisce dall'elenco per tutti.</p>"+
    "<p><b>Feedback</b><br>Dopo “Segna conclusa” ogni iscritto può lasciare un feedback privato sui compagni, che resta nel suo Google Drive.</p>";
}
function sendOrganizerSummary_(match,email,organizerName,lineup) {
  try {
    const slots=lineup.map(function(x,i){ const side=i%2===0?"destra":"sinistra", who=x.email?esc_(x.email)+" (invitato via email)":x.playerId?esc_(x.name)+(x.invitedAt?" (invitato)":" (tu)"):(x.name?esc_(x.name)+" (ospite)":"libero"); return "Coppia "+(Math.floor(i/2)+1)+", "+side+": "+who; });
    mail_(email,"🎾 Hai creato una partita di padel: "+match.venue,
      "<p>Ciao "+esc_(organizerName)+",</p><p>la tua partita è stata creata:</p><p><b>"+esc_(match.venue)+"</b><br>"+esc_(whenText_(match.date))+"</p><p>"+slots.join("<br>")+"</p>"+
      "<p><a href=\""+esc_(appLink_(match))+"\">Apri la partita</a></p><hr>"+manageInfoHtml_());
  } catch(err) { console.log("Email organizzatore non inviata: "+err); }
}

/** Run hourly (see installTriggers): after 24h without an answer, remind (match more than 4 days away) or release the seat and tell the organizer. */
function processInvites() {
  const lock=LockService.getScriptLock();
  lock.waitLock(20000);
  try {
    const now=Date.now(), DAY=24*60*60*1000, pm=playerMap_(), joined={};
    readRows_("Registrations").filter(r=>String(r.status)==="joined").forEach(r=>{ joined[String(r.matchId)+"|"+String(r.playerId)]=1; });
    const msh=sheet_("Matches");
    readRows_("Matches").forEach(function(m){
      const status=String(m.status); if(status==="cancelled"||status==="completed") return;
      const lineup=parseLineup_(m.lineup); if(!lineup) return;
      const start=new Date(m.dateTime).getTime(); if(isNaN(start)||start<now) return;
      const matchId=String(m.matchId), info={matchId:matchId,venue:String(m.venue),date:new Date(m.dateTime)};
      let changed=false;
      lineup.forEach(function(s,i){
        if((!s.playerId&&!s.email)||s.playerId===String(m.createdBy)||(s.playerId&&joined[matchId+"|"+s.playerId])||!s.invitedAt||s.reminded) return;
        const age=now-new Date(s.invitedAt).getTime(); if(isNaN(age)||age<INVITE_REMINDER_AFTER_MS) return;
        const invitee=s.email?{name:s.email,email:s.email}:(pm[s.playerId]||{name:s.name,email:""}), org=pm[String(m.createdBy)]||{name:"",email:""};
        if((start-now)/DAY>REMINDER_MIN_DAYS_LEFT) {
          s.reminded=true; changed=true;
          mail_(invitee.email,"⏰ Promemoria: hai un invito a una partita di padel",
            "<p>Ciao "+esc_(invitee.name)+",</p><p>hai ancora un posto riservato per la partita di <b>"+esc_(info.venue)+"</b>, "+esc_(whenText_(info.date))+".</p><p><a href=\""+esc_(appLink_(info,s.token))+"\">Apri la partita e premi “Accetta invito”</a>.</p>");
        } else {
          lineup[i]={playerId:"",name:"",invitedAt:"",reminded:false,email:"",token:""}; changed=true;
          mail_(org.email,"Invito scaduto: "+invitee.name+" non ha risposto",
            "<p>Ciao "+esc_(org.name)+",</p><p><b>"+esc_(invitee.name)+"</b> non ha risposto all'invito per la partita di <b>"+esc_(info.venue)+"</b>, "+esc_(whenText_(info.date))+". La partita è tra meno di "+REMINDER_MIN_DAYS_LEFT+" giorni, quindi l'invito è stato annullato e il posto è di nuovo libero.</p><p><a href=\""+esc_(appLink_(info))+"\">Apri la partita</a> per invitare qualcun altro.</p>");
          mail_(invitee.email,"Invito annullato: partita di padel del "+whenText_(info.date),
            "<p>Ciao "+esc_(invitee.name)+",</p><p>l'invito alla partita di <b>"+esc_(info.venue)+"</b> è stato annullato perché non hai risposto in tempo. Se vuoi ancora giocare, <a href=\""+esc_(appLink_(info))+"\">controlla se c'è un posto libero</a>.</p>");
        }
      });
      if(changed) msh.getRange(m._row,9).setValue(JSON.stringify(lineup));
    });
  } finally {
    lock.releaseLock();
  }
}

/** Run once from the editor: creates the hourly trigger and asks for the mail/trigger permissions. */
function installTriggers() {
  ScriptApp.getProjectTriggers().filter(t=>t.getHandlerFunction()==="processInvites").forEach(t=>ScriptApp.deleteTrigger(t));
  ScriptApp.newTrigger("processInvites").timeBased().everyHours(1).create();
  return "Controllo inviti attivato: ogni ora.";
}

/** Free seat that fits the player: right = positions 0 and 2, left = 1 and 3; indifferent players fit anywhere; if no fitting seat is left, any free seat. */
function pickSlot_(lineup,side) {
  const free=[0,1,2,3].filter(i=>!lineup[i].playerId&&!lineup[i].name);
  if(!free.length) return -1;
  if(side==="right"||side==="left") { const fit=free.filter(i=>(i%2===0?"right":"left")===side); if(fit.length) return fit[0]; }
  return free[0];
}

function publicLineup_(lu,user,createdBy) {
  if(!lu) return null;
  const owner=user.isAdmin||String(createdBy)===user.playerId;
  return lu.map(x=>({playerId:x.playerId,name:x.name,emailInvite:!!x.email,mine:!!(x.email&&(x.email===user.email||(CURRENT_INVITE_TOKEN&&x.token===CURRENT_INVITE_TOKEN))),email:owner?x.email:"",openedAt:owner?x.openedAt:"",opens:owner?x.opens:0}));
}
/** Personal share link: lets the sharer see who opens it. Members only. */
function createShareLink(idToken,input) {
  const user=verifyUser_(idToken); input=input||{};
  requireProfile_(user);
  const matchId=clean_(input.matchId,80), label=clean_(input.label,40), kind=input.kind==="group"?"group":"personal";
  if(!label) throw new Error(kind==="group"?"Scrivi il nome della chat o del gruppo.":"Scrivi il nome della persona a cui mandi il link.");
  const m=readRows_("Matches").find(r=>String(r.matchId)===matchId&&String(r.status)!=="cancelled");
  if(!m) throw new Error("Partita non trovata.");
  let rows; try { rows=readRows_("Shares"); } catch(e) { throw new Error("Aggiorna il foglio: esegui setupPadelCommunity."); }
  if(rows.filter(r=>String(r.matchId)===matchId&&String(r.createdBy)===user.playerId).length>=40) throw new Error("Hai già creato troppi link per questa partita.");
  const id=Utilities.getUuid(), token=Utilities.getUuid();
  sheet_("Shares").appendRow([id,matchId,token,label,user.playerId,new Date(),"","",0,"[]","","",kind,"[]"]);
  return {shareId:id,token:token,kind:kind};
}
/** Public (no login): records that a link was opened, with an anonymous device id, so the sharer can see who read it. */
function trackOpen(idToken,input) {
  input=input||{};
  const token=clean_(input.token,80), device=clean_(input.device,60).slice(0,16);
  if(!token) return {valid:false};
  const lock=LockService.getScriptLock();
  lock.waitLock(10000);
  try {
    const now=new Date(), nowIso=now.toISOString(), pm=playerMap_();
    let row=null; try { row=readRows_("Shares").find(r=>String(r.token)===token); } catch(e) {}
    if(row) {
      const sh=sheet_("Shares"); let devs=[]; try { devs=JSON.parse(String(row.devices||"[]")); } catch(e) {}
      if(device&&devs.indexOf(device)<0&&devs.length<500) devs.push(device);
      if(!row.openedAt) sh.getRange(row._row,7).setValue(now);
      sh.getRange(row._row,8).setValue(now); sh.getRange(row._row,9).setValue((Number(row.opens)||0)+1); sh.getRange(row._row,10).setValue(JSON.stringify(devs));
      const org=pm[String(row.createdBy)], resp=parseResponses_(row.responses), known=knownDevice_(device,pm), isGroup=String(row.kind||"personal")==="group";
      let mineR=device?resp.find(x=>x.device===device):null;
      if(known&&known.playerId!==String(row.createdBy)) {
        if(isGroup) {
          let e=resp.find(x=>x.playerId===known.playerId)||mineR;
          if(!e) { if(resp.length<300) { resp.push({name:known.name,answer:"",at:nowIso,device:device,playerId:known.playerId}); sh.getRange(row._row,14).setValue(JSON.stringify(resp)); } }
          else if(!e.playerId) { e.playerId=known.playerId; sh.getRange(row._row,14).setValue(JSON.stringify(resp)); }
          mineR=resp.find(x=>x.playerId===known.playerId)||mineR;
        } else if(!String(row.playerId||"")) { sh.getRange(row._row,11).setValue(known.playerId); sh.getRange(row._row,12).setValue(now); }
      }
      return {valid:true,kind:"share",shareKind:isGroup?"group":"personal",label:String(row.label||""),organizer:org?org.name:"",mine:mineR&&mineR.answer?{name:mineR.name,answer:mineR.answer}:null,known:known?{name:known.name}:null};
    }
    const ms=sheet_("Matches");
    const found=readRows_("Matches").find(m=>{ const lu=parseLineup_(m.lineup); return lu&&lu.some(x=>x.token&&x.token===token); });
    if(found) {
      const lu=parseLineup_(found.lineup), i=lu.findIndex(x=>x.token===token);
      if(!lu[i].openedAt) lu[i].openedAt=nowIso;
      lu[i].opens=(lu[i].opens||0)+1;
      ms.getRange(found._row,9).setValue(JSON.stringify(lu));
      const org=pm[String(found.createdBy)];
      return {valid:true,kind:"email",label:"",organizer:org?org.name:"",known:(function(){ const k=knownDevice_(device,pm); return k?{name:k.name}:null; })()};
    }
    return {valid:false};
  } finally {
    lock.releaseLock();
  }
}
/** A device that has logged in once is remembered, so later link opens can recognise the person without a login. */
function rememberDevice_(user) {
  if(!CURRENT_DEVICE) return;
  try {
    const sh=sheet_("Devices"), r=readRows_("Devices").find(x=>String(x.deviceId)===CURRENT_DEVICE);
    if(r) { if(String(r.playerId)!==user.playerId) sh.getRange(r._row,2).setValue(user.playerId); sh.getRange(r._row,4).setValue(new Date()); }
    else sh.appendRow([CURRENT_DEVICE,user.playerId,new Date(),new Date()]);
  } catch(e) {}
}
function knownDevice_(device,pm) {
  if(!device) return null;
  try {
    const r=readRows_("Devices").find(x=>String(x.deviceId)===device); if(!r) return null;
    const p=pm[String(r.playerId)]; return p?{playerId:String(r.playerId),name:p.name}:null;
  } catch(e) { return null; }
}
/** Public: "this is not me" - the device stops being recognised. */
function forgetDevice(idToken,input) {
  const device=clean_((input&&input.device)||"",60).slice(0,16);
  if(!device) return {forgotten:false};
  const lock=LockService.getScriptLock();
  lock.waitLock(10000);
  try {
    const r=readRows_("Devices").find(x=>String(x.deviceId)===device);
    if(r) { sheet_("Devices").deleteRows(r._row,1); return {forgotten:true}; }
    return {forgotten:false};
  } catch(e) { return {forgotten:false}; } finally { lock.releaseLock(); }
}
function parseResponses_(v) {
  try { const a=JSON.parse(String(v||"[]")); return Array.isArray(a)?a:[]; } catch(e) { return []; }
}
/** Public (no login): someone who opened a shared link says "I'm in" / "maybe" / "no" with a name, so the sharer sees who wants to play. One answer per device. */
function respondToLink(idToken,input) {
  input=input||{};
  const token=clean_(input.token,80), device=clean_(input.device,60).slice(0,16), name=clean_(input.name,40);
  const answer=["yes","maybe","no"].indexOf(input.answer)>=0?input.answer:"";
  if(!token||!answer) throw new Error("Risposta non valida.");
  const known=knownDevice_(device,playerMap_());
  if(!known&&name.length<2) throw new Error("Scrivi il tuo nome (almeno 2 lettere).");
  const lock=LockService.getScriptLock();
  lock.waitLock(10000);
  try {
    let row=null; try { row=readRows_("Shares").find(r=>String(r.token)===token); } catch(e) {}
    if(!row) throw new Error("Questo link non è più valido.");
    const resp=parseResponses_(row.responses);
    let e=(known?resp.find(x=>x.playerId===known.playerId):null)||(device?resp.find(x=>x.device===device):null);
    if(!e) { if(resp.length>=300) throw new Error("Troppe risposte per questo link."); e={name:name,answer:answer,at:"",device:device,playerId:""}; resp.push(e); }
    e.name=known?known.name:name; e.answer=answer; e.at=new Date().toISOString(); if(known) { e.playerId=known.playerId; e.device=device; }
    sheet_("Shares").getRange(row._row,14).setValue(JSON.stringify(resp));
    return {saved:true,count:resp.filter(x=>x.answer==="yes").length};
  } finally {
    lock.releaseLock();
  }
}
/** When a logged-in person arrives with a personal link, remember who they are (the first one only). */
function claimShare_(user) {
  if(!CURRENT_INVITE_TOKEN) return;
  try {
    const row=readRows_("Shares").find(r=>String(r.token)===CURRENT_INVITE_TOKEN);
    if(!row||String(row.createdBy)===user.playerId) return;
    const sh=sheet_("Shares");
    if(String(row.kind||"personal")==="group") {
      const resp=parseResponses_(row.responses);
      if(resp.some(x=>x.playerId===user.playerId)) return;
      const me=readRows_("Players").find(r=>String(r.playerId)===user.playerId);
      let e=CURRENT_DEVICE?resp.find(x=>x.device===CURRENT_DEVICE&&!x.playerId):null;
      if(e) { e.playerId=user.playerId; } else { if(resp.length>=300) return; resp.push({name:me?String(me.displayName||""):"",answer:"",at:new Date().toISOString(),device:CURRENT_DEVICE,playerId:user.playerId}); }
      sh.getRange(row._row,14).setValue(JSON.stringify(resp));
    } else if(!String(row.playerId||"")) { sh.getRange(row._row,11).setValue(user.playerId); sh.getRange(row._row,12).setValue(new Date()); }
  } catch(e) {}
}
function sharesByMatch_(user,players) {
  const out={};
  try {
    const names={}; players.forEach(p=>{ names[p.playerId]=p.displayName; });
    readRows_("Shares").forEach(function(r){
      let devs=[]; try { devs=JSON.parse(String(r.devices||"[]")); } catch(e) {}
      const mine=String(r.createdBy)===user.playerId, pid=String(r.playerId||"");
      (out[String(r.matchId)]=out[String(r.matchId)]||[]).push({shareId:String(r.shareId),label:String(r.label||""),mine:mine,token:mine?String(r.token):"",opens:Number(r.opens)||0,openedAt:iso_(r.openedAt),lastOpenAt:iso_(r.lastOpenAt),devices:devs.length,playerId:pid,who:pid?(names[pid]||"un giocatore"):"",createdBy:String(r.createdBy),kind:String(r.kind||"personal"),responses:parseResponses_(r.responses).map(x=>({name:String(x.name||""),answer:String(x.answer||""),playerId:String(x.playerId||""),who:x.playerId?(names[x.playerId]||""):"",at:String(x.at||"")}))});
    });
  } catch(e) {}
  return out;
}
function parseLineup_(v) {
  if(!v) return null;
  try { const a=JSON.parse(String(v)); if(!Array.isArray(a)||a.length!==4) return null;
    return a.map(x=>({playerId:String((x&&x.playerId)||""),name:String((x&&x.name)||""),invitedAt:String((x&&x.invitedAt)||""),reminded:!!(x&&x.reminded),email:String((x&&x.email)||""),token:String((x&&x.token)||""),openedAt:String((x&&x.openedAt)||""),opens:Number((x&&x.opens)||0)})); } catch(e) { return null; }
}
/** Four slots: pair 1 right/left, pair 2 right/left. Members of the community are matched by playerId; free text names are guests. */
function buildLineup_(raw,owner,ownerProfile,mustKeep,prev) {
  const arr=Array.isArray(raw)?raw.slice(0,4):[];
  const players={}, byEmail={}; readRows_("Players").filter(r=>r.playerId&&truthy_(r.active)).forEach(r=>{ players[String(r.playerId)]=String(r.displayName||""); const em=String(r.email||"").trim().toLowerCase(); if(em) byEmail[em]=String(r.playerId); });
  const seen={}, seenEmail={}, out=[], newInvites=[], newEmailInvites=[];
  for(let i=0;i<4;i++) {
    const e=arr[i]||{}; let pid=clean_(e.playerId,80), name=clean_(e.name,60), email=String(e.email||"").trim().toLowerCase().slice(0,120);
    if(pid&&!players.hasOwnProperty(pid)) pid="";
    if(!/^[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+$/.test(email)||pid) email="";
    if(email&&byEmail[email]) { if(byEmail[email]===owner.playerId) throw new Error("Questa è la tua email: il tuo posto c'è già."); pid=byEmail[email]; email=""; }
    if(email) { if(owner.email&&email===String(owner.email).toLowerCase()) throw new Error("Questa è la tua email: il tuo posto c'è già."); if(seenEmail[email]) throw new Error("La stessa email è in due posti."); seenEmail[email]=1; if(!name) name="Invitato via email"; }
    if(pid) { if(seen[pid]) throw new Error("Lo stesso giocatore è in due posti."); seen[pid]=1; name=players[pid]; }
    const old=pid&&prev?prev.find(x=>x.playerId===pid):null;
    const slot={playerId:pid,name:name,invitedAt:"",reminded:false,email:email,token:""};
    if(pid&&pid!==owner.playerId) { if(old&&old.invitedAt) { slot.invitedAt=old.invitedAt; slot.reminded=!!old.reminded; } else { slot.invitedAt=new Date().toISOString(); newInvites.push(pid); } }
    if(!pid&&email) { const oldE=prev?prev.find(x=>x.email===email):null; if(oldE&&oldE.invitedAt) { slot.invitedAt=oldE.invitedAt; slot.reminded=!!oldE.reminded; slot.token=oldE.token||Utilities.getUuid(); slot.openedAt=oldE.openedAt||""; slot.opens=oldE.opens||0; } else { slot.invitedAt=new Date().toISOString(); slot.token=Utilities.getUuid(); newEmailInvites.push({email:email,token:slot.token}); } }
    out.push(slot);
  }
  if(!seen[owner.playerId]) {
    const own=ownerProfile?String(ownerProfile.displayName||""):(players[owner.playerId]||"");
    const free=out.findIndex(x=>!x.playerId&&!x.name);
    if(free<0) throw new Error("Chi organizza deve occupare uno dei 4 posti.");
    out[free]={playerId:owner.playerId,name:own,invitedAt:"",reminded:false,email:"",token:""};
  }
  (mustKeep||[]).forEach(function(id){ if(!seen[id]&&id!==owner.playerId) throw new Error("Non puoi togliere dalla formazione chi è già iscritto: deve annullare lui."); });
  out.newInvites=newInvites; out.newEmailInvites=newEmailInvites;
  return out;
}

/** Admin only (ADMIN_EMAILS): deletes all matches and registrations, optionally the player profiles too. Needs the confirmation word. */
function resetAllData(idToken,input) {
  const user=verifyUser_(idToken); input=input||{};
  if(!user.isAdmin) throw new Error("Solo l'amministratore può cancellare i dati.");
  if(String(input.confirm||"").trim().toUpperCase()!=="CANCELLA") throw new Error("Per confermare scrivi CANCELLA.");
  const lock=LockService.getScriptLock();
  lock.waitLock(20000);
  try {
    const calendarId=PropertiesService.getScriptProperties().getProperty("CALENDAR_ID");
    let events=0;
    if(calendarId) {
      try {
        const cal=CalendarApp.getCalendarById(calendarId);
        if(cal) readRows_("Matches").forEach(function(m){ const id=String(m.calendarEventId||""); if(id) { try { const ev=cal.getEventById(id); if(ev) { ev.deleteEvent(); events++; } } catch(e) {} } });
      } catch(e) {}
    }
    let names=["Matches","Registrations"].concat(input.includeProfiles===true?["Players"]:[]);
    try { sheet_("Shares"); names.push("Shares"); } catch(e) {}
    if(input.includeProfiles===true) { try { sheet_("Devices"); names.push("Devices"); } catch(e) {} }
    const counts={};
    names.forEach(function(name){ const sh=sheet_(name), n=Math.max(0,sh.getLastRow()-1); if(n>0) sh.deleteRows(2,n); counts[name]=n; });
    return {message:"Dati cancellati: "+counts.Matches+" partite, "+counts.Registrations+" iscrizioni"+(input.includeProfiles===true?", "+counts.Players+" profili":"")+(events?", "+events+" eventi del calendario":"")+".",counts:counts};
  } finally {
    lock.releaseLock();
  }
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
  notifyCompleted_(row);
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
  if(allowedEmails.length && allowedEmails.indexOf(email)<0 && !isApprovedEmail_(email) && !hasEmailInvite_(email) && !hasTokenInvite_() && !hasCommunityInvite_(email)) throw new Error("Questo account non è ancora abilitato alla community. Chiedi a chi ti ha invitato o all'amministratore di aggiungere il tuo indirizzo.");
  return {email:email,playerId:"google:"+token.sub,isAdmin:isAdminEmail_(email),picture:String(token.picture||"")};
}

function safePhoto_(url) {
  const u=String(url||"");
  return /^https:\/\/[a-z0-9-]+\.googleusercontent\.com\/[A-Za-z0-9_\-\/=.%:~]{1,400}$/.test(u)?u:"";
}
function profileComplete_(r) {
  return GENDERS.indexOf(String(r.gender||""))>=0&&String(r.consentVersion||"")===CONSENT_VERSION&&!!r.consentAt;
}
function requireProfile_(user) {
  const p=readRows_("Players").find(r=>String(r.playerId)===user.playerId&&truthy_(r.active)&&String(r.displayName||"").trim());
  if(!p) throw new Error("Prima di iscriverti o proporre una partita salva il tuo profilo (nome, livello e lato).");
  if(!profileComplete_(p)) throw new Error("Completa il profilo: scegli maschio, femmina o altro e accetta l'informativa privacy, poi salva.");
  return p;
}
function isApprovedEmail_(email) {
  try { return JSON.parse(PropertiesService.getScriptProperties().getProperty("INVITED_EMAILS")||"[]").indexOf(email)>=0; } catch(e) { return false; }
}
/** Remembers an address that joined through an invitation, so it keeps access when ALLOWED_EMAILS is set. */
function approveEmail_(email) {
  try {
    const props=PropertiesService.getScriptProperties();
    const list=JSON.parse(props.getProperty("INVITED_EMAILS")||"[]");
    if(list.indexOf(email)<0) { list.push(email); props.setProperty("INVITED_EMAILS",JSON.stringify(list.slice(-300))); }
  } catch(e) { console.log("INVITED_EMAILS non aggiornata: "+e); }
}
function hasTokenInvite_() {
  if(!CURRENT_INVITE_TOKEN) return false;
  try {
    const now=Date.now();
    return readRows_("Matches").some(function(m){
      if(String(m.status)==="cancelled"||String(m.status)==="completed") return false;
      const t=new Date(m.dateTime).getTime(); if(!isNaN(t)&&t<now) return false;
      const lu=parseLineup_(m.lineup); return !!lu&&lu.some(x=>x.token&&x.token===CURRENT_INVITE_TOKEN);
    });
  } catch(e) { return false; }
}
/** True if someone invited this address to an upcoming match: an invitation counts as admission even when ALLOWED_EMAILS is set. */
function hasEmailInvite_(email) {
  try {
    const now=Date.now();
    return readRows_("Matches").some(function(m){
      if(String(m.status)==="cancelled"||String(m.status)==="completed") return false;
      const t=new Date(m.dateTime).getTime(); if(!isNaN(t)&&t<now) return false;
      const lu=parseLineup_(m.lineup); return !!lu&&lu.some(x=>x.email&&x.email===email);
    });
  } catch(e) { return false; }
}
/** Tells the lineup editor whether an address already belongs to a registered player (so the box can turn into that person). */
function lookupEmail(idToken,input) {
  const user=verifyUser_(idToken);
  const email=String((input&&input.email)||"").trim().toLowerCase();
  if(!/^[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+$/.test(email)) throw new Error("Email non valida.");
  if(email===user.email) return {found:false,self:true};
  const p=readRows_("Players").find(r=>r.playerId&&truthy_(r.active)&&String(r.email||"").trim().toLowerCase()===email);
  return p?{found:true,playerId:String(p.playerId),displayName:String(p.displayName||"")}:{found:false};
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
