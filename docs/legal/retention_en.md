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
| Notification inbox | Read 90 days, unread 365 days | Deleted |
| Push token | If unseen for 60 days | Deleted |
| Device identifier digest and IP records | 90 days | Deleted |
| Access-ban record | While the ban lasts and as needed for audit | Deleted / deactivated |
| Analytics events | 180 days | Deleted |
| E-mail queue (sent/failed) | 30 days | Deleted |
| Messages | While the account is open; remain as chat context after deletion (author anonymous) | Deleted if a limit is configured |
| Encrypted copy of deleted messages and edit history | Default indefinite (configurable) | Permanently deleted if a limit is set |
| Encrypted copy of view-once photos | 365 days (configurable) | Deleted; open record remains |
| Uploaded but unattached chat media | 24 hours | Deleted |
| Event chat room | Closes 7 days after the event | Room closed |
| Public (logged-out) support request | 365 days | Deleted |
| Support / feedback / appeal / report notes | Scrubbed when the account is deleted | Anonymous record remains |
| Agreement and consent records | Kept after deletion as proof | Until limitation periods end |
| Moderation violation and ban traces | Kept anonymously after deletion | While needed for security/evidence |
| Administrator action and message-access logs | Tamper-resistant; audit / legal period | May be archived then destroyed |
| Contact matching digests | **Not stored** | — |
| Location | **Not stored on the server** (not sent in the current version) | — |

## 3. When you delete your account

Deletion is **anonymisation**. Deleted: push tokens, inbox and preferences, bookmarks, votes and event feedback, block list, club application answers, community memberships, uploaded chat photos. Anonymised: name, e-mail, profile. Kept (anonymous/limited): messages and community posts (others' context), agreement acceptances, moderation traces, administrator records, anonymous event counters. Device/IP and analytics records are removed within their own periods. See the [Privacy Policy](/legal/privacy).

## 4. Legal retention duties

As a service provider we may be required by law (notably Law No. 5651 and its regulations) to retain certain access/traffic records for a fixed period. If such a duty applies, those records are kept for the legally required period and this text is updated. In the current version, device/IP security records are kept for the period stated above.

## 5. Destruction methods

Database records are deleted securely; files are removed from storage; anonymisation irreversibly replaces identifying fields; for encrypted data, access is closed together with the key. Removal from backups occurs within the backup cycle.

## 6. Your rights

Request deletion or anonymisation through the routes in the [KVKK Notice](/legal/kvkk) section 11; applications are answered within 30 days.

> **In short:** Most technical records are deleted automatically within days or months; messages and legal-proof records may remain longer in limited, anonymous form. Contact digests and location are not stored on the server.
