# Calendar behavior

## Internal community calendar

The app's internal calendar is the authoritative calendar for community activity and match workflow. It contains match requests, applications, confirmed matches, court assignments/bookings, availability indicators, and relevant status changes.

- Provide month and week views, with a clear agenda/list view for the selected day.
- Visually distinguish open requests, matches forming, confirmed matches, and items needing administrator action.
- A match is confirmed only when exactly four players are committed, all required approvals are complete, and an official valid court booking exists.
- Every match lasts 90 minutes and must fit the court booking slot.
- Internal calendar entries are managed by the app and synchronized using its planned authenticated peer-to-peer event model. They are not written to members' personal calendars by default.
- Court bookings are official only when recorded by an authorized administrator. A suggested court is not a booking.
- Do not create duplicate entries when an event changes. Use a stable event identifier and update/cancel the corresponding entry.
- Offline calendar views may show cached data and must indicate that it can be stale.

## Personal calendar integration

Only a user's own confirmed match should be optionally added to that user's personal device calendar.

- Ask for the required operating-system calendar permission and respect denial.
- Add an event only for the signed-in user's own confirmed match, not every community event or another player's match.
- Include match title, local start/end time, club/court when known, and concise participant details appropriate to the user's permissions.
- Use a stable mapping between the app match ID and the personal calendar event ID so updates modify the existing event instead of creating duplicates.
- When a confirmed match is rescheduled or cancelled, update or remove the corresponding personal event when permission and platform APIs allow it.
- The personal calendar is a convenience copy, not the source of truth for community match state or official court bookings.
- The user must be able to disable the integration and revoke calendar permission.

## Scope

The initial implementation should prioritize the internal calendar and match state model. Personal calendar integration should be an isolated adapter, introduced after the app can reliably confirm, reschedule, and cancel matches. Do not assume Google Calendar cloud API access: local device calendar access and Google Calendar API access are different integrations.
