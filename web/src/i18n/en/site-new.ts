// Public site: new features (event applications, club permissions, image sharing, privacy, encryption) and admin access notice (T17).
const m = {
  'site.feat.admission.title': 'Event applications and acceptance',
  'site.feat.admission.text':
    'Event organizers can require applications; each one is answered with accept, reject or waitlist. When a spot opens, the next person on the waitlist is notified.',
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
    'Your messages are encrypted in transit and stored encrypted on the server. Administrator access requires a written justification, and every access is written to an audit record.',
  'site.home.privacy4': 'Messages are sent and stored encrypted; administrator access is justified and audited.',

  'site.faq.new.title': 'About the new features',
  'site.faq.new.apply.q': 'How do I apply to an event?',
  'site.faq.new.apply.a':
    'On the page of an event that needs applications, tap “Apply”. The organizer accepts, rejects or waitlists your application and you get a notification. If the event is full, you can see your place on the waitlist.',
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
    'Messages are not shown to administrators by default. In a concrete situation such as a complaint, a security incident or a legal obligation, access is possible only with a written justification, and every access is written to an immutable audit record.',

  'legal.adminAccess.title': 'Administrator access with justification and audit',
  'legal.adminAccess.body1':
    'Messages are encrypted in transit and stored encrypted. Administrators cannot access message content by default.',
  'legal.adminAccess.body2':
    'In a concrete situation such as a complaint, a security incident or a legal obligation, an authorized administrator may request access only for the relevant conversation and message range by giving a written justification. Every access is written to an immutable audit record that shows who did it, when and for what reason.',
  'legal.adminAccess.draft': 'This text is a draft; legal review is required before it is published.',
} as const;
export default m;
