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
  "function setPartner(idToken,input)",
  "function setLineup(idToken,input)",
  "function setCourt(idToken,input)",
  "function resendInvite(idToken,input)",
  "function testMail()",
  "function startSession(idToken)",
  "function endSession(idToken)",
  "function processInvites()",
  "function resetAllData(idToken,input)",
  "function lookupEmail(idToken,input)",
  "function createShareLink(idToken,input)",
  "function trackOpen(idToken,input)",
  "function respondToLink(idToken,input)",
  "function forgetDevice(idToken,input)",
  "function inviteToCommunity(idToken,input)",
  "function createCommunityLink(idToken,input)",
  "function getSettings()",
  "function disclaimer_()",
  "function isAdminEmail_(email)",
  "function installTriggers()"
]) assert.ok(gs.includes(required), "Missing backend function: " + required);

assert.ok(!/function\s+(getPrivateFeedback|submitPrivateFeedback)\s*\(/.test(gs), "Private feedback must not be exposed by the Apps Script backend");
assert.ok(html.includes("drive.file"), "Private feedback must use the narrow Drive file scope");
assert.ok(html.includes("function score(a,b)"), "Match Score must be present in the client");
assert.ok(gs.includes("token.aud!==clientId"), "Google ID token audience must be validated");
assert.ok(gs.includes("ALLOWED_EMAILS"), "Optional community allowlist must be supported");

const scoringMatch = web.match(/function rank\(level\)\{[\s\S]*?function renderSuggestions\(/);
assert.ok(scoringMatch, "Match Score functions must be extractable for tests");
const scoringSource = 'var privateFeedback={};' + scoringMatch[0].replace(/function renderSuggestions\($/, "");
const sandbox = {};
vm.runInNewContext(scoringSource, sandbox);
const left = {playerId:"left", skillLevel:"Silver", preferredSide:"left"};
const right = {playerId:"right", skillLevel:"Silver", preferredSide:"right"};
assert.equal(sandbox.score(left,right), 95, "Opposite sides and equal levels should score highly");
assert.equal(sandbox.score(left,{...right,preferredSide:"left"}), 40, "Two Sinistro players: strong malus");
assert.equal(sandbox.score(right,{...right}), 40, "Two Destro players: strong malus");
const lefty = {playerId:"lefty", skillLevel:"Silver", preferredSide:"lefty"};
assert.equal(sandbox.score(lefty,left), 95, "Mancino + Sinistro: bonus");
assert.equal(sandbox.score(lefty,right), 55, "Mancino + Destro: malus");
assert.equal(sandbox.score(lefty,{...lefty}), 40, "Two Mancino players: strong malus");
sandbox.privateFeedback.right = {history:[{wouldPlayAgain:"yes"}]};
assert.equal(sandbox.score(left,right), 100, "Positive private feedback should raise the personalized score");
sandbox.privateFeedback.right = {history:[{wouldPlayAgain:"no"}]};
assert.equal(sandbox.score(left,right), 75, "Negative private feedback should lower the personalized score");

const webMatch = web.match(/<script>([\s\S]*?)<\/script>/);
assert.ok(webMatch, "web/index.html must contain its client script");
new vm.Script(webMatch[1], { filename: "web/index.html inline script" });
assert.ok(web.includes("drive.file") && !web.includes("google.script.run"), "Static page must use fetch and the Drive file scope");
assert.ok(gs.includes("function doPost(e)"), "Backend must expose the JSON API");

for (const required of ["function prepareBroadcast(idToken, input)","function saveMailList(idToken, input)","function detailsComplete_(r)","function seatSide_(side)","mailOptOut"]) assert.ok(gs.includes(required), "Missing: " + required);
// Pure helpers from Code.gs, run in isolation.
const ctx = {};
vm.runInNewContext(gs.match(/function seatSide_[^\n]*/)[0] + gs.match(/function pickSlot_[\s\S]*?\n}\n/)[0] + gs.match(/const EMAIL_RE_[^\n]*/)[0].replace("const","var") + gs.match(/function parseEmails_[\s\S]*?\n}\n/)[0] + gs.match(/function chunk_[^\n]*/)[0], ctx);
const plain = v => JSON.parse(JSON.stringify(v));
const empty = () => [0,1,2,3].map(()=>({playerId:"",name:"",email:""}));
assert.equal(ctx.pickSlot_(empty(),"lefty"), 0, "Mancino sits on the right");
assert.equal(ctx.pickSlot_(empty(),"left"), 1, "Sinistro sits on the left");
assert.deepEqual(plain(ctx.parseEmails_("A@b.it, a@b.it; x ,c@d.com")), {emails:["a@b.it","c@d.com"],invalid:["x"]});
assert.deepEqual(plain(ctx.chunk_([1,2,3,4,5],2)), [[1,2],[3,4],[5]]);
assert.ok(web.includes("function updateDetailsBanner") && web.includes('server("prepareBroadcast"'), "Banner and admin mail panel must be present");
console.log("Padel Community static validation passed.");
