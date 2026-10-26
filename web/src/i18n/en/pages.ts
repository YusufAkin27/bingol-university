// Public site: standard pages (cookies, account deletion, accessibility, security, community guidelines, help, status,
// news, menu, brand kit, changelog, sitemap), header/footer and error screens.
const m = {
  // --- shared ---
  'pg.crumbs': 'Breadcrumb',
  'pg.crumb.home': 'Home',
  'pg.related': 'Related pages',
  'pg.updated': 'Last updated: {date}',

  // --- header / footer ---
  'pg.nav.news': 'News',
  'pg.nav.menu': 'Menu',
  'pg.nav.help': 'Help',
  'pg.foot.org': 'Organisation',
  'pg.foot.product': 'Product',
  'pg.foot.support': 'Support',
  'pg.foot.legal': 'Legal',
  'pg.foot.get': 'Get the app',
  'pg.foot.contactTitle': 'Contact',
  'pg.foot.theme': 'Theme and language',

  // --- cookie banner ---
  'pg.cookie.label': 'Cookie notice',
  'pg.cookie.text':
    'This site only uses the browser storage it needs to work (language and theme preference). It does not use tracking, analytics or advertising cookies.',
  'pg.cookie.more': 'Cookie Policy',
  'pg.cookie.ok': 'Got it',

  // --- error / maintenance screens ---
  'pg.err.title': 'Something went wrong',
  'pg.err.text': 'An unexpected error occurred. You can try again or go back to the home page.',
  'pg.err.network.title': 'Connection problem',
  'pg.err.network.text':
    'The page could not be loaded. Check your internet connection and try again; if the problem continues, come back in a while.',
  'pg.err.maint.title': 'Maintenance in progress',
  'pg.err.maint.text': 'The service is briefly under maintenance. Please try again shortly.',
  'pg.err.home': 'Back to home',
  'pg.err.statusLink': 'See current status',

  // --- Cookie Policy ---
  'pg.cookies.title': 'Cookie Policy',
  'pg.cookies.lead':
    'This site stores only what it needs to work. We do not use advertising, tracking or analytics cookies.',
  'pg.cookies.meta': 'How the BÜ Kampüs website uses cookies and browser storage: essential records only.',
  'pg.cookies.s1.h': 'What are cookies?',
  'pg.cookies.s1.p1':
    'Cookies and similar browser storage (local storage, session storage) are small records kept in your browser when you visit a site.',
  'pg.cookies.s2.h': 'What do we store?',
  'pg.cookies.s2.p1':
    'Our website does not write HTTP cookies to your browser. It only keeps the following essential records in your browser’s local and session storage:',
  'pg.cookies.s2.l1': 'bu.lang: remembers the interface language you chose.',
  'pg.cookies.s2.l2': 'bu.theme: remembers your light or dark appearance choice.',
  'pg.cookies.s2.l3': 'bu.cookies: remembers that you have seen this notice.',
  'pg.cookies.s2.l4':
    'Admin panel session (administrator sign-in only, session storage): deleted when you close the tab.',
  'pg.cookies.s3.h': 'Analytics, advertising and tracking',
  'pg.cookies.s3.p1':
    'The website has no analytics, advertising or third-party tracking tools, so no cookie requires your consent. If that ever changes, this page will be updated and we will ask for your explicit consent first.',
  'pg.cookies.s4.h': 'Managing your preferences',
  'pg.cookies.s4.p1':
    'You can delete the stored records in your browser settings; your language and theme choices will then be reset. You can show the notice banner again below.',
  'pg.cookies.s5.h': 'Mobile app',
  'pg.cookies.s5.p1':
    'Details about how the mobile app processes data are in the Privacy Policy and the KVKK Notice.',
  'pg.cookies.status.ack': 'You have acknowledged the notice.',
  'pg.cookies.status.none': 'You have not acknowledged the notice yet.',
  'pg.cookies.reset': 'Show the notice banner again',

  // --- Account deletion ---
  'pg.delete.title': 'Delete your account',
  'pg.delete.lead':
    'You can delete your BÜ Kampüs account yourself from the app. This page explains the steps and what is removed.',
  'pg.delete.meta': 'How to delete your BÜ Kampüs account from inside the app and which data is removed.',
  'pg.delete.s1.h': 'Delete from inside the app',
  'pg.delete.s1.p1': 'The quickest way to delete your account is the app:',
  'pg.delete.s1.o1': 'Open the BÜ Kampüs app and sign in.',
  'pg.delete.s1.o2': 'Go to your profile and settings.',
  'pg.delete.s1.o3': 'Tap “Delete my account”.',
  'pg.delete.s1.o4': 'Confirm by entering your password.',
  'pg.delete.s2.h': 'What happens when you delete',
  'pg.delete.s2.l1':
    'Your name, email address, faculty, department, class year, biography and profile picture are removed; the account is anonymised as “Deleted user”.',
  'pg.delete.s2.l2': 'Your usage and activity records are deleted.',
  'pg.delete.s2.l3': 'Your event RSVPs are deleted, so you no longer take up places in event capacity.',
  'pg.delete.s2.l4': 'Your current sessions become invalid immediately.',
  'pg.delete.s3.h': 'This cannot be undone',
  'pg.delete.s3.p1':
    'Deleting an account is irreversible. If you wish, export your data first using the “download my data” option in the app.',
  'pg.delete.s4.h': 'If you cannot access the app',
  'pg.delete.s4.p1':
    'If you forgot your password or cannot install the app, reach us through the data request page or the contact page; we will reply within the legal time limits.',
  'pg.delete.s5.h': 'About your data',
  'pg.delete.s5.p1':
    'Which data we process and why is described in the Privacy Policy and the KVKK Notice.',

  // --- Accessibility ---
  'pg.accessibility.title': 'Accessibility statement',
  'pg.accessibility.lead': 'We work to make the BÜ Kampüs website usable by everyone.',
  'pg.accessibility.meta': 'The BÜ Kampüs website’s accessibility goal, what we have done and known limitations.',
  'pg.accessibility.s1.h': 'Our goal',
  'pg.accessibility.s1.p1':
    'We aim for WCAG 2.1 AA conformance. An independent accessibility audit has not been carried out yet; the status is based on our own assessment.',
  'pg.accessibility.s2.h': 'What we have done',
  'pg.accessibility.s2.l1': 'A “Skip to content” link and a meaningful heading structure on every page.',
  'pg.accessibility.s2.l2': 'Full keyboard use with a visible focus indicator.',
  'pg.accessibility.s2.l3':
    'Text and background colours meet at least a 4.5:1 contrast ratio; light and dark themes are available.',
  'pg.accessibility.s2.l4': 'Turkish, English and Arabic interfaces, with right-to-left layout for Arabic.',
  'pg.accessibility.s2.l5': 'Labelled buttons, status announcements and focus moved to the heading on page changes for screen readers.',
  'pg.accessibility.s2.l6': 'Animations are turned off when “reduce motion” is selected in your system.',
  'pg.accessibility.s3.h': 'Known limitations',
  'pg.accessibility.s3.l1':
    'News and announcements come from the Bingöl University website; images there may lack alternative text.',
  'pg.accessibility.s3.l2': 'We do not control the accessibility of external sites we link to.',
  'pg.accessibility.s4.h': 'Feedback',
  'pg.accessibility.s4.p1':
    'If you run into an accessibility problem, tell us; describing the issue and the device or assistive technology you use helps us fix it faster.',
  'pg.accessibility.s5.h': 'Assessment',
  'pg.accessibility.s5.p1': 'This statement was prepared for the October 2026 version of the site and is updated as the site evolves.',

  // --- Security ---
  'pg.security.title': 'Security',
  'pg.security.lead': 'How we protect your data and how you can report a security vulnerability to us.',
  'pg.security.meta': 'BÜ Kampüs security approach and responsible vulnerability disclosure guidelines.',
  'pg.security.s1.h': 'How we protect your data',
  'pg.security.s1.l1': 'In production, communication between the app and the server uses an encrypted connection (HTTPS).',
  'pg.security.s1.l2':
    'Messages are stored encrypted on the server. The server manages the keys, so messages are not protected in a way that only your device can decrypt; authorised processes can decrypt them.',
  'pg.security.s1.l3':
    'Administrator access is justified and audited: looking at a conversation requires a written reason, and every access is written to a tamper-evident audit log.',
  'pg.security.s1.l4':
    'Passwords are stored irreversibly (as hashes); session refresh tokens are also kept only as hashes.',
  'pg.security.s1.l5': 'Sign-up is only possible with bingol.edu.tr email addresses and email verification.',
  'pg.security.s1.l6': 'Rate limits apply to sign-in, verification and write endpoints.',
  'pg.security.s2.h': 'Reporting a vulnerability',
  'pg.security.s2.p1':
    'If you believe you have found a security vulnerability, please report it to us privately first. We welcome good-faith reports that follow the rules below.',
  'pg.security.s2.l1': 'Include the affected address or endpoint, steps to reproduce and the likely impact.',
  'pg.security.s2.l2':
    'Do not access, delete or modify other people’s data, and do not run tests that disrupt the service (heavy load, denial of service).',
  'pg.security.s2.l3': 'Do not disclose publicly until the issue is fixed.',
  'pg.security.s2.l4': 'We will try to respond when we receive your report.',
  'pg.security.s3.h': 'Scope',
  'pg.security.s3.l1': 'In scope: the BÜ Kampüs mobile app, this website and the API.',
  'pg.security.s3.l2':
    'Out of scope: university systems on bingol.edu.tr and its subdomains (report those to the relevant unit), social engineering, physical attacks and third-party services.',
  'pg.security.s4.h': 'Contact',
  'pg.security.s4.p1': 'Send your reports to the contact address below.',
  'pg.security.s5.h': 'Tips for users',
  'pg.security.s5.l1': 'Do not reuse your password on other services.',
  'pg.security.s5.l2': 'If you see suspicious content or a suspicious user, report it from the app.',
  'pg.security.s5.l3': 'Keep your device and the app up to date.',
  'pg.security.contactNone': 'No email address is registered at the moment; use the options on the contact page.',
  'pg.security.txt': 'security.txt file',

  // --- Community guidelines ---
  'pg.guidelines.title': 'Community guidelines',
  'pg.guidelines.lead': 'The rules for a campus where everyone feels safe, and how they are enforced.',
  'pg.guidelines.meta': 'BÜ Kampüs community guidelines: expectations, reporting, moderation decisions and appeals.',
  'pg.guidelines.s1.h': 'What we expect',
  'pg.guidelines.s1.l1': 'Be respectful; harassment, hate speech, threats and bullying are not allowed.',
  'pg.guidelines.s1.l2': 'Do not share other people’s personal information without permission.',
  'pg.guidelines.s1.l3': 'Do not post illegal, obscene or violent content.',
  'pg.guidelines.s1.l4': 'Do not impersonate another person or a club; do not send spam or misleading content.',
  'pg.guidelines.s2.h': 'How to report content',
  'pg.guidelines.s2.p1':
    'You can report users, messages, posts, communities, events and images from the app. The same content cannot be reported again within a short period.',
  'pg.guidelines.s2.l1': 'Your report goes to the moderators’ queue; its priority rises when several people report it.',
  'pg.guidelines.s2.l2':
    'For some content types, content may be hidden automatically until reviewed once enough distinct users report it.',
  'pg.guidelines.s2.l3': 'You are told the outcome by notification.',
  'pg.guidelines.s3.h': 'Moderation decisions',
  'pg.guidelines.s3.p1': 'Moderators review the report and do one of the following:',
  'pg.guidelines.s3.l1': 'Dismiss the report (no violation found).',
  'pg.guidelines.s3.l2': 'Warn the content owner.',
  'pg.guidelines.s3.l3': 'Remove or hide the content.',
  'pg.guidelines.s3.l4':
    'For repeated violations, a suspension recommendation is sent to administrators; the final decision belongs to an administrator.',
  'pg.guidelines.s3.p2':
    'Bad-faith reports, or many baseless reports that are dismissed in a row, can lead to the report feature being restricted for a while.',
  'pg.guidelines.s4.h': 'Appeals',
  'pg.guidelines.s4.p1':
    'If your content was hidden and that content type can be restored, you can appeal once from the app. An administrator reviews the appeal; if it is accepted, the content becomes visible again and the violation record from it is cancelled.',
  'pg.guidelines.s4.p2':
    'If your account is suspended you cannot sign in to the app, so send your appeal through the options on the contact page.',
  'pg.guidelines.s5.h': 'Binding text',
  'pg.guidelines.s5.p1':
    'This page is informational; the binding text is the Community Rules version in the legal documents.',
  'pg.guidelines.fullText': 'Full Community Rules text',

  // --- Help centre ---
  'pg.help.title': 'Help centre',
  'pg.help.lead': 'Frequently asked questions, guides and ways to get support in one place.',
  'pg.help.meta': 'BÜ Kampüs help centre: FAQ, account, privacy, rules and support.',
  'pg.help.cat.start.title': 'Getting started and account',
  'pg.help.cat.start.text': 'Sign-up, email verification, signing in and profile details.',
  'pg.help.cat.features.title': 'Messages and communities',
  'pg.help.cat.features.text': 'Chat, clubs, events and QR attendance.',
  'pg.help.cat.safety.title': 'Privacy and security',
  'pg.help.cat.safety.text': 'How your data is protected and how to report a vulnerability.',
  'pg.help.cat.rules.title': 'Rules and moderation',
  'pg.help.cat.rules.text': 'Community guidelines, reporting and appeals.',
  'pg.help.cat.data.title': 'Account and data',
  'pg.help.cat.data.text': 'Deleting your account, downloading your data and KVKK requests.',
  'pg.help.cat.status.title': 'Something not working?',
  'pg.help.cat.status.text': 'Current status of the news and menu sources.',
  'pg.help.open': 'Open',
  'pg.help.supportTitle': 'Still need help?',
  'pg.help.supportText':
    'If you could not find an answer, follow the steps on the contact page to open a support request from the app, or write to us.',
  'pg.help.faq': 'Frequently asked questions',
  'pg.help.contact': 'Contact us',

  // --- Status ---
  'pg.status.title': 'Current status',
  'pg.status.lead': 'A summary of the news and menu sources and of app-wide maintenance.',
  'pg.status.meta': 'BÜ Kampüs current status: news and menu sources and maintenance notices.',
  'pg.status.allOk': 'All sources are working',
  'pg.status.someMaint': 'Some sources are under maintenance',
  'pg.status.appMaint': 'The app is under maintenance',
  'pg.status.appOk': 'App services are normal',
  'pg.status.src.NEWS': 'News and announcements',
  'pg.status.src.MENU': 'Menu',
  'pg.status.ok': 'Working',
  'pg.status.maint': 'Under maintenance',
  'pg.status.lastOk': 'Last successful update: {date}',
  'pg.status.lastTry': 'Last attempt: {date}',
  'pg.status.never': 'Not updated yet',
  'pg.status.note':
    'When the source site changes or is unreachable, the last successful data keeps being shown.',
  'pg.status.empty': 'No status information found',
  'pg.status.emptyHint': 'Source statuses have not been reported yet.',
  'pg.status.error': 'Could not load the status',
  'pg.status.refresh': 'Refresh',

  // --- News ---
  'pg.news.title': 'News and announcements',
  'pg.news.lead': 'News, announcements and events published by Bingöl University.',
  'pg.news.meta': 'Bingöl University news, announcements and events in BÜ Kampüs.',
  'pg.news.filter': 'Type filter',
  'pg.news.type.ALL': 'All',
  'pg.news.type.HABER': 'News',
  'pg.news.type.DUYURU': 'Announcement',
  'pg.news.type.ETKINLIK': 'Event',
  'pg.news.empty': 'No content of this type',
  'pg.news.emptyHint': 'New items from the source site will appear here.',
  'pg.news.error': 'Could not load the news',
  'pg.news.source': 'Source: Bingöl University',
  'pg.news.attribution':
    'The content belongs to Bingöl University; BÜ Kampüs only compiles and displays it. See the original page for the current, authoritative text.',
  'pg.news.original': 'Open the original page (bingol.edu.tr)',
  'pg.news.back': 'All news',
  'pg.news.notFound': 'Content not found',
  'pg.news.notFoundHint': 'This item may have been removed or may never have existed.',
  'pg.news.noContent': 'The text of this item is published on an external site. Open the original page to read it in full.',
  'pg.news.read': 'Read more',
  'pg.news.untitledImage': 'News image',

  // --- Menu ---
  'pg.menu.title': 'Menu',
  'pg.menu.lead': 'The daily and monthly menu of the university canteen.',
  'pg.menu.meta': 'The daily and monthly menu of the Bingöl University canteen.',
  'pg.menu.view': 'View',
  'pg.menu.view.day': 'Daily',
  'pg.menu.view.month': 'Monthly',
  'pg.menu.today': 'Today',
  'pg.menu.prevDay': 'Previous day',
  'pg.menu.nextDay': 'Next day',
  'pg.menu.prevMonth': 'Previous month',
  'pg.menu.nextMonth': 'Next month',
  'pg.menu.noDay': 'No menu for this date',
  'pg.menu.noDayHint': 'A menu may not be published on weekends or holidays.',
  'pg.menu.noMonth': 'No menu published for this month',
  'pg.menu.noMonthHint': 'It will appear here once published.',
  'pg.menu.error': 'Could not load the menu',
  'pg.menu.maintenance': 'The menu source is under maintenance; the last successful menu is shown.',

  // --- Brand kit ---
  'pg.brand.title': 'Press and brand kit',
  'pg.brand.lead': 'BÜ Kampüs logos, colours and usage rules.',
  'pg.brand.meta': 'BÜ Kampüs logo variants, brand colours and usage rules; a downloadable kit for the press.',
  'pg.brand.logos': 'Logos',
  'pg.brand.logosText': 'Use the “light” version on light backgrounds and the “dark” one on dark backgrounds. Single-colour versions are for busy or coloured backgrounds.',
  'pg.brand.logo.mark': 'Mark',
  'pg.brand.logo.horizontalLight': 'Horizontal · light background',
  'pg.brand.logo.horizontalDark': 'Horizontal · dark background',
  'pg.brand.logo.verticalLight': 'Vertical · light background',
  'pg.brand.logo.verticalDark': 'Vertical · dark background',
  'pg.brand.logo.horizontalWhite': 'Horizontal · single colour white',
  'pg.brand.logo.horizontalBlack': 'Horizontal · single colour black',
  'pg.brand.logo.markWhite': 'Mark · single colour white',
  'pg.brand.logo.markBlack': 'Mark · single colour black',
  'pg.brand.download': 'Download {name} ({format})',
  'pg.brand.colors': 'Colours',
  'pg.brand.color.brand': 'Logo red',
  'pg.brand.color.brandUse': 'Logo, large surfaces, header areas',
  'pg.brand.color.action': 'Action red',
  'pg.brand.color.actionUse': 'Buttons and links; AA contrast with white text',
  'pg.brand.color.ink': 'Ink',
  'pg.brand.color.inkUse': 'Text, badges and dark surfaces',
  'pg.brand.color.bg': 'Background',
  'pg.brand.color.bgUse': 'Page background',
  'pg.brand.rules': 'Usage rules',
  'pg.brand.rule.1': 'Always write the product name as “BÜ Kampüs”; it is not translated in Arabic text either.',
  'pg.brand.rule.2': 'Leave clear space around the logo equal to 25% of the mark’s height.',
  'pg.brand.rule.3': 'Minimum size: mark 16 px, horizontal lockup 28 px tall.',
  'pg.brand.rule.4': 'Do not rotate, stretch or recolour the logo, or add shadows or glows.',
  'pg.brand.rule.5': 'On red or busy backgrounds use the single-colour version instead of the coloured logo.',
  'pg.brand.rule.6': 'The official Bingöl University logo is not part of this kit; contact the university for institutional use.',
  'pg.brand.pressTitle': 'Press contact',
  'pg.brand.pressText': 'For press questions and image requests, use the addresses on the contact page.',

  // --- Changelog ---
  'pg.changelog.title': 'Release notes',
  'pg.changelog.lead': 'Notable changes to BÜ Kampüs.',
  'pg.changelog.meta': 'BÜ Kampüs release notes: new features, improvements and security changes.',
  'pg.changelog.empty': 'No release notes yet',
  'pg.changelog.e1.date': '2026-10',
  'pg.changelog.e1.title': 'October 2026',
  'pg.changelog.e1.l1': 'Messages are stored encrypted on the server; administrator access is justified and tied to the audit log.',
  'pg.changelog.e1.l2': 'Event applications and acceptance: accept, reject and waiting list.',
  'pg.changelog.e1.l3': 'Club permissions, ownership transfer and invite codes.',
  'pg.changelog.e1.l4': 'Image sharing in chats; reporting inappropriate images and an appeals process.',
  'pg.changelog.e1.l5': 'Privacy settings: you choose who sees what on your profile.',
  'pg.changelog.e1.l6': 'Website refreshed: new colour palette, news, menu, help and legal pages.',
  'pg.changelog.e2.date': '2026-09',
  'pg.changelog.e2.title': 'September 2026',
  'pg.changelog.e2.l1': 'News, announcements and events, plus the monthly menu.',
  'pg.changelog.e2.l2': 'Communities, events, QR and manual attendance.',
  'pg.changelog.e2.l3': 'Turkish, English and Arabic interfaces.',
  'pg.changelog.note': 'This list is compiled by hand; minor fixes may not be included.',

  // --- Sitemap ---
  'pg.sitemap.title': 'Sitemap',
  'pg.sitemap.lead': 'All public pages on the site.',
  'pg.sitemap.meta': 'A list of all pages on the BÜ Kampüs website.',
} as const;
export default m;
