const SHEET_NAMES = {
  users: 'Users',
  clubs: 'Clubs',
  courts: 'Courts',
  matches: 'Matches',
  players: 'MatchPlayers',
  feedback: 'Feedback',
  results: 'MatchResults',
};

const HEADERS = {
  Users: ['userId', 'email', 'name', 'category', 'position', 'gender', 'active', 'createdAt'],
  Clubs: ['clubId', 'name', 'address', 'area', 'active'],
  Courts: ['courtId', 'clubId', 'name', 'address', 'active'],
  Matches: ['matchId', 'createdBy', 'format', 'category', 'startsAt', 'area', 'status', 'courtId', 'calendarEventId', 'createdAt'],
  MatchPlayers: ['matchId', 'userId', 'joinedAt', 'team'],
  Feedback: ['feedbackId', 'matchId', 'fromUserId', 'toUserId', 'rating', 'createdAt'],
  MatchResults: ['resultId', 'matchId', 'submittedBy', 'teamAScore', 'teamBScore', 'createdAt'],
};

const CATEGORIES = ['Bronze', 'Silver', 'Silver-Gold', 'Gold', 'Gold+'];
const POSITIONS = ['Right', 'Left', 'Either'];
const FORMATS = ['Mens doubles', 'Womens doubles', 'Mixed doubles'];

function doGet() {
  const template = HtmlService.createTemplateFromFile('Index');
  template.googleClientId = PropertiesService.getScriptProperties().getProperty('GOOGLE_CLIENT_ID') || '';
  return template.evaluate()
    .setTitle('Padel Community')
    .addMetaTag('viewport', 'width=device-width, initial-scale=1');
}

/**
 * Run once from the Apps Script editor as the project owner before deployment.
 * Creates the shared data spreadsheet and a dedicated Calendar if not configured.
 */
function setupPadelCommunity() {
  const props = PropertiesService.getScriptProperties();
  let spreadsheetId = props.getProperty('SPREADSHEET_ID');
  if (!spreadsheetId) {
    const spreadsheet = SpreadsheetApp.create('Padel Community Data');
    spreadsheetId = spreadsheet.getId();
    props.setProperty('SPREADSHEET_ID', spreadsheetId);
  }
  const spreadsheet = SpreadsheetApp.openById(spreadsheetId);
  Object.keys(HEADERS).forEach(function(name) {
    let sheet = spreadsheet.getSheetByName(name);
    if (!sheet) sheet = spreadsheet.insertSheet(name);
    const current = sheet.getRange(1, 1, 1, HEADERS[name].length).getValues()[0];
    if (current.join('|') !== HEADERS[name].join('|')) {
      sheet.getRange(1, 1, 1, HEADERS[name].length).setValues([HEADERS[name]]);
      sheet.setFrozenRows(1);
      sheet.getRange(1, 1, 1, HEADERS[name].length).setFontWeight('bold');
    }
  });
  const defaultSheet = spreadsheet.getSheetByName('Sheet1');
  if (defaultSheet && spreadsheet.getSheets().length > Object.keys(HEADERS).length) {
    spreadsheet.deleteSheet(defaultSheet);
  }
  let calendarId = props.getProperty('CALENDAR_ID');
  if (!calendarId) {
    const calendar = CalendarApp.createCalendar('Padel Community');
    calendarId = calendar.getId();
    props.setProperty('CALENDAR_ID', calendarId);
  }
  Logger.log('Spreadsheet: ' + spreadsheet.getUrl());
  Logger.log('Calendar ID: ' + calendarId);
  Logger.log('Admin emails must be set in Script Properties as ADMIN_EMAILS (comma-separated).');
  Logger.log('Set GOOGLE_CLIENT_ID in Script Properties before deploying the web app.');
}

function getGoogleClientId() {
  return PropertiesService.getScriptProperties().getProperty('GOOGLE_CLIENT_ID') || '';
}

/** Public entry point called by the browser. Every call verifies the Google ID token. */
function apiBootstrap(idToken) {
  const user = authenticate_(idToken);
  const profile = ensureUser_(user);
  return {
    user: publicUser_(profile),
    isAdmin: isAdmin_(user.email),
    categories: CATEGORIES,
    positions: POSITIONS,
    formats: FORMATS,
    matches: listMatches_(),
    recommendations: [],
  };
}

