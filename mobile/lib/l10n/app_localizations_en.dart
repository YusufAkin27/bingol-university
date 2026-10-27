// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get commonRetry => 'Try again';

  @override
  String get commonRetryShort => 'Retry';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonClose => 'Close';

  @override
  String get commonLoading => 'Loading';

  @override
  String get commonUpdate => 'Update';

  @override
  String get commonOpenInStore => 'Open in store';

  @override
  String get commonSomethingWentWrong => 'Something went wrong';

  @override
  String get configError =>
      'Configuration error: the server address (API_BASE) is not secure (https). Rebuild the app with the correct address.';

  @override
  String get exitAgainHint => 'Press back again to exit';

  @override
  String get navHome => 'Home';

  @override
  String get navDiscover => 'Discover';

  @override
  String get navChat => 'Chat';

  @override
  String get navClubs => 'Clubs';

  @override
  String get navProfile => 'Profile';

  @override
  String get updateRequiredTitle => 'Update required';

  @override
  String get updateRequiredBody =>
      'You need to update to the latest version to keep using the app.';

  @override
  String get updateAvailable => 'A new version is available.';

  @override
  String updateAvailableVersion(String version) {
    return 'A new version is available ($version).';
  }

  @override
  String get accessBlockedTitle => 'Access blocked';

  @override
  String get accessBlockedBody =>
      'Access from this device or network has been blocked. If you think this is a mistake, contact support.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionAppearance => 'APPEARANCE';

  @override
  String get settingsSectionNotifications => 'NOTIFICATIONS';

  @override
  String get settingsSectionPrivacy => 'PRIVACY AND ACCOUNT';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageHint => 'App, notification and email language';

  @override
  String get languageSystem => 'System';

  @override
  String get pushPermission => 'Notification permission (push)';

  @override
  String get pushNotConfigured => 'Not configured yet';

  @override
  String get pushOn => 'On';

  @override
  String get pushOff => 'Off (enable in system settings)';

  @override
  String get pushNotGranted => 'Permission not granted';

  @override
  String get pushOnToast => 'Push notifications are on.';

  @override
  String pushStatusToast(String status) {
    return 'Push notifications: $status';
  }

  @override
  String get settingsShowEmail => 'Show my email to others';

  @override
  String get settingsFindContacts => 'Find people from contacts';

  @override
  String get settingsPrivacyData => 'Privacy and data';

  @override
  String get settingsSupport => 'Support and FAQ';

  @override
  String get settingsLogoutAll => 'Sign out of all devices';

  @override
  String get settingsLogoutAllTitle => 'Sign out of all devices';

  @override
  String get settingsLogoutAllBody =>
      'Your account will be signed out on all devices and you will need to sign in again.';

  @override
  String get settingsLogoutAllConfirm => 'Sign out';

  @override
  String settingsVersion(String version) {
    return 'BÜ Kampüs · Version $version';
  }

  @override
  String get loginWelcome => 'Welcome';

  @override
  String get loginSubtitle => 'Sign in with your Bingöl University account.';

  @override
  String get loginReplacedNotice =>
      'Your account was signed in on another device. For your security, the session on this device was closed.';

  @override
  String get loginPasswordRequired => 'Enter your password.';

  @override
  String get loginForgotPassword => 'Forgot password';

  @override
  String get loginSubmit => 'Sign in';

  @override
  String get loginNoAccount => 'Do not have an account?';

  @override
  String get loginRegister => 'Sign up';

  @override
  String get loginCompleteVerification => 'Complete verification';

  @override
  String get authBack => 'Back';

  @override
  String get authShowPassword => 'Show password';

  @override
  String get authHidePassword => 'Hide password';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authIdHint => 'School number or email';

  @override
  String get authVerify => 'Verify';

  @override
  String get authResendCode => 'Resend code';

  @override
  String authResendIn(String seconds) {
    return 'Resend ($seconds s)';
  }

  @override
  String authNewCodeIn(String seconds) {
    return 'Wait $seconds s for a new code';
  }

  @override
  String get authCodeSent => 'Code sent.';

  @override
  String get authNewCodeSent => 'A new code has been sent.';

  @override
  String get authEnterCode => 'Enter the code';

  @override
  String authCodeSentTo(String email) {
    return 'A code was sent to $email.';
  }

  @override
  String get authVerifyEmailTitle => 'Verify your email';

  @override
  String authVerifySubtitle(String email) {
    return 'A code was sent to $email. It is valid for 10 minutes.';
  }

  @override
  String get authUnverifiedNotice =>
      'Verify your email. Your account must be verified before you can sign in.';

  @override
  String get authUseOtherAccount => 'Sign in with another account';

  @override
  String get authResetTitle => 'Reset your password';

  @override
  String get authSendCode => 'Send code';

  @override
  String get authNewPasswordTitle => 'New password';

  @override
  String get authNewPasswordLabel => 'New password (at least 8 characters)';

  @override
  String get authUpdatePassword => 'Update password';

  @override
  String get authPasswordUpdated => 'Password updated.';

  @override
  String get authSessionExpired => 'Time expired. Please start over.';

  @override
  String get authCreateAccount => 'Create account';

  @override
  String get authSelectDepartment => 'Select your department.';

  @override
  String get authSelectGrade => 'Select your year.';

  @override
  String get authDepartmentsLoadFailed =>
      'Could not load the department list. Try again.';

  @override
  String get authNameRequired => 'Enter your first and last name.';

  @override
  String get authNameHint => 'Full name';

  @override
  String get authPasswordMin8 => 'Password (at least 8 characters)';

  @override
  String get authTermsPrefix => 'I accept the ';

  @override
  String get authTermsLink => 'Terms of Use';

  @override
  String get authTermsSep => ' and ';

  @override
  String get authPrivacyLink => 'Privacy Policy';

  @override
  String get authTermsSuffix => '';

  @override
  String get authMustAccept => 'You must accept to continue.';

  @override
  String get authHaveAccount => 'Already have an account?';
}
