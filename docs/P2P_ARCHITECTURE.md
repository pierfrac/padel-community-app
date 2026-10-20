# Padel Community — P2P-first architecture

## The product direction

Padel Community is a **local-first, peer-to-peer app**. This is a core product constraint, not an implementation detail to be quietly replaced by a conventional client/server design.

There must be no mandatory, operator-managed application server or central database that owns the authoritative match data. Each device stores its local data and participates in sharing and synchronizing the records it is authorized to access.

A static web host may deliver the Flutter Web files. Hosting the application UI is not the same thing as running a central application backend.

## Responsibilities

- **Google sign-in:** identifies a real Google account. It does not, by itself, grant admin privileges.
- **Invitations:** a participant creates a match invitation and shares its link using email, WhatsApp, or the operating system's share sheet. Email and messaging are invitation channels, not the match database or synchronization protocol.
- **Peers:** exchange match data and updates directly whenever the network allows it. Each peer keeps a local copy so previously received data can be consulted offline.
- **Admin peer:** holds administrative authority, including management of clubs, courts and official bookings. The admin is a peer, not a central application server.
- **Discovery/signaling:** a small third-party service may help peers find each other and exchange the connection information needed to establish a direct channel. It must not become the source of truth for match data.
- **STUN/TURN:** STUN may help direct connections across common NAT configurations. TURN may be used as an optional relay where direct connections fail. A relay transports traffic; it does not need to own the application data.

WebRTC is a candidate transport for browser-to-browser data channels. Direct connectivity cannot be guaranteed on every network, so the implementation must detect failure and explain when a peer or relay is unreachable.

## Trust and write rules

1. Google identity and application permissions are separate concerns.
2. Admin authority must come from a trusted allowlist/credential and be verifiable by peers. A client-controlled role flag, route or build define is only a local UI test switch and must never authorize production operations.
3. Shared writes are allowed only while the requesting user is connected and at least one authorized admin peer is reachable, as specified by the product rules. Admin presence is a connectivity/trust condition; it does not mean every ordinary change needs manual approval.
4. Official court bookings and administrative records can only be changed by an authorized admin.
5. If no authorized admin is reachable, shared writes must be held as pending or refused rather than shown as completed. Personal data and previously synchronized data remain available locally.
6. Events should carry stable identifiers, actor identity, timestamps, and signatures or equivalent integrity checks. Peers must be able to deduplicate replayed events and detect conflicting changes.
7. A link is only an invitation/locator. Its token must be unguessable, expirable, revocable where possible, and validated against the invited user when the invite is restricted to a recipient. Possessing a link must not grant admin access.

## Local test setup

The Windows panel can start four separate Flutter Web instances on one PC:

- Session 1: real Google sign-in UI for the admin test, once a Google OAuth Web Client ID is configured locally.
- Sessions 2–4: synthetic test players. They do not need Gmail accounts.
- Synthetic identities are strictly for testing the UI and local workflows; they are not real authenticated users or production authorization.
- Separate browser sessions/ports let us inspect four views, but they do **not** by themselves exchange data. No WebRTC transport or P2P synchronization is implemented yet.

The Google OAuth Web Client ID is public client configuration, not a client secret. It belongs in local launcher settings/environment and should not be committed as an application secret. Authorized JavaScript origins must include the exact local origin(s) used for the admin sign-in test.

## Implementation sequence

1. Keep the UI, local test identities and Google sign-in entry point separate from the transport layer.
2. Define peer identity, match event envelopes, local persistence, idempotency and conflict rules.
3. Implement direct WebRTC data channels for peers that can connect.
4. Add minimal rendezvous/signaling, preferably through a replaceable third-party provider, without moving match storage into it.
5. Add STUN configuration and optional TURN fallback; surface connection state to the user.
6. Replicate match events among connected peers, including admin presence checks, reconnection, replay protection and synchronization after offline periods.
7. Test the four local clients first, then two computers on different networks, including direct-connect failure and relay fallback.

## Explicit non-goal

Do not introduce a mandatory central application API/database merely to make the first demo easier. Any service proposed later must have a narrowly defined purpose, be replaceable, and preserve peer ownership and local copies of the application data.
