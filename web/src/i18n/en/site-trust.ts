// Legal and trust pages (SITE3): "At a glance" point boxes, extra section of the legal list, delete-account screenshot alt text.
// The points only summarise behaviour already described in the pages' own texts (pg.*) and present in the app; no new claims.
const m = {
  'site.trust.glance': 'At a glance',
  'site.trust.toc': 'On this page',
  'site.shot.delete.alt':
    'BÜ Kampüs Delete account screen: a warning that the action cannot be undone, a “What happens” list, a confirmation checkbox and a “Continue” button.',

  'site.trust.security.pt1': 'Membership requires a valid email address and email verification.',
  'site.trust.security.pt2':
    'Messages are stored encrypted on the server; administrator access needs a written reason and is written to an audit log.',
  'site.trust.security.pt3': 'The connection is encrypted with HTTPS; passwords and session keys are stored only as hashes.',
  'site.trust.security.pt4': 'Sign-in and write actions are rate limited; if you find a flaw you can report it responsibly.',

  'site.trust.child.pt1': 'No anonymous use: an account is opened only with a verified email.',
  'site.trust.child.pt2': 'Users, messages, posts, clubs and events can be reported from the app; users can be blocked.',
  'site.trust.child.pt3':
    'A post is one photo and a short text; posts have no comments or video. Location data is removed from uploaded photos.',
  'site.trust.child.pt4': 'You can email the Child Safety Contact directly.',

  'site.trust.guidelines.pt1': 'Respect comes first: harassment, hate speech, threats and bullying are prohibited.',
  'site.trust.guidelines.pt2': 'You can report content from the app; reports go to the moderators’ queue.',
  'site.trust.guidelines.pt3': 'You are notified when a decision is made.',
  'site.trust.guidelines.pt4': 'You can appeal moderation decisions; the process is described further down this page.',

  'site.trust.access.pt1': 'Full keyboard use and a visible focus indicator.',
  'site.trust.access.pt2': 'Text colours meet at least a 4.5:1 contrast ratio; light and dark themes are available.',
  'site.trust.access.pt3': 'Turkish, English and Arabic; right-to-left layout in Arabic.',
  'site.trust.access.pt4': 'Our target is WCAG 2.1 AA; an independent audit has not been carried out yet.',

  'site.trust.cookies.pt1': 'No advertising, tracking or analytics cookies.',
  'site.trust.cookies.pt2': 'The website does not write HTTP cookies to your browser.',
  'site.trust.cookies.pt3': 'Only your language, theme and this notice preference are kept in your browser.',

  'site.trust.list.moreTitle': 'Trust and safety',
  'site.trust.list.moreLead': 'The app’s approach to security, child safety, community rules, accessibility and cookies, plus the account deletion guide.',
} as const;
export default m;
