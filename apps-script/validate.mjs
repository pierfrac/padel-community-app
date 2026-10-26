import fs from "node:fs";
import vm from "node:vm";
import assert from "node:assert/strict";

const gs = fs.readFileSync(new URL("./Code.gs", import.meta.url), "utf8");
const html = fs.readFileSync(new URL("./Index.html", import.meta.url), "utf8");
const web = fs.readFileSync(new URL("../web/index.html", import.meta.url), "utf8");
new vm.Script(gs, { filename: "Code.gs" });

const match = html.match(/<script>([\s\S]*?)<\/script>/);
assert.ok(match, "Index.html must contain its client script");
const client = match[1].replace(/<\?!= JSON\.stringify\(googleClientId\) \?>/g, '"test-client-id"');
new vm.Script(client, { filename: "Index.html inline script" });

for (const required of [
  "function verifyUser_(idToken)",
  "function saveProfile(idToken, input)",
  "function createMatch(idToken,input)",
  "function registerForMatch(idToken,input)",
  "function cancelRegistration(idToken,input)",
  "function completeMatch(idToken,input)",
  "function cancelMatch(idToken,input)",
  "function getIncompleteProfiles(idToken)",
  "function getMailList(idToken)",
  "function saveMailList(idToken,input)",
  "function previewEmail(idToken,input)",
  "function sendEmail(idToken,input)"
]) assert.ok(gs.includes(required), "Missing backend function: " + required);

