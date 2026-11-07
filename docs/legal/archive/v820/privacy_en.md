# Privacy Policy

*This English text is a translation provided for information only. The Turkish text is authoritative; if there is any difference, the Turkish text prevails.*

This policy explains in plain language which of your data is processed while you use the BÜ Kampüs application and website, why, how long it is kept, and your rights. For the legal framework and the application procedure, read it together with the [KVKK Privacy Notice](/legal/kvkk).

Data controller: {{controller.name}}{{?controller.address}}, {{controller.address}}{{/controller.address}}. Contact: {{controller.email|in-app Support section}}.

## 1. In short

1. We do **not sell** your data and do not share it with third parties for advertising.
2. We process only the data necessary to provide the service, ensure security and meet legal obligations.
3. Optional permissions such as contact matching and push notifications depend on your **explicit consent** and can be withdrawn at any time ([Explicit Consent text](/legal/explicit-consent)). The app **does not ask for, collect or store your device location**.
4. Your messages are stored encrypted on the server; however, the system is **not end-to-end encrypted** and authorised administrators may view messages in reasoned cases, with the access being recorded.
5. If you delete your account, your personal data is anonymised; some records remain in limited form for legal reasons and to protect the rights of others.

## 2. What data do we process?

| Data | Why | Legal basis | Retention period |
|---|---|---|---|
| **Account:** e-mail (bingol.edu.tr), name, password (only as a one-way digest), language preference | Membership, authentication, providing the service | Performance of a contract (KVKK Art. 5/2-c) | While the account is open; anonymised on deletion |
| **Profile:** faculty, department, year, biography, profile photo, your privacy settings | Showing your profile to other users (can be hidden field by field) | Performance of a contract; explicit consent for optional fields (Art. 5/1) | While the account is open |
| **Pending registration and verification code:** e-mail, digest of the code | E-mail verification | Pre-contractual step / performance of a contract | Pending registration 1 hour; verification code 10 minutes |
| **Session:** digest of the refresh token, session state | Secure session management | Legitimate interest (Art. 5/2-f) | Refresh token at most 30 days; deleted on sign-out/password change |
| **Messages:** text, photos, videos, edit history, reactions, read state, chat settings (mute/archive) | Messaging service | Performance of a contract | While the account is open; the encrypted copy and edit history of deleted messages are kept for security (default indefinite, adjustable) |
| **View-once photo:** encrypted file, open record | Messaging and security review | Performance of a contract; legitimate interest | Recipient access once / at most 24 hours; encrypted copy for administrator review **365 days** (adjustable) |
| **Community and event data:** memberships, posts, RSVP, attendance (QR/manual), application answers, event feedback | Community and event services | Performance of a contract | While the account is open; attendance/post records may remain anonymously |
| **Posts (Discover):** a single photo, a short text of at most 7 words, likes | Sharing posts and interaction | Performance of a contract | While the account is open; after a post is deleted its media file is removed from disk after 30 days; uploads not attached to a post are deleted after 24 hours. An image attached to a club post is deleted from disk immediately when the post/club/account is deleted |
| **Follow relationships and bookmarked news** | Building your feed, saving content to read later | Performance of a contract | While the account is open; deleted when the account is deleted |
| **Polls:** participation record and your vote | Voting service | Performance of a contract | While the account is open; when the account is deleted the participation record is deleted and the vote record becomes unlinked from you. In a secret poll, which option you voted for is not shown to other users or administrators. No separate automatic deletion period applies to the vote records of finished polls. |
| **Timetable, course and exam information:** courses, sessions, semester and exam records you enter yourself; announcement read state | Personal timetable and exam tracking | Performance of a contract | While the account is open; deleted when the account is deleted |
| **Notification inbox and preferences:** notification contents, quiet hours, type preferences | Notification service | Performance of a contract | Read notifications are deleted after 30 days, unread after 90 days; the newest 200 notifications per user are kept |
| **Device notification token (FCM):** token, platform, app version, language, last seen | Sending push notifications | Performance of a contract; explicit consent (notification permission) | A token unseen for 60 days is cleaned up nightly; deleted on sign-out/account deletion |
| **Push notification queue:** target user/device, notification title and short text, delivery status | Delivering push notifications from a persistent queue with retries | Performance of a contract | A pending entry is retried for at most 24 hours; sent entries are deleted after 7 days, failed ones after 30 days; deleted on sign-out/account deletion |
| **Device ID and IP records:** non-reversible digest of the device identifier (HMAC), platform, app version, IP address, last seen and event type (registration/sign-in/request) | Security, abuse and preventing circumvention of a ban on a banned user | Legitimate interest (Art. 5/2-f); legal obligation (Art. 5/2-ç) | Default **90 days**; ban records for as long as the ban lasts (see 6) |
| **Usage events (analytics):** screen name, event name, limited property values, time; last seen and daily activity | Improving the service, error/performance tracking; reports are aggregated | Legitimate interest (Art. 5/2-f) | Raw events **45 days** (immediately on account deletion); afterwards only non-personal aggregated daily summaries remain. The daily activity record (on which days you opened the app) **400 days** (immediately on account deletion) |
| **Support, feedback, appeal, report:** your texts and contact e-mail | Answering requests, moderation | Performance of a contract; legitimate interest; legal obligation | On account deletion the texts are cleared and the record remains without identity; public (signed-out) support requests 365 days |
| **Inappropriate-language filter record:** in which area, whose content was rejected/flagged and when (the rejected text is not stored) | Preventing abuse in public areas | Legitimate interest (Art. 5/2-f) | 90 days |
| **Blocking and moderation records:** people you blocked, violation records, report decisions, ban traces | Security and moderation | Legitimate interest; legal obligation | The moderation trail is kept without identity even after the account is deleted |
| **Administrator access and action records** (including the message-viewing record) | Accountability, preventing unauthorised access | Legitimate interest; legal obligation | Administrator action record (including IP) 365 days; message-access record and club management action record 730 days (records are append-only and cannot be changed); deleted at the end of the period |
| **Agreement acceptances:** document type, version, time | Proof of consent/acceptance | Legal obligation; legitimate interest | Kept even after the account is deleted |
| **E-mail queue:** recipient, subject, delivery status | Verification/password reset/security e-mails and administrator announcements | Performance of a contract; legitimate interest for announcements | Sent records are deleted after 7 days, failed (undeliverable) records after 30 days |
| **Administrator announcement e-mail (campaign) records:** campaign name and status, your user ID as the recipient and the delivery status | Sending service and community announcements (not advertising/marketing; you can unsubscribe through the link in the e-mails). Profile fields such as name, department, faculty and year may be used for personalisation in announcements | Legitimate interest (Art. 5/2-f); performance of a contract | Deleted 180 days after the campaign ends; your recipient row is deleted immediately when your account is deleted |
| **Contact matching:** SHA-256 digests of the e-mails in your contacts (only during the request) | Finding people you know in your contacts | **Explicit consent** (Art. 5/1) | **Not stored, not recorded**; only in memory while the request is processed |
| **Device location** | — | — | The app **does not ask** for location permission; device location (GPS/network) is **not collected, not sent to the server and not stored** (see 5) |

