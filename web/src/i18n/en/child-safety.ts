// Public site: Child safety standards page (/child-safety; public URL for the Google Play CSAE declaration).
// Describes ONLY what the app actually does. Key pattern: pg.childsafety.<section>.h | .p1.. | .l1..
const m = {
  'pg.childsafety.title': 'Child safety standards',
  'pg.childsafety.lead':
    'BÜ Kampüs has zero tolerance for child sexual abuse and exploitation. This page explains how we prevent it, how we receive reports and how we respond.',
  'pg.childsafety.meta':
    'BÜ Kampüs child safety standards: prevention, reporting and response for child sexual abuse and exploitation (CSAE) and child sexual abuse material (CSAM).',

  'pg.childsafety.s1.h': 'Purpose and scope',
  'pg.childsafety.s1.p1':
    'BÜ Kampüs is an independent app built for students and staff of Bingöl University; it is not the university’s official app. It is not directed at children: the target audience is 18 and over, and signing up requires a verified bingol.edu.tr email address.',
  'pg.childsafety.s1.p2':
    'This page describes our standards against child sexual abuse and exploitation (CSAE) and child sexual abuse material (CSAM).',
  'pg.childsafety.s1.p3':
    'This content and behavior has no place in our app: when we find it we remove it, close the account and, where needed, report it to the competent authorities.',

  'pg.childsafety.s2.h': 'What we prohibit',
  'pg.childsafety.s2.p1': 'All of the following are strictly prohibited in the app:',
  'pg.childsafety.s2.l1':
    'Child sexual abuse material (CSAM): creating, sharing, requesting, storing or linking to any photo, video, drawing or text that depicts a person under 18 in a sexual way.',
  'pg.childsafety.s2.l2':
    'Sexual content involving children and sexualizing children: sexual comments about a child, or asking a child for sexual images or information.',
  'pg.childsafety.s2.l3':
    'Grooming: trying to build trust with a child, deceive them or lure them into isolation for the purpose of sexual abuse.',
  'pg.childsafety.s2.l4':
    'Sextortion: threatening or blackmailing a child with sexual images, or demanding money or new images that way.',
  'pg.childsafety.s2.l5': 'Trafficking of children and their sexual exploitation, including facilitating or directing others to it.',
  'pg.childsafety.s2.l6': 'Posts that encourage or normalize these behaviors, or explain how to find such content.',

  'pg.childsafety.s3.h': 'Prevention',
  'pg.childsafety.s3.p1': 'To reduce risk, the app is built like this:',
  'pg.childsafety.s3.l1':
    'Sign-up works only with a verified university email (bingol.edu.tr); no account is created until the emailed code is entered. There is no anonymous use.',
  'pg.childsafety.s3.l2':
    'Opening several accounts to abuse the service is prohibited. New accounts that match the device or IP record of a banned user can be blocked.',
  'pg.childsafety.s3.l3':
    'A post is a single photo plus a short text of at most 7 words; posts have no comments, stories or video. Chat is one-to-one and in groups; photos and short videos can be shared in chat.',
  'pg.childsafety.s3.l4':
    'Uploaded photos are re-encoded on the server and embedded metadata such as location (EXIF) is removed. Administrators can add the digital fingerprint of a specific image to a blocklist; an identical file is then rejected on upload.',
  'pg.childsafety.s3.l5':
    'Text in public areas (posts, profiles, clubs, events) is filtered for inappropriate and sexual expressions. Private chat messages are not scanned before they are sent.',
  'pg.childsafety.s3.p2':
    'To be clear: the app has no system that automatically recognizes CSAM (no hash-matching database, no image scanning and so on). Uploaded images are not analyzed automatically for their content; the blocklist only catches identical files that administrators have added by hand. This is why user reports and human review are our main safeguard.',

  'pg.childsafety.s4.h': 'How to report',
  'pg.childsafety.s4.p1': 'If you see content or behavior that endangers a child, report it right away:',
  'pg.childsafety.s4.l1':
    'In the app, use “Report” on a user, message, post, club or event. There is no separate child safety reason: choose “Inappropriate content” or “Other” and write “child safety” in the note.',
  'pg.childsafety.s4.l2': 'Block the suspicious user; messages from a blocked person are not delivered to you.',
  'pg.childsafety.s4.l3': 'Open a request in the Support section of the app, or use the contact page on the website.',
  'pg.childsafety.s4.l4': 'Email the Child Safety Contact Point directly (see the contact section on this page).',
  'pg.childsafety.s4.l5':
    'If you think a child is in immediate danger, first call the 112 emergency line (Türkiye) or your nearest law enforcement.',
  'pg.childsafety.s4.p2':
    'Do not forward or spread the suspicious image; that may be a crime too. It is enough to tell us where it is and which user is involved.',

  'pg.childsafety.s5.h': 'Our response',
  'pg.childsafety.s5.p1': 'When a report suggests CSAE or CSAM, we do the following:',
  'pg.childsafety.s5.l1':
    'We hide or remove the content right away. If three independent accounts report the same post, event or chat image, it is hidden automatically and temporarily until review is complete; administrators can also hide it on a single report.',
  'pg.childsafety.s5.l2':
    'Authorized administrators review reported chat content by entering a written reason; every access is written to a tamper-proof record.',
  'pg.childsafety.s5.l3': 'We suspend the account or close it permanently. For severe violations, intermediate steps such as warnings are skipped.',
  'pg.childsafety.s5.l4': 'Where needed we apply an access block by IP, network range or device; a new account does not get around it.',
  'pg.childsafety.s5.l5':
    'We try to preserve the relevant content and records (report, action and access records) so they can be handed to the competent authorities. We share these records only on lawful requests and only as far as necessary.',
  'pg.childsafety.s5.l6':
    'We report to the cybercrime units of law enforcement and to the prosecutor’s office in Türkiye and, where applicable, to international child protection organizations and hotlines.',
  'pg.childsafety.s5.p2': 'We comply with applicable laws and with requests from competent authorities.',

  'pg.childsafety.s6.h': 'Process and transparency',
  'pg.childsafety.s6.p1':
    'We try to review reports without delay; reports that suggest a child safety violation come first. We do not promise a fixed response time.',
  'pg.childsafety.s6.p2':
    'You can appeal content removal or account restriction decisions through the appeal feature in the app or the Support section. A report to the competent authorities for a child safety violation is independent of any appeal.',
  'pg.childsafety.s6.p3':
    'We update these standards as the app, our knowledge and the law change. For more detailed rules, see the Community Guidelines and the Terms of Use.',
  'pg.childsafety.s6.p4': 'Last updated: 29 October 2026',

  'pg.childsafety.s7.h': 'Child Safety Contact Point',
  'pg.childsafety.s7.p1':
    'For child safety reports, requests from competent authorities and questions about these standards, write to the Child Safety Contact Point. This role belongs to the developer and administrator.',
  'pg.childsafety.s7.l1': 'Email: ysufakin23@gmail.com',
  'pg.childsafety.mail': 'Send email',
  'pg.childsafety.rules': 'Community Guidelines',
  'pg.childsafety.terms': 'Terms of Use',
} as const;
export default m;
