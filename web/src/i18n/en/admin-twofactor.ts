const m = {
  // Login: code step
  'admin.login.2fa.title': 'Login code',
  'admin.login.2fa.subtitle': 'A verification code was sent to:',
  'admin.login.2fa.code': 'Login code',
  'admin.login.2fa.codeRequired': 'Enter the 6-digit code.',
  'admin.login.2fa.remaining': 'Code valid for: {time}',
  'admin.login.2fa.expired': 'The code has expired. Request a new one or go back to sign in.',
  'admin.login.2fa.trust': 'Trust this browser (do not ask for a code next time)',
  'admin.login.2fa.submit': 'Verify and sign in',
  'admin.login.2fa.submitting': 'Verifying…',
  'admin.login.2fa.resend': 'Resend code',
  'admin.login.2fa.resent': 'A new code was sent to your email.',
  'admin.login.2fa.back': 'Back to sign in',
  'common.error.TWO_FACTOR_CODE_INVALID': 'The code is incorrect. Check it and try again.',
  'common.error.TWO_FACTOR_CHALLENGE_EXPIRED': 'The code has expired. Request a new one or sign in again.',
  'common.error.TWO_FACTOR_NOT_ENABLED': 'Two-factor authentication is not enabled on this account.',
  'common.error.TWO_FACTOR_ALREADY_ENABLED': 'Two-factor authentication is already enabled.',

  // Menu and page
  'admin.nav.twoFactor': 'Two-factor authentication',
  'admin.twoFactor.title': 'Two-factor authentication',
  'admin.twoFactor.intro':
    'Users who enable two-factor authentication enter a 6-digit code emailed to them when signing in from an unrecognised device.',
  'admin.twoFactor.sum.enabled': 'Users with 2FA',
  'admin.twoFactor.sum.percent': 'Share of active users',
  'admin.twoFactor.sum.percentHint': 'of {n} active users',
  'admin.twoFactor.sum.last7': 'Enabled in the last 7 days',
  'admin.twoFactor.sum.devices': 'Trusted devices (total)',
  'admin.twoFactor.searchPlaceholder': 'Search by name or email',
  'admin.twoFactor.count': '{n} users',
  'admin.twoFactor.col.name': 'Name',
  'admin.twoFactor.col.email': 'Email',
  'admin.twoFactor.col.role': 'Role',
  'admin.twoFactor.col.enabledAt': 'Enabled on',
  'admin.twoFactor.col.devices': 'Trusted devices',
  'admin.twoFactor.col.lastLogin': 'Last sign-in',
  'admin.twoFactor.col.detail': 'Details',
  'admin.twoFactor.openUser': 'Open details for {name}',
  'admin.twoFactor.never': 'Never',
  'admin.twoFactor.empty.title': 'No users found',
  'admin.twoFactor.empty.hint': 'No user has enabled two-factor authentication, or none matched your search.',

  // User list
  'admin.users.col.twoFactor': '2FA',
  'admin.users.twoFactor.on': 'On',
  'admin.users.twoFactor.onDevices': 'On · {n} devices',
  'admin.users.twoFactor.off': 'Off',
  'admin.users.filter.twoFactor': 'Two-factor',
  'admin.users.filter.twoFactor.true': 'On',
  'admin.users.filter.twoFactor.false': 'Off',

  // User details
  'admin.users.tf.title': 'Two-factor authentication',
  'admin.users.tf.status': 'Status',
  'admin.users.tf.enabledAt': 'Enabled on',
  'admin.users.tf.devices': 'Trusted devices',
  'admin.users.tf.offNote': 'The user has not enabled two-factor authentication.',
  'admin.users.tf.disable': 'Turn off 2FA',
  'admin.users.tf.disable.title': 'Turn off two-factor authentication',
  'admin.users.tf.disable.explain':
    'This is an account recovery action for users who cannot access their email. All trusted devices are removed, all of the user\'s sessions are closed, the user is notified by notification and email, and the action is written to the audit log. Only FULL and SUPPORT administrators can do this; you cannot turn off your own account or a FULL administrator account from the panel.',
  'admin.users.tf.selfNote':
    'You cannot turn off your own two-factor authentication from the panel; turn it off in your account settings with your password.',
  'admin.users.tf.disable.confirm': 'Turn off two-factor authentication for {name}?',
  'admin.users.tf.disable.reason': 'Reason',
  'admin.users.tf.disable.reasonHint':
    'Written to the audit log (e.g. the user cannot access their university email).',
  'admin.users.tf.disable.reasonRequired': 'Enter a reason.',
  'admin.users.tf.disable.done': 'Two-factor authentication was turned off.',
} as const;
export default m;
