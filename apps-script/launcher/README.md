# Windows launcher: portable Node.js + clasp

Double-click `avvia-padel-deploy.bat`. It downloads a pinned Windows x64 Node.js ZIP into `apps-script/.runtime/` only when needed. It does not install Node.js system-wide or modify the Windows PATH permanently.

## First use

1. Make sure this repository has been downloaded/cloned and you are working in `apps-script/`.
2. Copy `.clasp.json.example` to `.clasp.json` and enter the Google Apps Script project ID.
3. Run `launcher/avvia-padel-deploy.bat` and choose **1** to authorize clasp with Google.
4. Run it again and choose **2** to upload source files.

The launcher uses npm's temporary package execution to run `@google/clasp`; it does not install clasp globally. Internet access is required for the initial Node.js and clasp downloads.

## Important

- This launcher targets Windows x64.
- It does not use GitHub Actions.
- `clasp push` uploads source files; it does not create a deployment or update the public `/exec` version.
- Confirm the Apps Script project is bound to the intended spreadsheet before pushing. The current backend relies on `SpreadsheetApp.getActiveSpreadsheet()`.
- Review Google authorization prompts carefully. Never commit the real `.clasp.json`.
- The portable Node.js ZIP is pinned to Node.js 22.16.0 for repeatability; update the version deliberately when maintaining the launcher.
