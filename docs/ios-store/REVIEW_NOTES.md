# App Review Information: inceleme notu şablonu (İngilizce, Connect'e yapıştırılır)

Alanlar: **Sign-in required = Yes**; kullanıcı adı/parola = demo hesap (`scripts/ops/create-review-account.sh`; parola repoda YOK, yalnız Connect'e girilir); iletişim adı/telefon/e-posta (App Review Information). Aşağıdaki köşeli parantezli yerleri doldurun. `[24 SAAT]` taahhüdü yalnız gerçekten üstlenebiliyorsanız bırakın ([../IOS_RELEASE.md](../IOS_RELEASE.md) K4).

```
Thank you for reviewing BU Kampus.

ABOUT THE APP
BU Kampus is an independent, unofficial campus companion for students and staff of Bingol University (Turkey): university news and announcements, dining menu, student clubs, events with QR check-in, polls, class/exam reminders and chat. It is NOT published by or affiliated with Bingol University; the first paragraph of the App Store description says so. [Optional: a support letter from the university is attached / available on request.]

SIGN-IN (Guideline 2.1)
Account creation is limited to university e-mail addresses (@bingol.edu.tr) and needs an e-mail verification code that goes to a university mailbox, so a reviewer cannot sign up. Please use this ready, verified demo account:
  E-mail:   [DEMO_EMAIL]
  Password: [DEMO_PASSWORD]
Steps: open the app → "Log in" → enter the e-mail and password → you land on Home. No verification code is needed to log in. Please do not use "Sign up". Logging in on a second device signs the first one out (single-session rule), so please keep one device. The account is new, so clubs, posts and chats may look empty.

USER-GENERATED CONTENT (Guideline 1.2)
- Reporting: every post, chat message, user profile, club and event has a "Report" action (flag icon / "..." menu → Report) that sends the report to our moderation queue.
- Blocking: "..." menu on a post or profile → "Block user"; blocked users are listed under Profile → Privacy and blocked users → Blocked and can be unblocked there.
- Filtering: public text (posts, profiles, club/event text) goes through an objectionable-language filter on the server; image hashes can be blocklisted.
- Moderation: reports are reviewed in an admin panel; content reported by several independent accounts is hidden automatically until reviewed; users get warnings, strikes, suspension or access bans. We act on reports within [24 hours].
- Contact: Support section inside the app and https://bukampus.com.tr/en/contact.
- Terms/Community Rules are accepted at sign-up.

ACCOUNT DELETION (Guideline 5.1.1(v))
In the app: Profile → My data and account → Delete account. Web: https://bukampus.com.tr/en/delete-account. Deletion anonymizes the account immediately.

SIGN IN WITH APPLE (Guideline 4.8)
The app uses only its own e-mail + password sign-in with a university e-mail; there is no third-party or social login, so Sign in with Apple is not required.

PERMISSIONS (all optional, requested at the moment of use)
Camera: scan QR codes for event check-in, take photos/videos. Microphone: sound of videos recorded in chat. Photos: pick/save images. Contacts: find colleagues; only SHA-256 hashes of e-mail addresses are matched, nothing else leaves the device, and hashes are not stored. Notifications: messages, event reminders, announcements. No location, no tracking, no advertising, no App Tracking Transparency prompt.

DATA SOURCES
News, announcements and the dining menu are public content fetched by our server from the university's public web pages; the app itself never contacts those sites.

ENCRYPTION (export compliance)
Standard TLS only; ITSAppUsesNonExemptEncryption = NO.

TESTING NOTES
Push notifications require a real device. Event QR check-in needs an event QR code; the demo account can open any event detail page. Let us know if you need a second demo account or a screen recording: [SUPPORT_EMAIL].
```

## Ekler / hazırlık listesi

- [ ] Demo hesap canlıda hazır: `bash scripts/ops/create-review-account.sh --status` (inceleme bitince `--delete`, risk notu: [../store/PLAY_REVIEW_ACCOUNT.md](../store/PLAY_REVIEW_ACCOUNT.md))
- [ ] Menü yolları koddan alındı (Profil > "Gizlilik ve engellenenler" > "Engellenenler"; Profil > "Verilerim ve hesap" > "Hesabı sil"); ekranda gözle doğrulayıp metni gerçek menü adlarıyla eşleştirin
- [ ] `[24 SAAT]` taahhüdü verilebiliyor mu
- [ ] Üniversite destek mektubu var mı (yoksa ilk cümledeki köşeli satırı silin)
- [ ] Ekran kaydı (isteğe bağlı): giriş → rapor → engelleme → hesap silme akışı