function apiSaveProfile(idToken, input) {
  const user = authenticate_(idToken);
  const name = cleanText_(input && input.name, 80);
  const category = String(input && input.category || '');
  const position = String(input && input.position || '');
  const gender = String(input && input.gender || '');
  if (!name) throw new Error('Inserisci il nome da mostrare.');
  if (CATEGORIES.indexOf(category) < 0) throw new Error('Livello non valido.');
  if (POSITIONS.indexOf(position) < 0) throw new Error('Posizione non valida.');
  if (['Male', 'Female'].indexOf(gender) < 0) throw new Error('Seleziona il genere sportivo per il formato partita.');
  const sheet = sheet_(SHEET_NAMES.users);
  const row = findRow_(sheet, 'email', user.email);
  const now = new Date().toISOString();
  if (row) {
    sheet.getRange(row, 3, 1, 4).setValues([[name, category, position, gender]]);
    sheet.getRange(row, 7).setValue(true);
  } else {
    sheet.appendRow([user.email, user.email, name, category, position, gender, true, now]);
  }
  return apiBootstrap(idToken);
}

function apiCreateMatch(idToken, input) {
  const user = authenticate_(idToken);
  const profile = ensureUser_(user);
  if (!profile.name || !profile.category || !profile.position || !profile.gender) {
    throw new Error('Completa prima il profilo: nome, livello, posizione e genere.');
  }
  const startsAt = new Date(String(input && input.startsAt || ''));
  if (isNaN(startsAt.getTime()) || startsAt.getTime() < Date.now() + 5 * 60 * 1000) {
    throw new Error('Scegli una data futura valida.');
  }
  const format = String(input && input.format || '');
  const category = String(input && input.category || profile.category);
  const area = cleanText_(input && input.area, 100);
  if (FORMATS.indexOf(format) < 0) throw new Error('Formato partita non valido.');
  if (CATEGORIES.indexOf(category) < 0) throw new Error('Livello non valido.');
  if (!area) throw new Error('Indica zona o città.');
  if (!formatAcceptsGender_(format, profile.gender)) {
    throw new Error('Il formato scelto non è compatibile con il genere del tuo profilo.');
  }

  const lock = LockService.getScriptLock();
  lock.waitLock(10000);
  try {
    const id = Utilities.getUuid();
    sheet_(SHEET_NAMES.matches).appendRow([
      id, user.email, format, category, startsAt.toISOString(), area,
      'Open', '', '', new Date().toISOString(),
    ]);
    sheet_(SHEET_NAMES.players).appendRow([id, user.email, new Date().toISOString(), '']);
  } finally {
    lock.releaseLock();
  }
  return apiBootstrap(idToken);
}

function apiJoinMatch(idToken, matchId) {
  const user = authenticate_(idToken);
  const profile = ensureUser_(user);
  if (!profile.name || !profile.category || !profile.position || !profile.gender) {
    throw new Error('Completa prima il profilo.');
  }
  const lock = LockService.getScriptLock();
  lock.waitLock(10000);
  try {
    const match = getMatch_(String(matchId));
    if (!match) throw new Error('Partita non trovata.');
    if (match.status !== 'Open' && match.status !== 'Forming') throw new Error('Questa partita non accetta più candidature.');
    if (!formatAcceptsGender_(match.format, profile.gender)) throw new Error('Il tuo profilo non è compatibile con questo formato.');
    const players = getPlayers_(match.id);
    if (players.some(function(p) { return p.userId === user.email; })) throw new Error('Sei già iscritto a questa partita.');
    if (players.length >= 4) throw new Error('La partita è già completa.');
    sheet_(SHEET_NAMES.players).appendRow([match.id, user.email, new Date().toISOString(), '']);
    const matchRow = findRow_(sheet_(SHEET_NAMES.matches), 'matchId', match.id);
    sheet_(SHEET_NAMES.matches).getRange(matchRow, 7).setValue(players.length + 1 >= 4 ? 'Awaiting court' : 'Forming');
  } finally {
    lock.releaseLock();
  }
  return apiBootstrap(idToken);
}

