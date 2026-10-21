# Windows launcher: portable Node.js + GitHub repository/branch picker

Double-click `avvia-padel-deploy.bat`. It downloads a pinned Windows x64 Node.js ZIP into `apps-script/.runtime/` only when needed. It does not install Node.js system-wide or modify the Windows PATH permanently.

## First use

1. Download the latest launcher files from the working branch.
2. Copy `.clasp.json.example` to `.clasp.json` and enter the Google Apps Script project ID.
3. Run `launcher/avvia-padel-deploy.bat` and choose **1** to authorize clasp with Google, if not already authorized.
4. Choose **2**, confirm with `PUSH`, then connect to GitHub.
5. The launcher lists accessible repositories and then branches. Select the repository and branch whose `apps-script/` folder contains `Code.gs`, `Index.html`, `appsscript.json`, and `.claspignore`.

## GitHub authentication

The launcher first tries to list repositories without a token. If authentication is required, it asks for a GitHub Personal Access Token (PAT) using a secure input prompt. The token is used in memory for that run and is not written to the repository or a configuration file. Grant the token access only to the repositories needed for deployment. For fine-grained tokens, grant read access to repository metadata and contents.

## What gets updated

The launcher downloads the four source/config files from the selected repository and branch into a staging folder. It replaces the local files only after all four have been retrieved successfully.

The local `.clasp.json` and portable Node runtime in `.runtime/` are left untouched. The four source/config files are replaced, so do not keep uncommitted local edits to those files that you want to preserve.

## Important

- This launcher targets Windows x64.
- It does not use GitHub Actions and does not require Git to be installed.
- The first launch downloads Node.js portable once; subsequent launches reuse it.
- `clasp push` uploads source files; it does not create a deployment or update the public `/exec` version.
- Confirm the Apps Script project is bound to the intended spreadsheet before pushing. The current backend relies on `SpreadsheetApp.getActiveSpreadsheet()`.
- Review Google authorization prompts carefully. Never commit the real `.clasp.json` or a GitHub token.
