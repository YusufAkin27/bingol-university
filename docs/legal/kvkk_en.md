# KVKK Privacy Notice

*This English text is a translation provided for information only. The Turkish text is authoritative; if there is any difference, the Turkish text prevails.*

In accordance with Article 10 of the Personal Data Protection Law No. 6698 (the "**Law**" / "**KVKK**") and the Communiqué on the Procedures and Principles to be Followed in Fulfilling the Obligation to Inform, we inform you how your personal data is processed while you use the BÜ Kampüs application and website. This text is for information; operations that require explicit consent are requested from you separately and individually through the [Explicit Consent text](/legal/explicit-consent).

## 1. Data controller

| | |
|---|---|
| Data controller | {{controller.name}} |
{{?controller.address}}| Address | {{controller.address}} |{{/controller.address}}
{{?controller.email}}| E-mail | {{controller.email}} |{{/controller.email}}
{{?controller.kep}}| KEP address | {{controller.kep}} |{{/controller.kep}}
{{?controller.verbis}}| VERBİS registry no. | {{controller.verbis}} |{{/controller.verbis}}
| In-app application | Support section{{?support.email}} · {{support.email}}{{/support.email}} |

## 2. Categories of personal data processed

| Category | Examples |
|---|---|
| Identity | Name and surname; if you choose to sign in with Google or Apple (optional), the name of the provider and the identifier the provider assigns to your account |
| Contact | E-mail address (from any provider; with Google/Apple sign-in, the address reported by the provider, which may be a private relay address with Apple), contact e-mail in support requests |
| Education/professional information | Faculty, department, year, student/staff role; for those who apply as an academician, the title and unit; for students, the student number if the university e-mail address is in number form (derived from the e-mail address) |
| Visual | Profile photo; post photo (a single photo per post); chat photos and videos (the EXIF metadata of photos is removed; chat videos are not re-encoded on the server and the metadata inside them is not removed, they are stored encrypted) |
| User content | Messages, community posts and Discover posts (a single photo and text of at most 7 words), poll votes, event application answers, feedback, support and appeal texts, biography |
| Customer transaction / usage | Community memberships, event attendance and roll call, bookmarks, follow relationships, notification and privacy preferences, block list, the record of the administrator announcement e-mail campaigns you received (campaign and delivery status) |
| Personal plan | The timetable, courses, semester and exam records entered by the user themselves |
| Transaction security | Session information, password digest, non-reversible digest of the device identifier, IP address, platform and app version, access ban records, errors and sign-in attempts |
| Legal transaction / compliance | Agreement acceptance records, complaint/report and moderation records, administrator access records |
| Academician application | Title, first name, last name, unit, application status, approval mode (automatic/administrator), the administrator who decided and the time, rejection or revocation reason |
| Course enrolment and attendance | The academician of the course, course enrolment and the time it was added; attendance status per session (present/absent/removed), how it was recorded (QR/manual), when and by whom; a non-enrolled student's pending scan request; absence counts and the automatic absence-warning status; course notices (seven fixed types) and file attachments |
| Marketing | Not processed (no processing for advertising/marketing purposes). Announcement e-mails sent by administrators are service and community announcements; every e-mail contains an unsubscribe link |
| Special categories of personal data | Not requested knowingly. Special-category data shared within user content (e.g. in a message) is hosted only within the scope of your own sharing; we do not aim to process it. |

## 3. Purposes of processing

1. Creating membership, identity and e-mail verification, account security.
2. Providing news, announcements, events, menu, community, event, attendance, messaging, search and bookmark services.
3. Sending notifications (in-app, push, e-mail).
4. Handling support, feedback and appeal requests.
5. Security, preventing abuse and the circumvention of a ban on a banned user, moderation.
6. Improving the service, error and performance tracking (aggregated analysis).
7. Fulfilling legal obligations, meeting requests of competent authorities, exercising and defending rights.
8. Keeping agreement and consent records.
9. Providing post, follow, bookmark, poll and personal timetable services; sending administrator announcement e-mails.
10. Automatic filtering of inappropriate language in public areas and handling complaints.
11. Assessing academician applications; providing the student directory to approved academicians and adding a student to a course; course enrolment, attendance, absence tracking and automatic absence warnings; delivering course notices (with file attachments); providing this data to the academician as CSV and read-only monitoring in the administration panel (see section 12).

