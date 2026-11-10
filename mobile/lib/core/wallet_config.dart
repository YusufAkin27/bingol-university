/// Cüzdan (Apple Wallet / Google Cüzdan) bilet entegrasyonu bayrağı (T1). Varsayılan KAPALI: imzalama sertifikası
/// ve servis hesabı henüz yok (bkz. docs/WALLET_SETUP.md). Derleme anında `--dart-define=WALLET_ENABLED=true`;
/// düğme ayrıca sunucu `wallet.apple|google` bayrağı açıksa görünür. Bu sürümde düğme gerçek ekleme YAPMAZ.
const bool kWalletEnabled = bool.fromEnvironment('WALLET_ENABLED');
