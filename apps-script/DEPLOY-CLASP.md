# Deploy from GitHub to Google Apps Script with clasp

This workflow keeps GitHub as the source of truth and avoids copying code file-by-file into the Apps Script editor. It does **not** use GitHub Actions.

## Requirements

- Node.js (includes npm), installed on the computer used for deployment.
- Access to the Google account that owns the Apps Script project.
- The Apps Script project ID.

If Node.js is not already installed, this route is not zero-install. Do not install anything on a managed work computer without permission.

## One-time setup

1. Download or clone this repository and check out branch `feature/google-sheets-calendar-web-mvp`.
2. Open a terminal in the `apps-script` folder.
3. Copy `.clasp.json.example` to `.clasp.json`.
4. Edit `.clasp.json` and replace `PASTE_YOUR_APPS_SCRIPT_ID_HERE` with the project ID. Keep the real `.clasp.json` local; do not commit it.
5. Sign in to Google once:

   ```powershell
   npx --yes @google/clasp login
   ```

6. Push the files from this folder to the Apps Script project:

   ```powershell
   npx --yes @google/clasp push
   ```

   Review the confirmation carefully before accepting an overwrite.

## Subsequent updates

After pulling the intended GitHub branch and reviewing the changes, run from `apps-script`:

```powershell
npx --yes @google/clasp push
```

This uploads source files. It does **not** automatically create or update a deployed web-app version. Deployment and access settings must still be configured in the Apps Script UI, unless a deliberate deployment workflow is added later.

## Important blocker for this project

The current backend uses `SpreadsheetApp.getActiveSpreadsheet()`. That works when the Apps Script project is opened from a Google Sheet (a container-bound script), but may return no spreadsheet for a standalone script. Before relying on this deployment path, confirm whether the project is bound to the intended Padel Community spreadsheet. If it is standalone, the backend must be changed to open a configured spreadsheet ID instead.

## Before sharing the app

A successful `clasp push` only confirms that source files were uploaded. It does not prove that Google sign-in, Drive feedback, Calendar permissions, or the web app work. Run `setupPadelCommunity` in the correct spreadsheet context, configure Script Properties, deploy as a web app, and test with at least two Google accounts before sharing the `/exec` URL.
