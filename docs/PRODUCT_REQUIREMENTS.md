# Product requirements

## Product goal

Build a mobile app for coordinating padel matches within a community. Start with Android and keep the codebase compatible with iOS.

## Match rules

- Every match has exactly four players.
- Player categories: Bronze, Silver, Silver-Gold, Gold, Gold+.
- Match formats: men's doubles, women's doubles, ordinary mixed doubles (two men and two women), and exceptional mixed compositions.
- An exceptional mixed composition requires explicit approval from all four players. The woman must be in a higher category than the category requested for the match. The exact category gap remains to be decided.
- A match lasts 90 minutes and must fit the court's available time slot.

## Match creation and discovery

- A user can create a match request with known participants and vacant places, or publish an open request with preferred category, format, date/time, and area.
- Incomplete match requests are visible to the community so other members can apply.
- Invitations are direct and expire 120 minutes after being sent.
- If an invitation expires while the match is incomplete, the organizer chooses to cancel the match or publish the remaining places to the community.
- A match is not confirmed until it has four players, all required approvals, and a valid court booking.

## Courts and clubs

- The community contains clubs; each club has a list of courts.
- Administrators make official court bookings.
- Users may suggest alternative courts or slots, but suggestions do not change official bookings.
- Administrators are alerted when a match has four players but no court, or when no suitable court is available.

## Roles and permissions

- Administrators can access the community's management data.
- Members can access their own data and information explicitly shared with them.
- Members can identify authorized administrators and receive authenticated updates from them.
- Shared changes are allowed only while the acting member is online and at least one administrator is authenticated and reachable. Administrator presence is a connectivity/trust condition, not prior approval of each change.
- Shared changes must be auditable and synchronized. Administrators are notified about member changes.

## Identity

- Sign-in is limited to personal Google accounts; Google Workspace accounts are excluded.
- Use a stable Google identity subject identifier rather than email address alone.
- Administrator authorization must be controlled by a trusted allowlist or equivalent mechanism.

## Availability

- Members can define recurring weekly availability. Recurring availability is not a match confirmation.
- Offline reads may use cached data and must communicate that data can be stale.
- Shared writes are unavailable when the required online/admin-presence conditions cannot be met.

## Notifications

- Support persistent in-app notifications and distinct states for opened, viewed, and resolved.
- Important events include invitations, invitation expiry, incomplete matches, vacant places, court assignment problems, match cancellation/completion, administrator alerts, and a Saturday evening planning reminder.
- Push notifications may use APNs and FCM. Push delivery is not guaranteed to be instantaneous.
- A central application database is not part of the initial architecture.

## Decisions still required

- Withdrawals and cancellations after accepting an invitation.
- Rules for editing a confirmed match and when re-approval is required.
- Handling a cancelled or rescheduled court booking.
- Concurrent claims for the final available place.
- Which profile fields are visible to other members and administrators.
- Category assignment, category compatibility limits, and exact exceptional-mix category gap.
- Whether existing participants, the organizer, or another rule approves applications.
- Whether the organizer pays the entire court cost or coordinates a split.
- Detailed offline behavior and notification guarantees.
