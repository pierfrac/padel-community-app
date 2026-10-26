/**
 * Padel Community web app backend.
 * Configure Script Properties: GOOGLE_CLIENT_ID, ADMIN_EMAILS, CALENDAR_ID (optional),
 * APP_URL (optional, public address of the web front end, used in organizer emails),
 * SUPPORT_EMAIL (optional, defaults to SUPPORT_EMAIL_DEFAULT).
 * This script is bound to the community spreadsheet.
 */
const HEADERS = {
  Players: ["playerId","displayName","email","skillLevel","preferredSide","active","createdAt","updatedAt","gender","emailOptOut"],
  Matches: ["matchId","dateTime","venue","createdBy","status","notes","createdAt","calendarEventId"],
  Registrations: ["registrationId","matchId","playerId","status","createdAt"],
  MailList: ["email","addedBy","createdAt"],
  FeedbackPrivate: ["DO_NOT_USE"]
};

/** preferredSide: left = Sinistro (plays left), right = Destro (plays right), lefty = Mancino (left-handed, always plays right). Older rows may hold "indifferent" or be empty: those profiles count as incomplete. */
const POSITIONS = ["left","right","lefty"];
/** gender: M = Uomo, F = Donna. Visible only to the player and to administrators. */
const GENDERS = ["M","F"];
/** Compatibility between two partners, added to the base score. Keys are the two positions sorted alphabetically and joined by "|". */
const PAIR_MODIFIERS = {"left|lefty":10,"left|right":10,"lefty|right":-10,"left|left":-25,"right|right":-25,"lefty|lefty":-25};
const SUPPORT_EMAIL_DEFAULT = "pfcardillo-debutelespadel@gmail.com";
/** Apps Script allows at most 50 recipients per message; one slot is taken by the "to" address (the sending account), the rest is Bcc. */
const MAIL_BATCH = 49;
const MAIL_MATCH_LIMIT = 15;

function doGet() {
  const t = HtmlService.createTemplateFromFile("Index");
  t.googleClientId = PropertiesService.getScriptProperties().getProperty("GOOGLE_CLIENT_ID") || "";
  return t.evaluate().setTitle("Padel Community").addMetaTag("viewport","width=device-width, initial-scale=1");
}

