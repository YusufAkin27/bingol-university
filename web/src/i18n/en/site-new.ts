// Public site: new features (event applications, club permissions, image sharing, privacy, encryption) and admin access notice (T17).
const m = {
  'site.feat.admission.title': 'Event applications and acceptance',
  'site.feat.admission.text':
    'Event organisers can require applications; each one is answered with accept, reject or waitlist. When a spot opens, the next person on the waitlist is notified.',
  'site.feat.clubroles.title': 'Club permissions',
  'site.feat.clubroles.text':
    'Club owners give their team detailed permissions; ownership transfer and invite codes keep club management orderly. Important actions are recorded.',
  'site.feat.media.title': 'Image sharing in chats',
  'site.feat.media.text':
    'Send images in chats. You can report inappropriate images or block a user; blocked images are rejected automatically on upload.',
  'site.feat.privacysettings.title': 'Privacy settings',
  'site.feat.privacysettings.text':
    'You choose who can see what on your profile. You can change the visibility of your email address and other details at any time.',
  'site.feat.secure.title': 'Encrypted transfer and storage',
  'site.feat.secure.text':
    'Your messages are encrypted in transit and stored encrypted on the server. The server manages the keys; authorised administrators can view messages when needed and every access is written to an immutable audit log.',
  'site.home.privacy4': 'Messages are sent and stored encrypted; administrator access is written to the audit log. Deleted messages may be retained for security and legal obligations.',

  'site.faq.new.title': 'About the new features',
  'site.faq.new.apply.q': 'How do I apply to an event?',
  'site.faq.new.apply.a':
    'On the page of an event that needs applications, tap “Apply”. The organiser accepts, rejects or waitlists your application and you get a notification. If the event is full, you can see your place on the waitlist.',
  'site.faq.new.clubRoles.q': 'How do club permissions work?',
  'site.faq.new.clubRoles.a':
    'The club owner can grant permissions to members one by one (for example approving members or posting announcements). Ownership can be transferred with the other person’s consent. Permission changes and member decisions are kept in the club audit log.',
  'site.faq.new.images.q': 'Can I send images in chats?',
  'site.faq.new.images.a':
    'Yes. Type and size are checked on upload. You can report an inappropriate image and block the sender. Reported content is reviewed by moderators.',
  'site.faq.new.privacy.q': 'Can I choose who sees my information?',
  'site.faq.new.privacy.a':
    'Yes. In your profile and privacy settings you can change the visibility of details such as your email address. Changes take effect immediately.',
  'site.faq.new.encryption.q': 'How are my messages protected?',
  'site.faq.new.encryption.a':
    'Messages are encrypted in transit and stored encrypted on the server. Keys are managed separately from message content.',
  'site.faq.new.adminAccess.q': 'Can administrators read my messages?',
  'site.faq.new.adminAccess.a':
    'Yes, authorised administrators can view messages for security, report review and legal obligations. Every page of that access is written to an immutable audit log. Because the server manages the keys, messages are not protected in a way that only the two parties could read them. Messages you delete become invisible to you but may be retained for security and legal obligations.',

  'site.faq.gen.title': 'Common questions about the app',

  'site.faq.gen.independent.q': 'Is BÜ Kampüs the official Bingöl University app?',
  'site.faq.gen.independent.a':
    'No. BÜ Kampüs is an independent app built for Bingöl University students and staff; it is not the university’s official app. See the [About](/about) page for its purpose and how it works.',
  'site.faq.gen.who.q': 'Who can sign up?',
  'site.faq.gen.who.a':
    'Only people with a bingol.edu.tr university email address can sign up. During sign-up you accept the agreements and enter the verification code sent to your address. The steps are described on the [download page](/download).',
  'site.faq.gen.noCode.q': 'The verification code does not arrive. What should I do?',
  'site.faq.gen.noCode.a':
    'First check your spam folder and make sure you typed the bingol.edu.tr address correctly. The code is valid for 10 minutes; if it has expired, request a new one in the app. If the problem continues, write to us via the [contact page](/contact).',
  'site.faq.gen.free.q': 'Is BÜ Kampüs free?',
  'site.faq.gen.free.a':
    'Yes, BÜ Kampüs is free. The only requirement to sign up is a bingol.edu.tr email address.',
  'site.faq.gen.platforms.q': 'Which phones does it run on and where can I download it?',
  'site.faq.gen.platforms.a':
    'The app is being prepared for Android and iPhone. Store buttons become active on the [download page](/download) once the store links are published; until then they read “Coming soon”.',
  'site.faq.gen.menuSource.q': 'Where does the menu come from and when is it updated?',
  'site.faq.gen.menuSource.a':
    'The menu is taken from the monthly list published by the university cafeteria (SKS) and is updated once a month. The app is independent; if there is a difference, the official list prevails. See the [menu page](/menu) for the current menu.',
  'site.faq.gen.calorie.q': 'How are meal calories calculated?',
  'site.faq.gen.calorie.a':
    'An administrator enters calories for each dish; they do not come from the university’s list and are approximate. The entered calories are saved under the dish name, so the same dish is filled in automatically on later days. No value is shown for a dish without calories, so the daily total may be incomplete.',
  'site.faq.gen.newsSource.q': 'Where do news and announcements come from, and can they be delayed?',
  'site.faq.gen.newsSource.a':
    'News, announcements and events published on the Bingöl University website are imported into the app once every night, so a new item may take until the next day to appear. Every item links to its official source page. Everything is listed on the [news page](/news).',
  'site.faq.gen.academic.q': 'Does the app include the class schedule and exam calendar?',
  'site.faq.gen.academic.a':
    'Yes, the class schedule, exam calendar, academic calendar and department announcements are in the app, with reminders. If anything conflicts, the university’s official announcement prevails. See the [features page](/features) for everything the app does.',
  'site.faq.gen.qr.q': 'How does QR attendance work at events?',
  'site.faq.gen.qr.a':
    'Attendance at events is taken by QR code or manually by the person organising the event. You see club events in the calendar and sign up in the app.',
  'site.faq.gen.polls.q': 'Is my vote in a poll secret?',
  'site.faq.gen.polls.a':
    'Yes. Votes are secret: nobody can see who voted for what. You join club and campus polls in the app.',
  'site.faq.gen.dataSold.q': 'Is my data sold?',
  'site.faq.gen.dataSold.a':
    'No. Your data is not sold; only the data needed for the service is processed and usage statistics are aggregated. Details are in the [privacy policy](/privacy).',
  'site.faq.gen.export.q': 'Can I download my personal data?',
  'site.faq.gen.export.a':
    'Yes. In the app, go to Profile > Download my data to get your account data as a file. For other data protection requests, see the [data request page](/data-request).',
  'site.faq.gen.delete.q': 'How do I delete my account?',
  'site.faq.gen.delete.a':
    'You can delete your account yourself from the account settings in the app. Deletion anonymises your personal data and cannot be undone. See the [account deletion page](/delete-account) for the steps and the data removed.',
  'site.faq.gen.support.q': 'Where do I write if I have a problem or a suggestion?',
  'site.faq.gen.support.a':
    'You can open a request from the Support section in the app and follow its status there. If you do not have an account, use the form on the [contact page](/contact).',

  'site.links.features.label': 'Related pages',
  'site.links.features.text':
    'Before trying the features you can look at today’s menu, and download the app when you are ready.',
  'site.links.features.menu': 'Today’s menu with calorie information',
  'site.links.features.download': 'BÜ Kampüs download page',
  'site.links.news.label': 'Related pages',
  'site.links.news.text':
    'Besides the news, you can check today’s menu and follow announcements in the app.',
  'site.links.news.menu': 'Bingöl University cafeteria menu',
  'site.links.news.download': 'Download page to follow announcements in the app',
  'site.links.about.label': 'Related pages',
  'site.links.about.text':
    'Write to us with questions or suggestions, or browse the answers to the most common questions.',
  'site.links.about.contact': 'Get in touch on the contact page',
  'site.links.about.faq': 'Browse the frequently asked questions',

  'pg.menu.about.title': 'Where do the calories and data come from?',
  'pg.menu.about.text':
    'The menu is taken from the monthly list published by the university cafeteria (SKS); BÜ Kampüs is an independent app and, if there is a difference, the official list prevails. An administrator enters calories for each dish and they are approximate; because they are saved under the dish name, the same dish is filled in automatically on later days. No value is shown for a dish without calories.',
  'pg.menu.about.faq': 'How are calories calculated? Read the answer in the FAQ',
  'pg.menu.about.news': 'Bingöl University news and announcements',

  'legal.adminAccess.title': 'Administrator access and retention of deleted messages',
  'legal.adminAccess.body1':
    'Messages are encrypted in transit and stored encrypted on the server. The server manages the keys, so messages are not protected in a way that only your device can decrypt.',
  'legal.adminAccess.body2':
    'Authorised administrators may view users\' conversations for security, report review or legal obligations; administrator access is recorded and every access is written to an immutable audit log. Messages you delete or edit become invisible to you but, together with earlier versions, may be retained for security and legal obligations for a limited time or indefinitely.',
} as const;
export default m;