function apiRecommendations(idToken, matchId) {
  const user = authenticate_(idToken);
  const match = getMatch_(String(matchId));
  if (!match) throw new Error('Partita non trovata.');
  const players = getPlayers_(match.id);
  if (!players.some(function(p) { return p.userId === user.email; }) && !isAdmin_(user.email)) {
    throw new Error('Non puoi vedere i suggerimenti di questa partita.');
  }
  const existing = players.map(function(p) { return p.userId; });
  return sheetObjects_(SHEET_NAMES.users)
    .filter(function(p) {
      return p.active !== false && existing.indexOf(p.userId) < 0 &&
        formatAcceptsGender_(match.format, p.gender);
    })
    .map(function(p) {
      const score = matchScore_(match, players, p);
      return {
        userId: p.userId,
        name: p.name,
        category: p.category,
        position: p.position,
        matchScore: score.total,
        positionScore: score.position,
        levelScore: score.level,
        partnerFeedbackScore: score.feedback,
        explanation: score.explanation,
      };
    })
    .sort(function(a, b) { return b.matchScore - a.matchScore; })
    .slice(0, 12);
}

function apiAssignCourtAndConfirm(idToken, matchId, courtId) {
  const user = authenticate_(idToken);
  requireAdmin_(user.email);
  const match = getMatch_(String(matchId));
  if (!match) throw new Error('Partita non trovata.');
  const players = getPlayers_(match.id);
  if (players.length !== 4) throw new Error('Servono esattamente quattro giocatori.');
  const court = sheetObjects_(SHEET_NAMES.courts).find(function(c) {
    return c.courtId === String(courtId) && c.active !== false;
  });
  if (!court) throw new Error('Campo attivo non trovato.');
  const start = new Date(match.startsAt);
  const end = new Date(start.getTime() + 90 * 60000);
  const calendarId = PropertiesService.getScriptProperties().getProperty('CALENDAR_ID');
  if (!calendarId) throw new Error('CALENDAR_ID non configurato.');
  const calendar = CalendarApp.getCalendarById(calendarId);
  if (!calendar) throw new Error('Calendario non accessibile.');
  const guests = players.map(function(p) { return p.email; }).join(',');
  const event = calendar.createEvent(
    'Padel · ' + match.format + ' · ' + court.name,
    start,
    end,
    {
      location: court.address || match.area,
      description: 'Partita organizzata con Padel Community.',
      guests: guests,
      sendInvites: true,
    }
  );
  const row = findRow_(sheet_(SHEET_NAMES.matches), 'matchId', match.id);
  sheet_(SHEET_NAMES.matches).getRange(row, 7, 1, 3).setValues([['Confirmed', court.courtId, event.getId()]]);
  return apiBootstrap(idToken);
}

function apiSubmitFeedback(idToken, matchId, teammateEmail, rating) {
  const user = authenticate_(idToken);
  const match = getMatch_(String(matchId));
  if (!match || match.status !== 'Completed') throw new Error('Il feedback si può inviare dopo la partita.');
  const players = getPlayers_(match.id);
  if (!players.some(function(p) { return p.userId === user.email; }) ||
      !players.some(function(p) { return p.userId === String(teammateEmail); })) {
    throw new Error('Il feedback è disponibile solo per un compagno della tua partita.');
  }
  const score = Number(rating);
  if (!Number.isInteger(score) || score < 1 || score > 5) throw new Error('Valutazione non valida.');
  const feedbackSheet = sheet_(SHEET_NAMES.feedback);
  const duplicate = sheetObjects_(SHEET_NAMES.feedback).some(function(f) {
    return f.matchId === match.id && f.fromUserId === user.email && f.toUserId === String(teammateEmail);
  });
  if (duplicate) throw new Error('Hai già inviato il feedback per questo compagno.');
  feedbackSheet.appendRow([Utilities.getUuid(), match.id, user.email, String(teammateEmail), score, new Date().toISOString()]);
  return { ok: true };
}

function apiSubmitResult(idToken, matchId, teamAScore, teamBScore) {
  const user = authenticate_(idToken);
  const match = getMatch_(String(matchId));
  if (!match || !getPlayers_(match.id).some(function(p) { return p.userId === user.email; })) {
    throw new Error('Solo i partecipanti possono registrare il risultato.');
  }
  const a = Number(teamAScore);
  const b = Number(teamBScore);
  if (!Number.isInteger(a) || !Number.isInteger(b) || a < 0 || b < 0 || a === b) {
    throw new Error('Inserisci un risultato valido e non in parità.');
  }
  sheet_(SHEET_NAMES.results).appendRow([Utilities.getUuid(), match.id, user.email, a, b, new Date().toISOString()]);
  return { ok: true };
}

