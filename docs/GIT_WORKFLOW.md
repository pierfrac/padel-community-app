# Git workflow

## Branches

- `main`: stable baseline only.
- `develop`: integration branch for tested work.
- `feature/<short-name>`: focused changes, branched from `develop`.
- `fix/<short-name>`: focused bug fixes, branched from `develop`.

## Changes

1. Create a feature branch from `develop`.
2. Keep changes focused and commits descriptive.
3. Run formatting, static analysis, and tests locally.
4. Open a pull request into `develop`.
5. Merge only after review and checks.
6. Promote tested releases from `develop` to `main`.

## Commit message examples

- `feat: add match request model`
- `fix: prevent duplicate match applications`
- `docs: clarify invitation expiry`
- `test: cover four-player match validation`

## Secrets

Never commit API secrets, signing keys, service-account files, local environment files, or production credentials. Use GitHub Actions secrets or local environment configuration for future integrations.
