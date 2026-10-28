# Privacy Policy

*This English text is provided for information only. The Turkish text is authoritative.*

This policy explains which of your data is processed, why, for how long, and your rights. Read it together with the [KVKK Notice](/legal/kvkk).

Controller: {{controller.name}}{{?controller.address}}, {{controller.address}}{{/controller.address}}. Contact: {{controller.email|in-app Support section}}.

## 1. In short

1. We do **not sell** your data or share it for advertising.
2. We process only what is needed to provide the service, keep it secure and meet legal obligations.
3. Optional permissions (contacts, push notifications) rely on your **explicit consent** and can be withdrawn at any time ([Explicit Consent](/legal/explicit-consent)). The app does **not ask for, collect or store your device location**.
4. Messages are stored encrypted but the system is **not end-to-end encrypted**; authorised administrators may view them for stated reasons, with every access logged.
5. Deleting your account anonymises your data; some records remain in limited form for legal reasons and to protect others.

## 2. Data we process

| Data | Why | Legal basis | Retention |
|---|---|---|---|
| **Account:** e-mail (bingol.edu.tr), name, password (one-way hash only), language | Membership, authentication | Contract (KVKK 5/2-c) | While the account is open; anonymised on deletion |
| **Profile:** faculty, department, year, bio, avatar, privacy settings | Showing your profile (field-level visibility) | Contract; explicit consent for optional fields | While the account is open |
| **Pending registration / code:** e-mail, code digest | E-mail verification | Contract | Pending registration 1 hour; code 10 minutes |
| **Session:** refresh token digest | Secure sessions | Legitimate interest | At most 30 days; removed on logout/password change |
| **Messages:** text, photos, videos, edit history, reactions, read state, chat settings | Messaging | Contract | While the account is open; encrypted copies of deleted messages and edit history kept for security (default indefinite, configurable) |
| **View-once photo:** encrypted file, open record | Messaging; security review | Contract; legitimate interest | Recipient access once / max 24 h; encrypted copy for admin review **365 days** (configurable) |
| **Community and event data:** memberships, posts, RSVP, attendance, application answers | Community and event features | Contract | While the account is open; some records stay anonymous |
| **Posts (Discover):** text, photos, videos, hashtags (#), mentions (@), likes, comments | Posting and interaction | Contract | While the account is open; after a post is deleted its media files are removed from disk after 30 days; uploads not attached to a post are deleted after 24 hours |
| **Stories:** photo/video, text, viewers | 24-hour temporary sharing | Contract | Visible for 24 hours; permanently deleted 24 hours after expiry (configurable) |
| **Follows and saved posts** | Building your feed, saving items for later | Contract | While the account is open; deleted with the account |
| **Polls:** participation record and your vote | Voting | Contract | While the account is open; on account deletion the participation record is deleted and the vote is detached from you. In a secret poll, which option you chose is not shown to other users or administrators. No separate automatic deletion period applies to the vote records of finished polls. |
| **Timetable, course and exam data:** courses, sessions, semester and exams you enter yourself; announcement read marks | Personal timetable and exam tracking | Contract | While the account is open; deleted with the account |
| **Notification inbox and preferences** | Notifications | Contract | Read 90 days, unread 365 days |
| **Device push token (FCM):** token, platform, app version, language, last seen | Push notifications | Contract; explicit consent (notification permission) | Removed after 60 days unseen; on logout/deletion |
| **Push notification queue:** target user/device, title and short text, delivery status | Delivering push notifications from a durable queue with retries | Contract | Pending entries are retried for at most 24 hours; sent entries are deleted after 7 days, failed ones after 30 days; deleted on logout/account deletion |
| **Inappropriate-language filter log:** which field, which user's content was rejected/flagged, and when (the rejected text is not stored) | Preventing abuse in public areas | Legitimate interest | 90 days |
| **Device and IP records:** non-reversible HMAC digest of device identifier, platform, app version, IP, last seen and event type | Security, abuse prevention, ban evasion | Legitimate interest; legal obligation | Default **90 days**; ban records while a ban lasts |
| **Usage events (analytics):** screen, event name, limited values, time | Improving the service; reports are aggregated | Legitimate interest | **180 days** |
| **Support, feedback, appeals, reports** | Handling requests, moderation | Contract; legitimate interest; legal obligation | Texts scrubbed on account deletion; public (logged-out) tickets 365 days |
| **Blocks and moderation records** | Safety and moderation | Legitimate interest; legal obligation | Moderation trail kept anonymously |
| **Administrator action and message-access logs** | Accountability | Legitimate interest; legal obligation | Tamper-resistant; for legal/audit period |
| **Agreement acceptances:** document, version, time | Proof of acceptance | Legal obligation; legitimate interest | Kept after account deletion |
| **E-mail queue:** recipient, subject, status | Verification, reset and security e-mails | Contract | Sent/failed entries deleted after 30 days |
| **Contact matching:** SHA-256 digests of e-mails in your address book | Finding people you know | **Explicit consent** | **Not stored or logged**; in memory only while the request is processed |
| **Device location** | — | — | The app does **not ask for location permission**; device location (GPS/network) is **not collected, sent or stored** (see 5) |

> **In short:** Device/IP records 90 days, analytics 180 days, notifications 90/365 days, e-mail queue 30 days.

## 3. How messages are stored and who can see them

1. Transit: TLS/WSS. Storage: AES-256-GCM with a separate key per conversation, protected by a master key held in the server environment, not in the database.
2. **Not end-to-end encrypted.** Because we hold the master key, the system can decrypt messages.
3. Authorised administrators may view messages and media for report reviews, security/abuse, and legal requests. The admin view can also show deleted, edited and moderation-hidden messages, view-once photos and messages not delivered because of a block. **Every view is automatically written to a tamper-resistant record before content is shown** (who, whose chat, how many messages, IP, time); if logging fails, content is not shown.
4. "Delete for everyone" hides the message from users; the encrypted copy and previous versions may be retained for security (default indefinite).
5. View-once photos: recipient sees once; the encrypted file is kept 365 days (configurable) for administrator review, then deleted. No absolute guarantee against screenshots.
6. Push previews: by default message text is not shown in push notifications; the in-app inbox never stores message content.
7. Photos are validated and re-encoded, EXIF removed; chat videos are compressed on your device and are not re-encoded by the server (they are stored encrypted with a per-conversation key). Post (Discover) videos are re-encoded on the server after upload (H.264, at most 720p, AAC audio, metadata such as GPS removed) and stored on disk encrypted with a random per-file key that is itself wrapped by the master key; until re-encoding finishes the encrypted original stays playable and is then deleted. Image digests are matched against a prohibited-content digest list; images are not analysed automatically.
8. Blocking: messages from someone you blocked are not delivered to you and the blocked person is not notified; they remain stored and visible to authorised administrators during report reviews.

## 4. Who we share data with

| Recipient | What | Purpose | Location |
|---|---|---|---|
| **Google Firebase Cloud Messaging** (and Apple APNs for iOS) | Device push token, notification title/short text, target | Push delivery | Outside Türkiye |
| **E-mail (SMTP) provider** | Recipient address, e-mail content | Verification, reset, security e-mails | {{hosting.location|Provider's country}} |
| **Hosting provider** | All service data (messages encrypted) | Hosting | {{hosting.location|Stated before publication}} |
| **Competent public authorities** | Data within the request | Legal obligation | Türkiye |
| **University / authorised administrators** | Data needed for moderation and support | Service administration | Türkiye |

We do not share data with ad networks, data brokers or social-media trackers.

## 5. Permissions

1. **Notifications:** optional; notification types and **quiet hours** are configurable. Without permission, the in-app inbox still works.
2. **Contact matching:** only SHA-256 digests of e-mails (up to 500 per request) are sent; they are **not stored or logged**; names and phone numbers are never sent.
3. **Location:** the app does **not ask for location permission** and does not collect, send or store your location. The IP address recorded for security (see 6) is not device location, and the application code does not infer location or region from IP addresses. Hosting and network infrastructure providers may keep their own technical logs under their own policies; we do not use them to determine location. If location is ever processed we will update this text and ask for consent again.

## 6. Device/IP records and access bans

Device-identifier digest, platform, app version, IP and time are recorded on registration, login, refresh and requests for security. The raw identifier is not stored. Records are kept **90 days** by default (configurable); if a legal retention duty arises (e.g. Law No. 5651 traffic data) the period may change and this policy will be updated. Access bans (IP, network range, device digest or user) keep reason code, date, optional expiry and notes while the ban lasts; blocked attempts are logged as security records. Requests from anonymising networks may be restricted. You may contest a ban via Support or the appeal feature.

## 7. Account deletion and data export

**Download my data:** Profile > Download my data (JSON, up to 3 per day; deleted messages excluded).

**Account deletion = anonymisation**

| What happens | Data |
|---|---|
| **Deleted** | Push tokens and pending push entries, notification inbox and preferences, saved posts, follows, stories, timetable and exam data, poll participation record, likes and comments (comments on others' posts show as deleted), Discover posts (media files removed after 30 days), bookmarks, feedback votes and event feedback, block list, club application answers, community memberships, chat photos you uploaded |
| **Anonymised** | Name, e-mail, profile, bio, photo; poll vote records (link to you removed); support, feedback, appeal, report and event application texts are scrubbed |
| **Kept (limited)** | Messages and community posts (others' context; author appears anonymous), agreement acceptances, moderation records, anonymous attendance/RSVP counters, administrator action and access logs |
| **Cleaned by time** | Device/IP records (90 days), language-filter log (90 days), analytics (180 days), e-mail queue (30 days) |

## 8. Security

One-way password hashes; digests of codes and refresh tokens; 15-minute access tokens; single-use refresh tokens; rate limits; generic responses that do not reveal whether an account exists; encrypted message storage; logged administrator access; validated uploads. No system is perfectly secure; in a breach we notify the Board and affected persons as required.

## 9. Cookies and local storage

No tracking or advertising cookies. See the [Cookie Policy](/legal/cookies).

## 10. Children

The service is not designed for persons under 18; if such a registration is found we may require a legal representative's consent or close the account.

## 11. Posts, stories, comments and content moderation

1. Posts, comments, stories, hashtags (#) and mentions (@) are shown to other signed-in users; visibility is mutually closed with users you block or who block you. Any visibility options offered in the app are shown on the relevant screen.
2. Mentioning a user with `@` may send them a notification.
3. Stories are visible for 24 hours; the story owner can see who viewed it; they are permanently deleted 24 hours after expiry.
4. **Language filter.** Insults, abuse, hate speech or sexually explicit expressions in public areas (communities, events, profiles, group titles, posts, comments, stories) may be rejected automatically. **Chat messages (one-to-one and group) are not pre-screened.** The filter acts at submission time; which field and which user's content was rejected is kept for 90 days, the rejected text is not stored. The decision is automatic without human review; you may contest it through Support.
5. **Reports and removal.** Posts, comments, stories and messages can be reported with **Report**; authorised administrators review and may hide or remove content. See [Content Notice and Removal](/legal/content-removal) and the [Community Rules](/legal/community-rules).

## 12. Your rights, changes, contact

Your KVKK Article 11 rights and the application route (30-day response) are in the [KVKK Notice](/legal/kvkk). We may update this policy; for material changes we ask for re-acceptance. Contact: {{support.email|in-app Support section}}{{?controller.email}} · {{controller.email}}{{/controller.email}}{{?controller.kep}} · KEP: {{controller.kep}}{{/controller.kep}}
