/**
 * Padel Community web app backend.
 * Configure Script Properties: GOOGLE_CLIENT_ID, ADMIN_EMAILS, CALENDAR_ID (optional).
 * This script is bound to the community spreadsheet.
 */
const HEADERS = {
  Players: ["playerId","displayName","email","skillLevel","preferredSide","active","createdAt","updatedAt","photoUrl"],
  Matches: ["matchId","dateTime","venue","createdBy","status","notes","createdAt","calendarEventId","lineup"],
  Registrations: ["registrationId","matchId","playerId","status","createdAt","partnerId"],
  FeedbackPrivate: ["DO_NOT_USE"]
};

function doGet() {
  const t = HtmlService.createTemplateFromFile("Index");
  t.googleClientId = PropertiesService.getScriptProperties().getProperty("GOOGLE_CLIENT_ID") || "";
  return t.evaluate().setTitle("Padel Community").addMetaTag("viewport","width=device-width, initial-scale=1");
}

const BACKEND_VERSION = "2026-10-24.5";
const API_METHODS = ["getAppData","saveProfile","createMatch","registerForMatch","cancelRegistration","completeMatch","cancelMatch","setPartner","setLineup","resetAllData"];

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
    return {playerId:String(r.playerId),displayName:String(r.displayName || "Giocatore"),skillLevel:String(r.skillLevel || "Da definire"),preferredSide:String(r.preferredSide || "indifferent"),photoUrl:safePhoto_(r.photoUrl),active:true};
  });
  const registrations = readRows_("Registrations").filter(r => r.registrationId && String(r.status) === "joined").map(function(r) {
    return {registrationId:String(r.registrationId),matchId:String(r.matchId),playerId:String(r.playerId),status:String(r.status),partnerId:String(r.partnerId || "")};
  });
  const matches = readRows_("Matches").filter(r => r.matchId && String(r.status) !== "cancelled").map(function(r) {
    return {matchId:String(r.matchId),dateTime:iso_(r.dateTime),venue:String(r.venue || ""),status:String(r.status || "open"),notes:String(r.notes || ""),createdBy:String(r.createdBy || ""),lineup:parseLineup_(r.lineup),registeredCount:0};
  });
  const counts = {};
  registrations.forEach(r => counts[r.matchId]=(counts[r.matchId]||0)+1);
  matches.forEach(m => { m.registeredCount=counts[m.matchId]||0; m.seatsTaken=m.lineup?m.lineup.filter(x=>x.playerId||x.name).length:m.registeredCount; });
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
  const photo=input.showPhoto===true?safePhoto_(user.picture):"";
  const values=[user.playerId,name,user.email,level,side,true,existing?existing.createdAt:new Date(),new Date(),photo];
  if(existing) sh.getRange(existing._row,1,1,values.length).setValues([values]); else sh.appendRow(values);
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
      if(slot<0) { slot=pickSlot_(lineup,String(profile.preferredSide||"")); if(slot<0) throw new Error("La partita è già completa."); lineup[slot]={playerId:user.playerId,name:String(profile.displayName||""),invitedAt:"",reminded:false}; sheet_("Matches").getRange(match._row,9).setValue(JSON.stringify(lineup)); }
    } else if(active.length>=4) throw new Error("La partita è già completa.");
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
  const mrow=readRows_("Matches").find(r=>String(r.matchId)===matchId), lu=mrow&&parseLineup_(mrow.lineup);
  if(lu) { const i=lu.findIndex(x=>x.playerId===user.playerId); if(i>=0) { lu[i]={playerId:"",name:"",invitedAt:"",reminded:false}; sheet_("Matches").getRange(mrow._row,9).setValue(JSON.stringify(lu)); } }
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
    return {message:"Formazione aggiornata."};
  } finally {
    lock.releaseLock();
  }
}

const DEFAULT_APP_URL = "https://pierfrac.github.io/padel-community-app/";
const INVITE_REMINDER_AFTER_MS = 24*60*60*1000;
const REMINDER_MIN_DAYS_LEFT = 4;