## 4. Legal bases

| Legal basis | Example processing activities |
|---|---|
| Art. 5/2-(a) Expressly provided for by law | Providing information to competent authorities, records required by legislation |
| Art. 5/2-(c) Establishment or performance of a contract | Membership, profile, messaging, community/event services, sending notifications and e-mails, academician application, recording your attendance when you scan the QR code yourself |
| Art. 5/2-(ç) Fulfilment of a legal obligation | Agreement acceptance records, legal requests, retention required by relevant legislation |
| Art. 5/2-(e) Establishment, exercise or protection of a right | Moderation traces, records that serve as evidence for appeals and disputes |
| Art. 5/2-(f) Legitimate interest (provided that fundamental rights and freedoms are not harmed) | Security, device/IP records, rate limiting, administrator access audit, analytics, the student directory, course enrolment, attendance records and absence warnings, course notices (see section 12) |
| Art. 5/1 Explicit consent | **Optional** operations such as contact matching, push notification permission and publishing optional profile fields |

(Sub-paragraphs Art. 5/2-(ç) and Art. 5/2-(e) can together be the basis for the relevant operations.)

## 5. Transfer of personal data

| Recipient group | Data transferred | Purpose | Domestic / abroad |
|---|---|---|---|
| Hosting and infrastructure service providers (processors) | Service data (messages encrypted) | Hosting the service | {{hosting.location|The hosting location is notified separately by the data controller}} |
| E-mail delivery service provider: Brevo (SMTP; processor) | Recipient e-mail, e-mail content; in announcement e-mails personalisation fields such as name and department/faculty/year | Verification/password reset/security e-mails and administrator announcements | **May be abroad** (the provider's servers may be in Europe or other countries) |
| Notification provider: Google LLC (Firebase Cloud Messaging) and Apple Inc. (APNs) for iOS | Device notification token, notification title/short text, target information, platform | Delivering push notifications | **Abroad** |
| Approved academicians (other users of the app; for administration panel administrators see section 8) | Student directory fields; to the academician of their own course, enrolment, attendance, absence and notification information | Conducting the course, attendance and notices | Shown within the app; not transferred to another country |
| Competent public bodies and institutions (court, public prosecutor, law enforcement, the Board, etc.) | Data within the scope of the request | Legal obligation | Domestic |

**There is no transfer to the university.** Your personal data is not transferred to Bingöl University or its units: the Service only reads publicly available news, announcements, events and menu content from the university's sites. Management panel administrators do not act on behalf of the university (see section 8). Note: because the e-mails we send reach your registered e-mail address, the organisation that operates that mailbox (your e-mail provider; the university if you use a bingol.edu.tr address) may technically process the e-mail on its own infrastructure; this is not a transfer made by the data controller but the nature of e-mail. If you sign in with Google or Apple, authentication takes place between your device and that provider; our server only verifies the provider's signed identity token and sends no data to the provider on your behalf. The providers' own processing is subject to their own notices and privacy policies.

**Transfer abroad (Art. 9).** For push notifications, your device notification token and the notification content are transferred abroad through Firebase/APNs. Within the framework of Article 9 of the Law and the relevant Board regulations, this transfer relies on **your explicit consent based on the notification permission** and/or adequacy/appropriate-safeguard mechanisms (standard contract, etc.). If you do not grant the notification permission you will not receive push notifications, but the in-app notification inbox and other services continue to work. You can withdraw your consent at any time from the device settings or the Permissions/Notification settings in the app. The servers of the e-mail delivery service provider (Brevo) may also be abroad; your e-mail address and the e-mail content may be transferred to this provider to deliver verification, password reset and announcement e-mails, and this transfer also relies on the mechanisms under Article 9 above.

## 6. Method of collecting personal data

Your data is collected by automated and partly automated methods electronically through the application and website: registration/profile forms, messaging and content sharing, support forms, the technical communication of your device (IP, device digest, app version), cookie-like local storage and (if you allow it) the contact matching request. News and menu content is compiled from publicly available sources that contain no personal data.

## 7. Retention period

Personal data is kept for the time required for the purpose of processing and for the period provided in the relevant legislation, and at the end of the period it is deleted, destroyed or anonymised. Main periods: pending registration 1 hour; verification code 10 minutes; refresh token at most 30 days; read notifications 30 days, unread 90 days (newest 200 per user); device notification token if unseen for 60 days; device/IP security records 90 days; inappropriate-language filter record 90 days; push queue record 7 days after sending (30 days if failed); raw analytics events 45 days (afterwards only non-personal aggregated summaries); daily activity record 400 days; e-mail queue sent records 7 days, failed records 30 days; administrator announcement e-mail (campaign) records 180 days after the campaign ends; administrator action record 365 days; message-access and club action records 730 days; encrypted copy of a view-once photo 365 days; public support request 365 days. While the account is open your profile and contents are kept; the encrypted copy of deleted messages and agreement acceptance records may also be kept separately for security/evidence purposes. Detailed table: [Retention and Destruction](/legal/retention). No automatic retention period applies to records of the academician area (application, course enrolment, attendance, pending scan request, course notices and their attachments); they are kept until the course is deleted or the academician's or the student's account is deleted (see section 12 and [Retention and Destruction](/legal/retention)). Uploaded files not attached to a notice are cleaned up after 24 hours.

## 8. Administrator access and powers (transparency note)

Messages are stored encrypted on the server, but the system is not end-to-end encrypted. Management panel accounts are defined by the Operator and carry one of five roles (full administrator, moderator, support, editor, read-only); administrators do not act on behalf of the university. Only the full administrator and moderator have access to personal fields (unmasked e-mail, IP, device details); in the other roles these fields are masked. **Only the full administrator and moderator can access the content of messages and media,** only for reasons such as report review, security, abuse and legal requests, by entering a written reason (at least 10 characters); every viewing is recorded automatically and in a tamper-resistant way (administrator, user viewed, chat, number of messages, reason, IP, time; 730 days) and if the record cannot be written the content is not shown. Administrators may also hide or delete a message, close a chat, remove content, close a club and suspend an account; these operations are written to the administrator action record (365 days). The legal basis of this processing activity is legitimate interest and legal obligation (Art. 5/2-(f), (ç), (e)); details are in sections 3 and 14 of the [Privacy Policy](/legal/privacy).

## 9. Automated decision-making

The Service does not make a decision that produces a legal consequence about you solely by automated processing. If several violation records accumulate for the same account, the system only produces a **recommendation** to an administrator; an administrator makes the suspension decision. There are automated measures such as rate limiting, the prohibited-content digest check, the inappropriate-language filter in public areas, and the automatic and temporary hiding of content, until the review is completed, when the same content is reported by several mutually independent accounts (an administrator can reopen it); the filter may reject a content automatically (chat messages are not subject to this check) and you can send your objection through the Support section. Decisions that produce a lasting consequence for your account are made by an administrator. If an academician application meets certain conditions (e-mail verified by code, an address on the bingol.edu.tr domain that is not in student-number form, no year information on the account), the system may approve it automatically; this decision has no adverse consequence for the applicant, and rejection and revocation decisions are made by an administrator. Automatic absence warnings are only notifications; they do not make any decision about the consequence of an absence.

## 10. Your rights (Art. 11)

By applying to the data controller you may request the following:

1. To learn whether your personal data is processed,
2. To request information if it has been processed,
3. To learn the purpose of processing and whether it is used in line with its purpose,
4. To know the third parties to whom it is transferred at home or abroad,
5. To request correction if it is incomplete or incorrectly processed,
6. To request deletion or destruction within the framework of the conditions in Article 7 of the Law,
7. To request that the operations under (5) and (6) be notified to the third parties to whom the data was transferred,
8. To object to the occurrence of a result against you through the analysis of the processed data exclusively by automated systems,
9. To request compensation for the damage if you suffer damage due to unlawful processing.

In-app shortcuts: Profile editing and privacy settings (correction/control of publication), **Download my data** (access/copy), **Delete account** (deletion/anonymisation).

## 11. How to apply

1. **In-app:** Create a request titled "Personal data request" in the Support section (the identity of a signed-in user is verified through the account).
2. **Written:** By a wet-signed petition{{?controller.address}} to {{controller.address}}{{/controller.address}}, by hand or through a notary.
{{?controller.kep}}3. **KEP:** An application with a secure electronic signature to {{controller.kep}}.{{/controller.kep}}
{{?controller.email}}4. **E-mail:** To {{controller.email}}, from your registered e-mail address.{{/controller.email}}

Your application must state your name and surname, information that verifies your identity (account e-mail), your notification address and the subject of your request. We may ask for additional information to verify your identity. Applications are concluded free of charge, depending on the nature of the request, **within 30 days at the latest**; if the process requires an additional cost, the fee in the tariff determined by the Board may be charged.

If the application is rejected, the reply is found insufficient or no reply is given in time, you retain the right to **complain to the Personal Data Protection Board** within 30 days of learning the reply and in any case within 60 days of the application date.

## 12. Academician area, course enrolment and attendance

This section completes the disclosure for the area for teaching staff ("academicians").

1. **Data subjects:** (a) students registered in the app (listed in the student directory, added to a course, whose attendance is taken); (b) those who apply as an academician.
2. **Data shown in the directory.** Every approved academician, for as long as they are approved, can search and filter all students who are registered in the app and have completed their profile, and sees the fields **name, student number, faculty, department, year**; e-mail, photo, biography and other profile information are not shown. The directory is independent of profile privacy settings; in this version there is no separate setting to opt out of the directory, and objections can be sent to the Support section. Academician and administrator accounts do not appear in the directory.
3. **Purposes and legal bases:**

| Purpose | Legal basis |
|---|---|
| Assessing and approving an academician application | Art. 5/2-(c) performance of a contract (the academician area service); Art. 5/2-(f) legitimate interest (preventing unauthorised access to student data) |
| Showing the student directory to approved academicians and adding a student to a course | Art. 5/2-(f) legitimate interest |
| Course enrolment, attendance and absence tracking; the academician's manual actions | Art. 5/2-(f) legitimate interest; Art. 5/2-(c) when the student scans the QR code themselves |
| Automatic absence warning and delivery of course notices (with attachments) | Art. 5/2-(f) legitimate interest; Art. 5/2-(c) for delivering the notification |
| Read-only monitoring and oversight in the administration panel | Art. 5/2-(f) legitimate interest; Art. 5/2-(ç) |

4. **Who can see it (recipients).** A student's course enrolment, attendance and notices are visible to the academician of the course; the academician can download attendance as CSV. Administration panel administrators (section 8) can view academician applications, courses, attendance, notices and attachments read-only; fields such as e-mail are unmasked only for roles with the relevant permission. Other students cannot see them. There is no transfer abroad for this activity beyond section 5 for push notifications.
5. **Collection method.** The data arises from your and the academician's in-app actions (application, adding to a course, QR scan, manual entry, notice); the directory fields are shown from the existing profile fields of your account (no separate copy is kept).
6. **Not processed.** Location, GPS, device identifier, grades and assignment submissions are not processed for attendance.
7. **Your rights.** Sections 10 and 11 apply. The "Download my data" output includes your course enrolments, attendance records and pending scan requests (if you are an academician, your application and a summary of your courses). On account deletion your course and attendance records are deleted; if you are an academician, your application and courses (including the students' attendance records, notices and attachments in those courses) are deleted. To object to appearing in the directory or to a course enrolment, you can apply to the Support section under the subject "Personal data request".
