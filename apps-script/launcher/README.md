# Windows launcher: portable Node.js + branch sync

Double-click `avvia-padel-deploy.bat`. It downloads a pinned Windows x64 Node.js ZIP into `apps-script/.runtime/` only when needed. It does not install Node.js system-wide or modify the Windows PATH permanently.

## First use

1. Download the repository once, or keep your existing local project folder.
2. Copy `.clasp.json.example` to `.clasp.json` and enter the Google Apps Script project ID.
3. Run `launcher/avvia-padel-deploy.bat` and choose **1** to authorize clasp with Google.
4. Choose **2** when you want to deploy source updates. The launcher downloads only `Code.gs`, `Index.html`, `appsscript.json`, and `.claspignore` directly from the configured GitHub branch, then runs `clasp push`.

## What gets updated automatically

The configured source branch is `feature/google-sheets-calendar-web-mvp`. The launcher fetches individual source files over HTTPS; it does not download the repository ZIP and does not require Git to be installed.

The local `.clasp.json` and the portable Node runtime in `.runtime/` are left untouched. The four source/config files listed above are replaced by the branch versions, so do not keep uncommitted local edits to those files that you want to preserve.

## Important

- This launcher targets Windows x64.
- It does not use GitHub Actions.
- The first launch downloads Node.js portable once; subsequent launches reuse it.
- `clasp push` uploads source files; it does not create a deployment or update the public `/exec` version.
- Confirm the Apps Script project is bound to the intended spreadsheet before pushing. The current backend relies on `SpreadsheetApp.getActiveSpreadsheet()`.
- Review Google authorization prompts carefully. Never commit the real `.clasp.json`.
