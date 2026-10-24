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
  "function processInvites()",
  "function resetAllData(idToken,input)",
  "function installTriggers()"
]) assert.ok(gs.includes(required), "Missing backend function: " + required);

assert.ok(!/function\s+(getPrivateFeedback|submitPrivateFeedback)\s*\(/.test(gs), "Private feedback must not be exposed by the Apps Script backend");
assert.ok(html.includes("drive.file"), "Private feedback must use the narrow Drive file scope");
assert.ok(html.includes("function score(a,b)"), "Match Score must be present in the client");
assert.ok(gs.includes("token.aud!==clientId"), "Google ID token audience must be validated");
assert.ok(gs.includes("ALLOWED_EMAILS"), "Optional community allowlist must be supported");

const scoringMatch = html.match(/function rank\(level\)\{[\s\S]*?function renderSuggestions\(/);
assert.ok(scoringMatch, "Match Score functions must be extractable for tests");
const scoringSource = 'var privateFeedback={};' + scoringMatch[0].replace(/function renderSuggestions\($/, "");
const sandbox = {};
vm.runInNewContext(scoringSource, sandbox);
const left = {playerId:"left", skillLevel:"Silver", preferredSide:"left"};
const right = {playerId:"right", skillLevel:"Silver", preferredSide:"right"};
assert.equal(sandbox.score(left,right), 95, "Opposite sides and equal levels should score highly");
assert.equal(sandbox.score(left,{...right,preferredSide:"left"}), 55, "Same side should score lower");
sandbox.privateFeedback.right = {history:[{wouldPlayAgain:"yes"}]};
assert.equal(sandbox.score(left,right), 100, "Positive private feedback should raise the personalized score");
sandbox.privateFeedback.right = {history:[{wouldPlayAgain:"no"}]};
assert.equal(sandbox.score(left,right), 75, "Negative private feedback should lower the personalized score");

const webMatch = web.match(/<script>([\s\S]*?)<\/script>/);
assert.ok(webMatch, "web/index.html must contain its client script");
new vm.Script(webMatch[1], { filename: "web/index.html inline script" });
assert.ok(web.includes("drive.file") && !web.includes("google.script.run"), "Static page must use fetch and the Drive file scope");
assert.ok(gs.includes("function doPost(e)"), "Backend must expose the JSON API");

console.log("Padel Community static validation passed.");