> **In short:** Every item of data we process is tied to a purpose; most is kept while your account is open. Device/IP records are kept 90 days, raw analytics events 45 days, the daily activity record 400 days, notifications 30 days if read and 90 if unread, the e-mail queue 7 days (30 days if failed), and announcement campaign records 180 days.

## 3. How are your messages stored and who can see them?

1. **Transmission:** Messages are transmitted encrypted with TLS/WSS.
2. **Storage:** On the server each chat is stored encrypted with AES-256-GCM using a separate key. The keys are protected by a separate master key and are kept in the server environment, not in the database. This makes it harder to read the messages even if a database backup is captured.
3. **It is NOT end-to-end encryption.** Because the master key is with us, the system can decrypt messages. Use it knowing this.
4. **Administrator access:** Only authorised administrators (those with the full administrator and moderator roles, see 14) may view the content of messages and media, for reasons such as report review, security/abuse and legal requests. The administrator interface can also show deleted, edited and moderation-hidden messages, "view-once" photos, and messages not delivered to a blocked user. The administrator must enter a written reason to view the content (at least 10 characters). **Every viewing** is written, before the content is shown, to a tamper-resistant record automatically: who looked, whose chat they looked at, how many messages, for what reason, from which IP, and when. If the record cannot be written, the content is not shown.
5. **Deleted messages:** "Delete for everyone" hides the message from other users; the encrypted copy of the message and its old versions may be kept for security review. The retention period is set by the operator (default: indefinite).
6. **View-once photos:** The recipient sees it once, then access closes; however, for administrator review the encrypted file is kept for 365 days (adjustable) and then deleted. Although there are technical measures to prevent screenshots, no absolute guarantee is given.
7. **Notification preview:** By default the message text is not shown in push notifications (if the setting is turned on, the text passes through Google FCM/Apple APNs). Message content is never written to the in-app notification inbox.
8. **Photo and video processing:** Photos (profile, cover, post, chat) are re-encoded after their type/size is verified, and EXIF (location, etc.) is removed. **Chat videos** are compressed on your device; the server does not re-encode the video and **does not remove the metadata inside the video file (recording time, location tag, etc.)**: only the type, size and duration are verified, and the video is stored encrypted with a chat-specific key. Your device's compression may not remove this metadata; be careful before sending videos that may contain location or personal information. The cover (preview) image of a video, however, is re-encoded like a photo and its metadata is removed. Posts contain only a single photo. The digests of images are compared with the prohibited-content digest list; the content of images is not analysed automatically.
9. **Blocking:** Messages written to you by a person you blocked are not delivered to you; the blocked person is not notified. These messages remain in the system and may be seen only by authorised administrators for reasons such as report review.

