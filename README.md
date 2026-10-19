# Padel Community

Flutter app for organizing padel matches and community availability.

## Windows launcher

Double-click PADEL.bat to open the graphical launcher inspired by the portable TEO control panel. On first use, choose where Flutter and its caches should live: the default user profile, another disk (including an external drive), or an existing Flutter SDK.

The SDK, Flutter Web artifacts, Pub cache, configuration and logs are stored outside the repository by default under %LOCALAPPDATA%\PadelCommunity. This means redownloading the repository does not force another multi-gigabyte SDK download. Existing SDKs are reused when selected. The first download is still large; it is not repeated when the runtime folder is preserved.

The panel offers preview, setup, format, analyze, test, build, check and diagnostics. The app preview is served locally at http://127.0.0.1:7357. See docs/WINDOWS_FLUTTER_SETUP.md.

### Command-line actions

PADEL.bat setup, web, format, analyze, test, build, check, doctor and clean are supported. Double-click without arguments opens the graphical panel.

## Current scope

The current screens are an interactive UI prototype and still use demonstration data. Authentication, persistent storage, peer-to-peer synchronization, notifications, and real booking integrations are not implemented yet.

## Validation

GitHub Actions is configured to format, analyze, test, and build the Web target. Until a run is confirmed successful, use the local launcher on Windows as the validation path; no successful CI or Windows execution is claimed by this README.