const BACKEND_VERSION = "2026-10-26.1";
const API_METHODS = ["getAppData","saveProfile","createMatch","registerForMatch","cancelRegistration","completeMatch","cancelMatch","getIncompleteProfiles","getMailList","saveMailList","previewEmail","sendEmail"];

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
  ["Players","Matches","Registrations","MailList"].forEach(function(name) {
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
    const own = String(r.playerId) === user.playerId;
    const p = {playerId:String(r.playerId),displayName:String(r.displayName || "Giocatore"),skillLevel:String(r.skillLevel || "Da definire"),preferredSide:String(r.preferredSide || ""),active:true};
    if (own || user.isAdmin) p.gender = String(r.gender || "");
    if (own) p.emailOptOut = truthy_(r.emailOptOut);
    return p;
  });
  const registrations = readRows_("Registrations").filter(r => r.registrationId && String(r.status) === "joined").map(function(r) {
    return {registrationId:String(r.registrationId),matchId:String(r.matchId),playerId:String(r.playerId),status:String(r.status)};
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
  const gender = clean_(input.gender,2).toUpperCase();
  const emailOptOut = input.emailOptOut===true || input.emailOptOut==="true";
  const allowedLevels = ["Bronze","Silver","Silver-Gold","Gold","Gold+"];
  if (!name || allowedLevels.indexOf(level)<0 || POSITIONS.indexOf(side)<0 || GENDERS.indexOf(gender)<0)
    throw new Error("Inserisci nome, livello, sesso e posizione.");
  const sh=sheet_("Players"); ensureHeaders_(sh,"Players");
  const rows=readRows_("Players");
  const existing=rows.find(r=>String(r.playerId)===user.playerId);
  const values=[user.playerId,name,user.email,level,side,true,existing?existing.createdAt:new Date(),new Date(),gender,emailOptOut];
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
  sheet_("Registrations").appendRow([Utilities.getUuid(),id,user.playerId,"joined",created]);
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
    sheet_("Registrations").appendRow([Utilities.getUuid(),matchId,user.playerId,"joined",new Date()]);
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
  return {message:"Iscrizione annullata."};
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

/* ---------- Funzioni riservate agli organizzatori (ADMIN_EMAILS) ---------- */

/** Active players without gender or position, with the names of the missing fields. */
function getIncompleteProfiles(idToken) {
  const user=verifyUser_(idToken); requireAdmin_(user);
  const incomplete=readRows_("Players").filter(r=>r.playerId&&truthy_(r.active)&&!isComplete_(r)).map(function(r) {
    const missing=[];
    if(GENDERS.indexOf(String(r.gender||""))<0) missing.push("sesso");
    if(POSITIONS.indexOf(String(r.preferredSide||""))<0) missing.push("posizione");
    return {displayName:String(r.displayName||"Giocatore"),missing:missing};
  }).sort((a,b)=>a.displayName.localeCompare(b.displayName));
  return {incomplete:incomplete};
}

function getMailList(idToken) {
  const user=verifyUser_(idToken); requireAdmin_(user);
  return {emails:readRows_("MailList").map(r=>String(r.email||"")).filter(Boolean)};
}

/** Replaces the manual mail list (people not yet in the app). Addresses removed from the text are deleted. */
function saveMailList(idToken,input) {
  const user=verifyUser_(idToken); requireAdmin_(user);
  const parsed=parseEmails_(input&&input.emails);
  if(parsed.valid.length>500) throw new Error("La lista può contenere al massimo 500 indirizzi.");
  const lock=LockService.getScriptLock();
  lock.waitLock(10000);
  try {
    const sh=sheet_("MailList"), cols=HEADERS.MailList.length, old={};
    readRows_("MailList").forEach(r=>{old[String(r.email).toLowerCase()]=r;});
    const now=new Date();
    const rows=parsed.valid.map(e=>[e,old[e]?old[e].addedBy:user.email,old[e]?old[e].createdAt:now]);
    if(sh.getLastRow()>1) sh.getRange(2,1,sh.getLastRow()-1,cols).clearContent();
    if(rows.length) sh.getRange(2,1,rows.length,cols).setValues(rows);
  } finally {
    lock.releaseLock();
  }
  const skipped=parsed.invalid.length?" Ignorati perché non validi: "+parsed.invalid.slice(0,5).join(", ")+(parsed.invalid.length>5?"…":"")+".":"";
  return {emails:parsed.valid,message:"Lista salvata: "+parsed.valid.length+" indirizzi."+skipped};
}

/** Dry run: who would receive the email, how many sends, how much daily quota is left, and the exact text. */
function previewEmail(idToken,input) {
  const user=verifyUser_(idToken); requireAdmin_(user);
  const p=planEmail_(input);
  return {recipientCount:p.emails.length,batches:p.chunks.length,quotaRemaining:p.quota,quotaNeeded:p.needed,subject:p.subject,body:p.body,notes:p.notes};
}

/** Sends the organizer email. Recipients are always in Bcc; the audience is recomputed here and never taken from the browser. */
function sendEmail(idToken,input) {
  const user=verifyUser_(idToken); requireAdmin_(user);
  const lock=LockService.getScriptLock();
  lock.waitLock(10000);
  try {
    const p=planEmail_(input);
    if(!p.emails.length) throw new Error("Nessun destinatario con queste scelte.");
    if(p.needed>p.quota) throw new Error("Quota giornaliera di invio insufficiente: servono "+p.needed+" destinatari (compreso l'indirizzo che invia), ne restano "+p.quota+". Riduci i destinatari o riprova domani.");
    const to=Session.getEffectiveUser().getEmail();
    let sent=0;
    p.chunks.forEach(function(chunk) {
      try {
        MailApp.sendEmail({to:to,bcc:chunk.join(","),subject:p.subject,body:p.body,replyTo:p.support,name:"Telespadel"});
        sent+=chunk.length;
      } catch(err) {
        throw new Error("Inviate "+sent+" email su "+p.emails.length+" prima dell'errore: "+err.message+". Non rinviare a chi l'ha già ricevuta.");
      }
    });
    return {sent:sent,message:"Email inviata a "+sent+" destinatari in "+p.chunks.length+(p.chunks.length===1?" invio":" invii")+"."};
  } finally {
    lock.releaseLock();
  }
}

function planEmail_(input) {
  input=input||{};
  const src=input.sources||{}, f=input.filter||{};
  const sources={registered:src.registered===true,manual:src.manual===true};
  if(!sources.registered&&!sources.manual) throw new Error("Scegli almeno una fonte di indirizzi.");
  const mode=["all","incomplete","match"].indexOf(f.mode)>=0?f.mode:"all";
  const players=readRows_("Players").filter(r=>r.playerId).map(function(r) {
    return {playerId:String(r.playerId),displayName:String(r.displayName||""),email:String(r.email||""),skillLevel:String(r.skillLevel||""),preferredSide:String(r.preferredSide||""),gender:String(r.gender||""),emailOptOut:truthy_(r.emailOptOut),active:truthy_(r.active)};
  });
  const props=PropertiesService.getScriptProperties();
  const appUrl=String(props.getProperty("APP_URL")||"").trim().replace(/#.*$/,"");
  const support=String(props.getProperty("SUPPORT_EMAIL")||SUPPORT_EMAIL_DEFAULT).trim();
  const open=listOpenMatches_();
  let matchPlayers=[];
  if(mode==="match") {
    const matchId=clean_(f.matchId,80);
    const m=open.find(x=>x.matchId===matchId);
    if(!m) throw new Error("Scegli una partita aperta con posti liberi.");
    const ids={}; m.playerIds.forEach(id=>{ids[id]=true;});
    matchPlayers=players.filter(p=>ids[p.playerId]);
  }
  const manual=sources.manual?readRows_("MailList").map(r=>String(r.email||"")):[];
  const aud=selectAudience_({players:players,matchPlayers:matchPlayers,manual:manual,sources:sources,mode:mode,max:Number(f.max)});
  const listed=input.includeOpenMatches===true?open.slice(0,MAIL_MATCH_LIMIT).map(m=>({when:formatWhen_(m.date),venue:m.venue,free:4-m.count,link:appUrl?appUrl+"#match="+m.matchId:""})):null;
  const subject=clean_(input.subject,120)||"Telespadel";
  const body=buildEmailBody_({message:input.message,openMatches:listed,appUrl:appUrl,support:support});
  const chunks=chunk_(aud.emails,MAIL_BATCH);
  const notes=aud.notes.slice();
  if(listed&&listed.length&&!appUrl) notes.push("Manca APP_URL nelle Proprietà script: l'email non contiene il link all'app.");
  return {emails:aud.emails,chunks:chunks,subject:subject,body:body,support:support,notes:notes,needed:aud.emails.length+chunks.length,quota:MailApp.getRemainingDailyQuota()};
}

/** Open matches in the future with free places, soonest first. */
function listOpenMatches_() {
  const counts={}, ids={};
  readRows_("Registrations").filter(r=>r.registrationId&&String(r.status)==="joined").forEach(function(r) {
    const k=String(r.matchId); counts[k]=(counts[k]||0)+1; (ids[k]=ids[k]||[]).push(String(r.playerId));
  });
  return readRows_("Matches").filter(r=>r.matchId&&String(r.status||"open")==="open").map(function(r) {
    const k=String(r.matchId);
    return {matchId:k,date:new Date(r.dateTime),venue:String(r.venue||""),count:counts[k]||0,playerIds:ids[k]||[]};
  }).filter(m=>!isNaN(m.date.getTime())&&m.date.getTime()>Date.now()&&m.count<4).sort((a,b)=>a.date-b.date);
}

/**
 * Pure audience selection.
 * mode "all": every chosen address. "incomplete": registered players with an incomplete profile.
 * "match": registered players not yet in the match, best average partner score first, at most max of them.
 * The manual list has no profile data, so it is used only with mode "all". Players who switched emails off are always excluded.
 */
function selectAudience_(o) {
  const notes=[], seen={}, out=[], optedOut={};
  o.players.forEach(function(p) { if(truthy_(p.emailOptOut)) optedOut[String(p.email).trim().toLowerCase()]=true; });
  const add=function(raw) {
    const e=String(raw||"").trim().toLowerCase();
    if(!validEmail_(e)||seen[e]||optedOut[e]) return;
    seen[e]=true; out.push(e);
  };
  const mode=o.mode||"all";
  if(o.sources.registered) {
    let list=o.players.filter(p=>truthy_(p.active)&&!truthy_(p.emailOptOut));
    if(mode==="incomplete") list=list.filter(p=>!isComplete_(p));
    if(mode==="match") {
      const inMatch=o.matchPlayers||[], taken={};
      inMatch.forEach(p=>{taken[p.playerId]=true;});
      const ranked=list.filter(p=>!taken[p.playerId]).map(function(p) {
        const s=inMatch.length?inMatch.reduce((t,q)=>t+pairScore_(p,q),0)/inMatch.length:50;
        return {p:p,s:s};
      }).sort((a,b)=>b.s-a.s||String(a.p.displayName).localeCompare(String(b.p.displayName)));
      const max=Math.max(1,Math.min(100,Math.floor(o.max)||20));
      list=ranked.slice(0,max).map(x=>x.p);
    }
    list.forEach(p=>add(p.email));
  }
  if(o.sources.manual) {
    if(mode==="all") o.manual.forEach(add);
    else notes.push("La lista manuale è inclusa solo con la scelta \"Tutti\".");
  }
  return {emails:out,notes:notes};
}

function buildEmailBody_(o) {
  const parts=[clean_(o.message,2000)||"Ciao a tutti,"];
  if(o.openMatches) {
    if(o.openMatches.length) parts.push("Partite aperte:\n"+o.openMatches.map(m=>"• "+m.when+" · "+m.venue+" · "+(m.free===1?"1 posto libero":m.free+" posti liberi")+(m.link?"\n  "+m.link:"")).join("\n"));
    else parts.push("Al momento non ci sono partite aperte.");
  }
  if(o.appUrl) parts.push("Entrate nell'app: "+o.appUrl);
  parts.push("Per qualsiasi problema scrivete a "+o.support+".");
  parts.push("La riservatezza delle vostre informazioni per noi è una cosa seria: la trattiamo con la massima attenzione.");
  parts.push("Non volete più ricevere queste email? Rispondete a questo messaggio scrivendo STOP, oppure disattivate l'opzione email nel vostro profilo dell'app.");
  return parts.join("\n\n");
}

function formatWhen_(d) {
  const days=["dom","lun","mar","mer","gio","ven","sab"], months=["gen","feb","mar","apr","mag","giu","lug","ago","set","ott","nov","dic"];
  const pad=n=>(n<10?"0":"")+n;
  return days[d.getDay()]+" "+d.getDate()+" "+months[d.getMonth()]+", "+pad(d.getHours())+":"+pad(d.getMinutes());
}

/* ---------- Compatibilità tra compagni ---------- */

function isComplete_(p) { return GENDERS.indexOf(String(p.gender||""))>=0&&POSITIONS.indexOf(String(p.preferredSide||""))>=0; }
function rank_(level) { return {"Bronze":1,"Silver":2,"Silver-Gold":3,"Gold":4,"Gold+":5}[level]||0; }
/** Positions outside POSITIONS (older profiles) have no effect. */
function pairModifier_(a,b) { return PAIR_MODIFIERS[[String(a||""),String(b||"")].sort().join("|")]||0; }
/** Server-side score used to rank candidates for an open match. The personal feedback term of the browser score is not available here. */
function pairScore_(a,b) {
  const s=50+pairModifier_(a.preferredSide,b.preferredSide)+Math.max(-20,20-Math.abs(rank_(a.skillLevel)-rank_(b.skillLevel))*10);
  return Math.max(0,Math.min(100,Math.round(s)));
}

function requireAdmin_(user) { if(!user.isAdmin) throw new Error("Funzione riservata agli amministratori."); }
function validEmail_(e) { e=String(e||""); return e.length<=254&&/^[^@\s,;<>]+@[^@\s,;<>]+\.[^@\s,;<>]+$/.test(e); }
function parseEmails_(text) {
  const valid=[], invalid=[], seen={};
  String(text==null?"":text).split(/[\s,;]+/).forEach(function(raw) {
    const e=raw.trim().toLowerCase(); if(!e) return;
    if(!validEmail_(e)) { invalid.push(raw.slice(0,60)); return; }
    if(!seen[e]) { seen[e]=true; valid.push(e); }
  });
  return {valid:valid,invalid:invalid};
}
function chunk_(arr,n) { const out=[]; for(let i=0;i<arr.length;i+=n) out.push(arr.slice(i,i+n)); return out; }

/** Adds missing header cells (new columns at the end) to a sheet created by an older version. */
function ensureHeaders_(sh,name) {
  const want=HEADERS[name], have=sh.getLastColumn();
  if(have>=want.length) return;
  const first=sh.getRange(1,1,1,have).getDisplayValues()[0];
  if(first.join("|")!==want.slice(0,have).join("|")) throw new Error("Intestazioni non compatibili nella scheda "+name+". Non sono state sovrascritte.");
  if(sh.getMaxColumns()<want.length) sh.insertColumnsAfter(sh.getMaxColumns(),want.length-sh.getMaxColumns());
  sh.getRange(1,have+1,1,want.length-have).setValues([want.slice(have)]);
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