function esc_(t) { return String(t==null?"":t).replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c])); }
function appLink_(m) {
  const base=PropertiesService.getScriptProperties().getProperty("APP_URL")||DEFAULT_APP_URL;
  return base+"?match="+encodeURIComponent(m.matchId)+"&v="+encodeURIComponent(m.venue)+"&d="+encodeURIComponent(new Date(m.date).toISOString());
}
function whenText_(d) { return Utilities.formatDate(new Date(d),Session.getScriptTimeZone(),"dd/MM/yyyy 'alle' HH:mm"); }
function mail_(to,subject,html) {
  try { if(!to) return; MailApp.sendEmail({to:String(to),subject:subject,htmlBody:html,name:"Padel Community"}); }
  catch(err) { console.log("Email non inviata a "+to+": "+err); }
}
function playerMap_() {
  const map={}; readRows_("Players").forEach(r=>{ map[String(r.playerId)]={name:String(r.displayName||""),email:String(r.email||"")}; }); return map;
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
    const slots=lineup.map(function(x,i){ const side=i%2===0?"destra":"sinistra", who=x.playerId?esc_(x.name)+(x.invitedAt?" (invitato)":" (tu)"):(x.name?esc_(x.name)+" (ospite)":"libero"); return "Coppia "+(Math.floor(i/2)+1)+", "+side+": "+who; });
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
        if(!s.playerId||s.playerId===String(m.createdBy)||joined[matchId+"|"+s.playerId]||!s.invitedAt||s.reminded) return;
        const age=now-new Date(s.invitedAt).getTime(); if(isNaN(age)||age<INVITE_REMINDER_AFTER_MS) return;
        const invitee=pm[s.playerId]||{name:s.name,email:""}, org=pm[String(m.createdBy)]||{name:"",email:""};
        if((start-now)/DAY>REMINDER_MIN_DAYS_LEFT) {
          s.reminded=true; changed=true;
          mail_(invitee.email,"⏰ Promemoria: hai un invito a una partita di padel",
            "<p>Ciao "+esc_(invitee.name)+",</p><p>hai ancora un posto riservato per la partita di <b>"+esc_(info.venue)+"</b>, "+esc_(whenText_(info.date))+".</p><p><a href=\""+esc_(appLink_(info))+"\">Apri la partita e premi “Accetta invito”</a>.</p>");
        } else {
          lineup[i]={playerId:"",name:"",invitedAt:"",reminded:false}; changed=true;
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

function parseLineup_(v) {
  if(!v) return null;
  try { const a=JSON.parse(String(v)); if(!Array.isArray(a)||a.length!==4) return null;
    return a.map(x=>({playerId:String((x&&x.playerId)||""),name:String((x&&x.name)||""),invitedAt:String((x&&x.invitedAt)||""),reminded:!!(x&&x.reminded)})); } catch(e) { return null; }
}
/** Four slots: pair 1 right/left, pair 2 right/left. Members of the community are matched by playerId; free text names are guests. */
function buildLineup_(raw,owner,ownerProfile,mustKeep,prev) {
  const arr=Array.isArray(raw)?raw.slice(0,4):[];
  const players={}; readRows_("Players").filter(r=>r.playerId&&truthy_(r.active)).forEach(r=>players[String(r.playerId)]=String(r.displayName||""));
  const seen={}, out=[], newInvites=[];
  for(let i=0;i<4;i++) {
    const e=arr[i]||{}; let pid=clean_(e.playerId,80), name=clean_(e.name,60);
    if(pid&&!players.hasOwnProperty(pid)) pid="";
    if(pid) { if(seen[pid]) throw new Error("Lo stesso giocatore è in due posti."); seen[pid]=1; name=players[pid]; }
    const old=pid&&prev?prev.find(x=>x.playerId===pid):null;
    const slot={playerId:pid,name:name,invitedAt:"",reminded:false};
    if(pid&&pid!==owner.playerId) { if(old&&old.invitedAt) { slot.invitedAt=old.invitedAt; slot.reminded=!!old.reminded; } else { slot.invitedAt=new Date().toISOString(); newInvites.push(pid); } }
    out.push(slot);
  }
  if(!seen[owner.playerId]) {
    const own=ownerProfile?String(ownerProfile.displayName||""):(players[owner.playerId]||"");
    const free=out.findIndex(x=>!x.playerId&&!x.name);
    if(free<0) throw new Error("Chi organizza deve occupare uno dei 4 posti.");
    out[free]={playerId:owner.playerId,name:own,invitedAt:"",reminded:false};
  }
  (mustKeep||[]).forEach(function(id){ if(!seen[id]&&id!==owner.playerId) throw new Error("Non puoi togliere dalla formazione chi è già iscritto: deve annullare lui."); });
  out.newInvites=newInvites;
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
    const names=["Matches","Registrations"].concat(input.includeProfiles===true?["Players"]:[]);
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
  return {email:email,playerId:"google:"+token.sub,isAdmin:adminEmails.indexOf(email)>=0,picture:String(token.picture||"")};
}

function safePhoto_(url) {
  const u=String(url||"");
  return /^https:\/\/[a-z0-9-]+\.googleusercontent\.com\/[A-Za-z0-9_\-\/=.%:~]{1,400}$/.test(u)?u:"";
}
function requireProfile_(user) {
  const p=readRows_("Players").find(r=>String(r.playerId)===user.playerId&&truthy_(r.active)&&String(r.displayName||"").trim());
  if(!p) throw new Error("Prima di iscriverti o proporre una partita salva il tuo profilo (nome, livello e lato).");
  return p;
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
