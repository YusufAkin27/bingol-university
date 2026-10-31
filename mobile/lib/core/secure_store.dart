import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Oturum/cihaz kimliği/kuyruk gibi cihaza özel sırlar için güvenli depo: iOS'ta kayıtlar bu cihaza bağlıdır
/// (şifreli cihaz yedeğiyle başka cihaza taşınmaz) ve ilk kilit açılışından sonra okunur. Android'de etkisizdir.
/// Eski (varsayılan erişilebilirlikle yazılmış) kayıtlar eklenti tarafından okunmaya devam eder.
const kDeviceOnlyIOptions = IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device);

const FlutterSecureStorage kDeviceSecureStorage = FlutterSecureStorage(iOptions: kDeviceOnlyIOptions);
