# Padel Community

Flutter app for organizing padel matches and community availability.

## Run on Windows without administrator rights

The repository includes a portable Flutter launcher. It downloads the official Flutter stable SDK into a local `runtime` folder and does not modify the system PATH or install Flutter globally.

1. Clone or download the `develop` branch into a writable local folder.
2. Double-click `PADEL.bat`.
3. On first launch, wait for the Flutter SDK and Dart dependencies to download.
4. The app opens in your browser at `http://127.0.0.1:7357`. Keep the terminal open while using the preview.

The first download is large and requires HTTPS access to the official Flutter download host. Company proxy, antivirus, or execution policies may block it.

### Commands

Run `PADEL.bat` with one of these arguments from Command Prompt:

- `setup`: install the portable SDK and fetch dependencies.
- `web`: run the local Web preview (default).
- `format`: format Dart source files.
- `analyze`: run static analysis.
- `test`: run Flutter tests.
- `build`: compile the Web app into `build\web`.
- `check`: format, analyze, test, and build Web in sequence.
- `doctor`: show Flutter diagnostics.
- `clean`: remove project build/cache folders while keeping the SDK.

Detailed instructions: [docs/WINDOWS_FLUTTER_SETUP.md](docs/WINDOWS_FLUTTER_SETUP.md).

## Current scope

The current screens are an interactive UI prototype and still use demonstration data. Authentication, persistent storage, peer-to-peer synchronization, notifications, and real booking integrations are not implemented yet.

## Validation

GitHub Actions is configured to format, analyze, test, and build the Web target. Until a run is confirmed successful, use `PADEL.bat check` on a Windows machine as the local validation path; no successful CI or Windows execution is claimed by this README.