> **In short:** Messages are stored encrypted but not end-to-end. Authorised administrators may view them only in reasoned cases, each time with a record. The encrypted copies of deleted messages and view-once photos may be kept for a period for security.

## 4. With whom do we share your data?

| Recipient | What is shared? | Purpose | Location |
|---|---|---|---|
| **Google Firebase Cloud Messaging (FCM)** (and Apple APNs for iOS) | Device notification token, notification title/short text, target information | Delivering push notifications | Abroad (Google/Apple infrastructure); see the KVKK Privacy Notice |
| **E-mail delivery service provider: Brevo (SMTP)** (processor) | Recipient e-mail address, e-mail content (verification code, announcement text; in announcements name and department/faculty/year information for personalisation) | Verification, password reset, security e-mails and administrator announcements | May be abroad (the provider's servers may be in Europe or other countries); see the KVKK Privacy Notice |
| **Hosting / server provider** | All service data (including encrypted messages) | Hosting the service | {{hosting.location|The hosting location is stated before publication}} |
| **Competent public authorities** (court, public prosecutor, law enforcement, the KVKK Board, etc.) | Data within the scope of the request | Legal obligation | Domestic |

We do not share data with advertising networks, data brokers or social-media tracking tools. **We do not transfer user data to Bingöl University or its units;** the Service only reads publicly available news, announcements, events and menu content from the university's sites and, at registration, only checks the domain name of the e-mail address (bingol.edu.tr). Management panel administrators do not act on behalf of the university (see 14). A note: because our e-mails are sent to your registered bingol.edu.tr address, the institution that operates that mailbox (the university) may technically process the e-mail on its own infrastructure; this is not a data transfer made by us but the nature of e-mail.

## 5. Permissions and optional features

1. **Notification permission:** You receive push notifications if you wish. If you decline, the in-app notification inbox continues to work. You manage notification types and **quiet hours** in settings.
2. **Contact matching:** If you grant contacts access, only the **SHA-256 digests** of the e-mail addresses in your contacts (at most 500 per request) are sent to the server in order to find people you know. The digests are **not stored and not recorded**; only the matching users (respecting their privacy settings) are returned to you in the response. Your contact names and phone numbers are not sent to the server. There is an hourly request limit to prevent abuse.
3. **Location:** The app **does not ask for permission** for location (GPS/network based) from your device; it does not collect, send to the server or store your location. The IP address recorded for security (see 6) is not device location; no location or region is derived from the IP address in the application code. Hosting and network infrastructure providers may keep their own technical records according to their own policies; these records are not used by us to determine location. If location is to be processed in the future this text will be updated and your explicit consent will be obtained again.
4. You can withdraw permissions at any time from the device settings or the Permissions screen in the app. Withdrawal does not affect the lawfulness of processing before the moment of withdrawal.

## 6. Device and IP records, access bans

1. For security, at registration, sign-in, session renewal and requests, a non-reversible digest of your device identifier, the platform, app version, IP address and time information are recorded. The raw device identifier is not stored.
2. These records are kept for **90 days** by default and are cleaned up nightly. The period can be adjusted by the operator; if a legal retention duty arises (e.g. traffic information under Law No. 5651), the period may be set accordingly and this policy will be updated.
3. An **access ban** may be defined for the IP address, network range, device digest or user ID of a user banned for abuse. The ban record (reason code, date, duration if any, and notes) is kept for as long as the ban lasts and for the period needed for appeal/audit. Attempts caught by a ban (IP, device digest, request path, time) are kept as a security record and are subject to the same cleanup principle as device/IP records. Requests from anonymising ranges such as VPN/Tor/data centres may be restricted for security.
4. If you think you were banned, you can apply from the Support section or the appeal feature.

## 7. Account deletion and data portability

**Download my data:** With Profile > Download my data you can download your own data (limited to 3 times a day) as JSON. The output includes your profile and privacy settings, your acceptance records, your messages and chat memberships, your posts and likes, your follows, your bookmarked news, your community memberships and posts, your event attendance, application and attendance records, the events you created, the announcement e-mail campaigns sent to you, your notifications and device records, your support requests, and your device/IP history. Deleted messages are not included in the output. If a section cannot be prepared temporarily, an error marker appears in that section and the other sections are still provided.

**Account deletion = anonymisation.** When you delete your account:

| What happens? | Which data |
|---|---|
| **Deleted** | Your notification device tokens and pending push records, your notification inbox and preferences, your follow relationships, your timetable and exam records, your poll participation record, your likes, your Discover posts (media files are removed from disk after 30 days), your bookmarked news, your feedback votes, your event feedback, your block list, your club application answers, your community memberships, your recipient rows in announcement e-mail campaigns, the chat photos you uploaded, **your device/IP records, analytics events and daily activity record (immediately)**, the images you attached to club posts (immediately, from disk). Your event applications are closed (the next person on the waiting list takes the seat) and the unfinished events you created that are not linked to a club are cancelled. **If you are a club owner:** ownership is transferred to the oldest active administrator (or, if none, moderator) of the club; if there is nobody to take over, the club is closed and its members are notified |
| **Anonymised** | Name, e-mail, profile information, biography, photo; poll vote records (the link to the user is cut); support, feedback, appeal, report and event application texts are cleared (the record remains without identity) |
| **Kept (limited)** | The messages you sent and community posts (part of other people's chat context; the author appears anonymous such as "Deleted user"); agreement acceptance records (legal evidence); moderation violation/report and ban traces; anonymous attendance/RSVP counters; administrator action and access records |
| **Cleaned up after a period** | Device/IP records (90 days), inappropriate-language filter record (90 days), raw analytics events (45 days), daily activity record (400 days), e-mail queue (sent 7 days, failed 30 days), announcement campaign records (180 days), administrator action record (365 days), message-access and club action records (730 days) |

> **In short:** When you delete your account your identity is removed and your personal data is deleted or anonymised. To protect the rights of others and legal evidence/security needs, some records remain without identity and in limited form.

## 8. Security measures

1. Passwords are stored as one-way digests; verification codes and refresh tokens are kept as digests.
2. The access token lasts 15 minutes; the refresh token is single-use; all sessions are closed when the password changes.
3. Rate limits apply to sign-in, registration, verification and write operations; generic responses that do not leak user existence are given.
4. Messages are stored encrypted; administrator access is recorded; the management panel works only with an administrator role.
5. Uploaded files are verified for type/size and file names are generated on the server.
6. No system is absolutely secure. If a data breach occurs, we notify the Board and the affected persons in accordance with the legislation.

## 9. Cookies and local storage

**No tracking/advertising cookies are used** on the website. Only necessary local storage such as your language/theme preference and session information is used. For details see the [Cookie and Local Storage Policy](/legal/cookies).

## 10. Children's data

The Service is not designed for persons under 18; registration is only with a university student/staff e-mail. If the registration of a user under 18 is detected, the knowledge and consent of the legal representative may be requested; if necessary the account is closed and the data is deleted/anonymised.

## 11. Your rights

Under KVKK Art. 11 you have the right to access, correct, delete, object to and otherwise exercise rights over your data. The application routes and the 30-day response time are in the [KVKK Privacy Notice](/legal/kvkk) and [Retention and Destruction](/legal/retention) texts. Quick routes: editing profile information, privacy settings, Download my data, Delete account, the Support section.

## 12. Changes

We may update this policy. For important changes we ask for your re-acceptance; the current version and history appear on this page.

## 13. Posts and content moderation

1. **Who sees them?** Posts are shown to other users who are signed in to the app; mutual visibility is closed with users you have blocked or who have blocked you. The visibility options offered in the app are shown on the relevant screen.
2. **Club post images.** An image you attach to a club post has its link removed and the file is deleted from disk when you delete the post, when the club is closed or when you delete your account.
3. **Inappropriate-language filter.** In public areas such as communities, events, profiles and posts, profanity, insults and similar expressions may be rejected automatically. **Chat messages (one-to-one and group) are not pre-screened.** The filter works only at the moment of saving; which area's and which user's content was rejected is kept for 90 days, and the rejected text is not stored. Rejected content is not published; the decision is made automatically without human review and you can send your objection through the Support section.
4. **Reports and removal.** Posts and messages can be reported with **Report**; authorised administrators review them and may hide or remove the content. If the same content is reported by several mutually independent accounts, it may be hidden automatically and temporarily until the review is completed; it may be made visible again after administrator review. For the procedure see the [Content Notice and Removal](/legal/content-removal) and [Community Rules](/legal/community-rules) texts.

## 14. Administrator roles and access powers

1. **Who are they?** Accounts that access the management panel are defined by the Operator and carry one of five roles: *full administrator*, *moderator*, *support*, *editor*, *read-only*. Administrators do not act on behalf of the university; an administrator role does not mean that personal data is transferred to the university.
2. **Access to personal data is limited by role.** Only the full administrator and moderator see the unmasked e-mail, IP and device details; in the support, editor and read-only roles these fields are masked (e.g. a•••@bingol.edu.tr). The support role manages support requests and feedback, the editor manages news, announcement and communication content, and the read-only role only monitors.
3. **Private correspondence.** Only the full administrator and moderator can access the content of messages and chat media; no one who is not an administrator can. This access is subject to the conditions in section 3: only for reasons such as report review, security/suspected abuse or a legal request, with a written reason and a tamper-resistant access record (730 days). Because the management panel can technically list a user's chats, preventing this power from being used for other purposes rests solely on these rules and the record; viewing for any other purpose is prohibited.
4. **Intervention powers.** Authorised administrators may hide (reversibly) or permanently delete a message, close a chat, remove a member from a chat, hide or remove posts and other content, close a club, suspend an account or define an access ban. Write operations are written to the administrator action record (365 days); for critical operations (message/chat intervention, role changes, account and club operations) a written reason is mandatory.
5. **Management of roles.** The assignment and changing of administrator roles is also written to the audit log.

## 15. Contact

{{support.email|In-app Support section}}{{?controller.email}} · {{controller.email}}{{/controller.email}}{{?controller.kep}} · KEP: {{controller.kep}}{{/controller.kep}}
