# Architecture

## Initial direction

- Flutter and Dart, Android first, iOS-compatible codebase.
- Local persistence: SQLite, introduced with the data layer.
- Google sign-in for personal Google accounts only.
- Feature modules: authentication, matches, availability, clubs/courts, notifications, synchronization.
- Keep business rules independent from UI and transport implementation.

## Peer-to-peer synchronization

The intended model has no mandatory central application database. Changes to shared data are authenticated events, not unverified overwrites. Each event should carry an identifier, entity identifier, author identity, timestamp, schema version, and enough information to detect duplicates and conflicts.

Shared writes require the acting member to be online and at least one authorized administrator to be authenticated and reachable. The administrator's presence is not a per-change approval step. The app should record the change and notify administrators.

Direct peer-to-peer communication over the public internet needs peer discovery/rendezvous and may need an optional relay for NAT traversal. A relay can forward encrypted/authenticated traffic without becoming the application's database. The concrete transport is an open technical decision and must be validated before promising reliable delivery.

## Offline behavior

- Cached reads may be available offline and must indicate that data may be stale.
- Shared writes must not be treated as successful when the required online conditions are missing.
- A local persistent queue can retain pending operations, but cannot guarantee delivery if a device is lost or never reconnects.
- Expiring invitations are evaluated from their authoritative timestamps on reconnect; expired invitations must not become active again.

## Notifications

Use an in-app event/inbox model as the durable user-facing history. APNs/FCM may be added for push delivery when the app is closed. Push providers are notification transport, not the source of truth for community data. Scheduled notifications require a reliable scheduling strategy; device-only scheduling has limitations.

## Backup

Cloud Drive backup is out of scope for the MVP. Keep backup behind a separate abstraction so an administrator-managed Drive backup can be considered later without coupling it to synchronization.

## Security principles

- Do not store client secrets or private keys in source control.
- Treat email addresses as profile/contact attributes, not as stable identity keys.
- Keep administrator authorization separate from UI visibility.
- Validate permissions and event authorship at the receiving peer.
- Do not claim that a local event is globally synchronized until peers have acknowledged it.