function apiCompleteMatch(idToken, matchId) {
  const user = authenticate_(idToken);
  requireAdmin_(user.email);
  const row = findRow_(sheet_(SHEET_NAMES.matches), 'matchId', String(matchId));
  if (!row) throw new Error('Partita non trovata.');
  sheet_(SHEET_NAMES.matches).getRange(row, 7).setValue('Completed');
  return apiBootstrap(idToken);
}

function apiAdminAddCourt(idToken, input) {
  const user = authenticate_(idToken);
  requireAdmin_(user.email);
  const name = cleanText_(input && input.name, 100);
  const address = cleanText_(input && input.address, 200);
  if (!name || !address) throw new Error('Nome e indirizzo del campo sono obbligatori.');
  sheet_(SHEET_NAMES.courts).appendRow([Utilities.getUuid(), '', name, address, true]);
  return sheetObjects_(SHEET_NAMES.courts);
}

function authenticate_(idToken) {
  if (!idToken || String(idToken).length > 10000) throw new Error('Accedi con Google per continuare.');
  const clientId = PropertiesService.getScriptProperties().getProperty('GOOGLE_CLIENT_ID');
  if (!clientId) throw new Error('Configurazione incompleta: manca GOOGLE_CLIENT_ID nelle Script Properties.');
  const response = UrlFetchApp.fetch('https://oauth2.googleapis.com/tokeninfo?id_token=' + encodeURIComponent(String(idToken)), {
    muteHttpExceptions: true,
  });
  if (response.getResponseCode() !== 200) throw new Error('Token Google non valido o scaduto. Accedi di nuovo.');
  const claims = JSON.parse(response.getContentText());
  const email = String(claims.email || '').toLowerCase();
  if (String(claims.aud || '') !== clientId) throw new Error('Il token non appartiene a questa applicazione.');
  if (claims.email_verified !== 'true' && claims.email_verified !== true) throw new Error('Google non ha verificato questa email.');
  if (!email.endsWith('@gmail.com')) throw new Error('Per questa beta è richiesto un account Gmail personale.');
  const issuer = String(claims.iss || '');
  if (issuer !== 'accounts.google.com' && issuer !== 'https://accounts.google.com') {
    throw new Error('Emittente del token Google non valido.');
  }
  return { email: email, name: String(claims.name || email.split('@')[0]) };
}

function ensureUser_(identity) {
  const sheet = sheet_(SHEET_NAMES.users);
  let row = findRow_(sheet, 'email', identity.email);
  if (!row) {
    sheet.appendRow([identity.email, identity.email, identity.name, '', '', '', true, new Date().toISOString()]);
    row = sheet.getLastRow();
  }
  return rowObject_(sheet, row);
}

function publicUser_(user) {
  return {
    userId: user.userId,
    email: user.email,
    name: user.name,
    category: user.category,
    position: user.position,
    gender: user.gender,
  };
}

function isAdmin_(email) {
  const list = (PropertiesService.getScriptProperties().getProperty('ADMIN_EMAILS') || '')
    .split(',')
    .map(function(value) { return value.trim().toLowerCase(); })
    .filter(Boolean);
  return list.indexOf(String(email).toLowerCase()) >= 0;
}

function requireAdmin_(email) {
  if (!isAdmin_(email)) throw new Error('Operazione riservata agli amministratori.');
}

function formatAcceptsGender_(format, gender) {
  if (format === 'Mens doubles') return gender === 'Male';
  if (format === 'Womens doubles') return gender === 'Female';
  return gender === 'Male' || gender === 'Female';
}

function matchScore_(match, currentPlayers, candidate) {
  const positions = currentPlayers.map(function(player) {
    const profile = getUser_(player.userId);
    return profile ? profile.position : '';
  });
  const occupied = positions.filter(function(position) { return position === 'Right' || position === 'Left'; });
  let position = candidate.position === 'Either' ? 12 : 0;
  let positionReason = candidate.position === 'Either' ? 'Posizione indifferente' : 'Posizione complementare';
  if (candidate.position === 'Right' && occupied.indexOf('Left') >= 0) position = 30;
  if (candidate.position === 'Left' && occupied.indexOf('Right') >= 0) position = 30;
  if (candidate.position === 'Right' && occupied.indexOf('Right') >= 0 && occupied.indexOf('Left') < 0) {
    position = -5;
    positionReason = 'Stessa posizione preferita del giocatore già presente';
  }
  if (candidate.position === 'Left' && occupied.indexOf('Left') >= 0 && occupied.indexOf('Right') < 0) {
    position = -5;
    positionReason = 'Stessa posizione preferita del giocatore già presente';
  }

  const difference = Math.abs(CATEGORIES.indexOf(candidate.category) - CATEGORIES.indexOf(match.category));
  const level = difference === 0 ? 25 : difference === 1 ? 18 : difference === 2 ? 10 : difference === 3 ? 4 : 0;
  const feedback = feedbackAffinity_(currentPlayers, candidate.userId);
  return {
    total: position + level + feedback,
    position: position,
    level: level,
    feedback: feedback,
    explanation: positionReason + '; compatibilità livello ' + level + '/25; feedback privato ' + feedback + '/10',
  };
}