assert.ok(!/function\s+(getPrivateFeedback|submitPrivateFeedback)\s*\(/.test(gs), "Private feedback must not be exposed by the Apps Script backend");
assert.ok(html.includes("drive.file"), "Private feedback must use the narrow Drive file scope");
assert.ok(html.includes("function score(a,b)"), "Match Score must be present in the client");
assert.ok(gs.includes("token.aud!==clientId"), "Google ID token audience must be validated");
assert.ok(gs.includes("ALLOWED_EMAILS"), "Optional community allowlist must be supported");

function loadScoring(source, label) {
  const found = source.match(/function rank\(level\)\{[\s\S]*?function renderSuggestions\(/);
  assert.ok(found, label + ": Match Score functions must be extractable for tests");
  const sb = {};
  vm.runInNewContext('var privateFeedback={};' + found[0].replace(/function renderSuggestions\($/, ""), sb);
  return sb;
}
const player = (side, extra = {}) => ({playerId: side, skillLevel: "Silver", preferredSide: side, ...extra});
const sandbox = loadScoring(html, "Index.html");
for (const [label, sb] of [["Index.html", sandbox], ["web/index.html", loadScoring(web, "web/index.html")]]) {
  // Base 50 + partner compatibility (position) + level closeness (+20 at equal level).
  assert.equal(sb.score(player("lefty"), player("left")), 80, label + ": mancino + sinistro is a bonus");
  assert.equal(sb.score(player("left"), player("right")), 80, label + ": sinistro + destro is a bonus");
  assert.equal(sb.score(player("lefty"), player("right")), 60, label + ": mancino + destro is a malus");
  assert.equal(sb.score(player("right"), player("right")), 45, label + ": destro + destro overlaps sides");
  assert.equal(sb.score(player("left"), player("left")), 45, label + ": sinistro + sinistro overlaps sides");
  assert.equal(sb.score(player("lefty"), player("lefty")), 45, label + ": mancino + mancino is a strong malus");
  assert.equal(sb.score(player("indifferent"), player("left")), 70, label + ": older profiles without a valid position have no compatibility effect");
}
const left = player("left"), right = player("right");
sandbox.privateFeedback.right = {history:[{wouldPlayAgain:"yes"}]};
assert.equal(sandbox.score(left,right), 100, "Positive private feedback should raise the personalized score");
sandbox.privateFeedback.right = {history:[{wouldPlayAgain:"no"}]};
assert.equal(sandbox.score(left,right), 60, "Negative private feedback should lower the personalized score");

const webMatch = web.match(/<script>([\s\S]*?)<\/script>/);
assert.ok(webMatch, "web/index.html must contain its client script");
new vm.Script(webMatch[1], { filename: "web/index.html inline script" });
assert.ok(web.includes("drive.file") && !web.includes("google.script.run"), "Static page must use fetch and the Drive file scope");
assert.ok(gs.includes("function doPost(e)"), "Backend must expose the JSON API");

// ---- Backend logic that does not need Google services ----
const backend = vm.runInNewContext(gs + "\n;({PAIR_MODIFIERS,POSITIONS,GENDERS,MAIL_BATCH,pairModifier_,pairScore_,isComplete_,selectAudience_,buildEmailBody_,parseEmails_,chunk_,validEmail_})", {});

// The server table and the browser table must agree for every combination, including older profiles.
for (const a of ["left","right","lefty","indifferent",""]) for (const b of ["left","right","lefty","indifferent",""])
  assert.equal(backend.pairModifier_(a,b), sandbox.pairModifier(a,b), "Server and browser compatibility differ for " + a + "/" + b);
assert.deepEqual(
  [["lefty","left"],["left","right"],["lefty","right"],["right","right"],["left","left"],["lefty","lefty"]].map(([a,b]) => backend.pairModifier_(a,b)),
  [10, 10, -10, -25, -25, -25]);

assert.equal(backend.isComplete_({gender:"F", preferredSide:"lefty"}), true);
assert.equal(backend.isComplete_({gender:"", preferredSide:"left"}), false, "Missing gender means incomplete");
assert.equal(backend.isComplete_({gender:"M", preferredSide:"indifferent"}), false, "Older 'indifferent' profiles are incomplete");

const roster = [
  {playerId:"a", displayName:"Anna", email:"a@x.it", skillLevel:"Silver", preferredSide:"left", gender:"F", emailOptOut:false, active:true},
  {playerId:"b", displayName:"Bruno", email:"b@x.it", skillLevel:"Silver", preferredSide:"right", gender:"M", emailOptOut:false, active:true},
  {playerId:"c", displayName:"Carlo", email:"c@x.it", skillLevel:"Silver", preferredSide:"lefty", gender:"M", emailOptOut:false, active:true},
  {playerId:"d", displayName:"Dora", email:"d@x.it", skillLevel:"Silver", preferredSide:"left", gender:"F", emailOptOut:true, active:true},
  {playerId:"e", displayName:"Enzo", email:"e@x.it", skillLevel:"Gold", preferredSide:"right", gender:"", emailOptOut:false, active:true}
];
const plain = (v) => JSON.parse(JSON.stringify(v)); // values built inside the vm context have another Array prototype
const pick = (o) => backend.selectAudience_({players:roster, matchPlayers:[], manual:[], max:20, ...o});
assert.deepEqual(plain(pick({sources:{registered:true,manual:false}, mode:"all"}).emails), ["a@x.it","b@x.it","c@x.it","e@x.it"], "Players who switched emails off are excluded");
assert.deepEqual(plain(pick({sources:{registered:true,manual:false}, mode:"incomplete"}).emails), ["e@x.it"]);
const withManual = pick({sources:{registered:true,manual:true}, mode:"all", manual:["B@x.it","z@x.it","d@x.it","not-an-address"]});
assert.deepEqual(plain(withManual.emails), ["a@x.it","b@x.it","c@x.it","e@x.it","z@x.it"], "Manual list is merged, de-duplicated and respects opt-outs");
const targeted = pick({sources:{registered:true,manual:true}, mode:"incomplete", manual:["z@x.it"]});
assert.deepEqual(plain(targeted.emails), ["e@x.it"]);
assert.equal(targeted.notes.length, 1, "The manual list is skipped, and the organizer is told, when the audience is filtered");
const byMatch = pick({sources:{registered:true,manual:false}, mode:"match", matchPlayers:[roster[2]], max:2});
assert.deepEqual(plain(byMatch.emails), ["a@x.it","b@x.it"], "With a mancino in the match the best candidates are the Sinistro first, then the Destro; players already in the match and opted-out players are left out");

const parsed = backend.parseEmails_("a@x.it, A@x.it; bad\nc@y.it");
assert.deepEqual(plain(parsed.valid), ["a@x.it","c@y.it"]);
assert.deepEqual(plain(parsed.invalid), ["bad"]);

const batches = backend.chunk_(Array.from({length:100}, (_, i) => i), backend.MAIL_BATCH);
assert.deepEqual(plain(batches.map(b => b.length)), [49,49,2]);
assert.ok(batches.every(b => b.length + 1 <= 50), "Each message, including the 'to' address, stays within 50 recipients");

const body = backend.buildEmailBody_({message:"Ciao <b>a tutti</b>", openMatches:[{when:"ven 30 ott, 20:30", venue:"Circolo Roma", free:1, link:"https://example.org/app/#match=abc"}], appUrl:"https://example.org/app/", support:"supporto@example.org"});
assert.ok(body.includes("1 posto libero") && body.includes("#match=abc"), "Open matches are listed with their link");
assert.ok(body.includes("supporto@example.org") && body.includes("STOP") && body.includes("riservatezza"), "Every email carries the support contact, the confidentiality note and the opt-out instruction");
assert.ok(!body.includes("<"), "Message text is stripped of markup");
assert.ok(backend.buildEmailBody_({message:"", openMatches:[], appUrl:"", support:"s@x.it"}).includes("Al momento non ci sono partite aperte."));

// Organizer-only functions must check the administrator role, and recipients must stay in Bcc.
for (const name of ["getIncompleteProfiles(idToken)","getMailList(idToken)","saveMailList(idToken,input)","previewEmail(idToken,input)","sendEmail(idToken,input)"]) {
  const at = gs.indexOf("function " + name);
  assert.ok(at >= 0 && gs.slice(at, at + 220).includes("requireAdmin_(user)"), name + " must be restricted to administrators");
}
assert.ok(gs.includes("bcc:chunk.join"), "Organizer emails must put recipients in Bcc");
assert.ok(gs.includes("if (own || user.isAdmin) p.gender"), "Gender must be visible only to the player and to administrators");

// ---- Front end ----
for (const [label, page] of [["Index.html", html], ["web/index.html", web]]) {
  for (const needed of ['id="profileAlert"', 'id="adminPanel"', 'id="gender"', 'value="lefty"', "function renderAlert()", '"previewEmail"', '"sendEmail"'])
    assert.ok(page.includes(needed), label + " is missing " + needed);
  assert.ok(!page.includes("Lato preferito"), label + " still shows the old side preference");
}

console.log("Padel Community static validation passed.");
