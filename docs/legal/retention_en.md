# Personal Data Retention and Destruction (Summary)

*This English text is provided for information only. The Turkish text is authoritative.*

This summary shows how long your personal data is kept and what happens afterwards. Periods are defined in application settings and may be changed by the Operator, in which case this text is updated.

## 1. Principles

Data is kept for the time needed for its purpose and as permitted by law, then **deleted**, **destroyed** or **anonymised** by nightly jobs. Where a legal retention duty exists, data is kept for that period.

## 2. Retention periods

| Data | Period | After |
|---|---|---|
| Pending (unverified) registration | 1 hour | Deleted |
| Verification / reset code | 10 minutes (max 5 attempts) | Invalid / deleted |
| Access token | 15 minutes | Expires |
| Refresh token (as digest) | At most 30 days; removed earlier on logout, password change or new mobile login | Deleted |
| Notification inbox | Read 30 days, unread 90 days; the newest 200 notifications per user are kept | Deleted |
| Push token | If unseen for 60 days | Deleted |
| Device identifier digest and IP records | 90 days (immediately on account deletion) | Deleted |
| Inappropriate-language filter log (field, user, time; no text) | 90 days | Deleted |
| Push notification queue | Pending retried for at most 24 hours; sent 7 days, failed 30 days | Deleted |
| Media files of a deleted post (Discover) | 30 days | Removed from disk and database |
| Image attached to a club post | Immediately when the post is deleted, the club is closed or the account is deleted | Removed from disk |
| Uploaded media not attached to a post | 24 hours | Deleted |
| Follows, bookmarked news, personal timetable and exam data | While the account is open | Deleted with the account |
| Poll vote record | While the account is open | On deletion the link to the user is removed (anonymous counter remains); participation record deleted |
| Access-ban record | While the ban lasts and as needed for audit | Deleted / deactivated |
| Raw analytics events (screen/event name, time) | 45 days (immediately on account deletion) | Deleted; only non-personal, aggregated daily summaries remain permanently |
| Daily activity record (which days you opened the app) | 400 days (immediately on account deletion) | Deleted |
| E-mail queue | Sent 7 days, failed (undeliverable) 30 days | Deleted |
| Administrator announcement e-mail (campaign) records: campaign and recipient rows | 180 days after the campaign ends (your recipient row is deleted at once when you delete your account) | Deleted |
| Messages | While the account is open; remain as chat context after deletion (author anonymous) | Deleted if a limit is configured |
| Encrypted copy of deleted messages and edit history | Default indefinite (configurable) | Permanently deleted if a limit is set |
| Encrypted copy of view-once photos | 365 days (configurable) | Deleted; open record remains |
| Uploaded but unattached chat media | 24 hours | Deleted |
| Event chat room | Closes 7 days after the event | Room closed |
| Public (logged-out) support request | 365 days | Deleted |
| Support / feedback / appeal / report notes | Scrubbed when the account is deleted | Anonymous record remains |
| Agreement and consent records | Kept after deletion as proof | Until limitation periods end |
| Moderation violation and ban traces | Kept anonymously after deletion | While needed for security/evidence |
| Administrator action log (including IP) | 365 days | Deleted |
| Message-access log and club administration action log | 730 days (entries are append-only and cannot be altered) | Deleted when the period ends |
| Contact matching digests | **Not stored** | — |
| Location | **Not collected or stored** (the app does not ask for location permission) | — |

## 3. When you delete your account

Deletion is **anonymisation**. Deleted: push tokens and pending push entries, inbox and preferences, follows, timetable and exam data, poll participation record, likes, Discover posts (media after 30 days), bookmarks, votes and event feedback, block list, club application answers, community memberships, e-mail campaign recipient rows, uploaded chat photos, **your device/IP records, analytics events and daily activity record (immediately)**, and images you attached to club posts (immediately, from disk). Your event applications are closed (the next person on the waiting list moves up) and unfinished events you created that are not tied to a club are cancelled. If you own a club, ownership passes to its longest-standing active administrator; if there is none, the club is closed and its members are notified. Anonymised: name, e-mail, profile. Kept (anonymous/limited): the text of messages and community posts (others' context), agreement acceptances, moderation traces, administrator records, anonymous event counters. Other records are removed within the periods in the table above. See the [Privacy Policy](/legal/privacy).

## 4. Legal retention duties

As a service provider we may be required by law (notably Law No. 5651 and its regulations) to retain certain access/traffic records for a fixed period. If such a duty applies, those records are kept for the legally required period and this text is updated. In the current version, device/IP security records are kept for the period stated above.

## 5. Destruction methods

Database records are deleted securely; files are removed from storage; anonymisation irreversibly replaces identifying fields; for encrypted data, access is closed together with the key. Removal from backups occurs within the backup cycle.

## 6. Your rights

Request deletion or anonymisation through the routes in the [KVKK Notice](/legal/kvkk) section 11; applications are answered within 30 days.

> **In short:** Most technical records are deleted automatically within days or months; messages and legal-proof records may remain longer in limited, anonymous form. Contact digests are not stored and location is never collected.