function feedbackAffinity_(currentPlayers, candidateId) {
  const fromIds = currentPlayers.map(function(p) { return p.userId; });
  const feedback = sheetObjects_(SHEET_NAMES.feedback).filter(function(f) {
    return fromIds.indexOf(f.fromUserId) >= 0 && f.toUserId === candidateId;
  });
  if (!feedback.length) return 0;
  const average = feedback.reduce(function(sum, item) { return sum + Number(item.rating); }, 0) / feedback.length;
  return Math.round((average - 3) * 5);
}

function listMatches_() {
  return sheetObjects_(SHEET_NAMES.matches).map(function(match) {
    const players = getPlayers_(match.matchId);
    return {
      id: match.matchId,
      format: match.format,
      category: match.category,
      startsAt: match.startsAt,
      area: match.area,
      status: match.status,
      playerCount: players.length,
      playerCapacity: 4,
      courtId: match.courtId || '',
      canJoin: ['Open', 'Forming'].indexOf(match.status) >= 0 && players.length < 4,
    };
  }).sort(function(a, b) { return new Date(a.startsAt) - new Date(b.startsAt); });
}

function getMatch_(id) {
  const matches = sheetObjects_(SHEET_NAMES.matches);
  const match = matches.find(function(item) { return item.matchId === id; });
  if (!match) return null;
  return {
    id: match.matchId,
    createdBy: match.createdBy,
    format: match.format,
    category: match.category,
    startsAt: match.startsAt,
    area: match.area,
    status: match.status,
    courtId: match.courtId || '',
  };
}

function getPlayers_(matchId) {
  return sheetObjects_(SHEET_NAMES.players).filter(function(p) { return p.matchId === matchId; });
}

function getUser_(userId) {
  return sheetObjects_(SHEET_NAMES.users).find(function(user) { return user.userId === userId; }) || null;
}

function sheetObjects_(name) {
  const sheet = sheet_(name);
  const values = sheet.getDataRange().getValues();
  if (values.length < 2) return [];
  const headers = values[0];
  return values.slice(1).filter(function(row) {
    return row.some(function(value) { return value !== '' && value !== null; });
  }).map(function(row) {
    const item = {};
    headers.forEach(function(header, index) { item[header] = row[index]; });
    return item;
  });
}

function rowObject_(sheet, row) {
  const values = sheet.getRange(row, 1, 1, sheet.getLastColumn()).getValues()[0];
  const headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];
  const result = {};
  headers.forEach(function(header, index) { result[header] = values[index]; });
  return result;
}

function findRow_(sheet, header, value) {
  const headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];
  const column = headers.indexOf(header);
  if (column < 0 || sheet.getLastRow() < 2) return 0;
  const values = sheet.getRange(2, column + 1, sheet.getLastRow() - 1, 1).getValues();
  for (let index = 0; index < values.length; index++) {
    if (String(values[index][0]).toLowerCase() === String(value).toLowerCase()) return index + 2;
  }
  return 0;
}

function sheet_(name) {
  const id = PropertiesService.getScriptProperties().getProperty('SPREADSHEET_ID');
  if (!id) throw new Error('Esegui setupPadelCommunity() dal progetto Apps Script prima di usare la web app.');
  const spreadsheet = SpreadsheetApp.openById(id);
  const sheet = spreadsheet.getSheetByName(name);
  if (!sheet) throw new Error('Foglio mancante: ' + name + '. Esegui setupPadelCommunity().');
  return sheet;
}

function cleanText_(value, maxLength) {
  return String(value || '').trim().replace(/[<>]/g, '').slice(0, maxLength);
}
