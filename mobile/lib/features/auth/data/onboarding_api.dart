import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/api.dart';
import '../../../core/secure_store.dart';

/// Profil tamamlama (OAuth sonrası 2 aşamalı onboarding) sunucu sözleşmesi: alan adları TEK bu dosyada.
/// Sözleşme: `PUT /users/me/onboarding`, `GET /users/username-available?u=` (docs/changes/auth.md, docs/MOBILE_API_GUIDE.md).

/// Sınıf seçenekleri. [wire]: sunucuya giden değer.
enum ClassYear {
  prep('PREP', null),
  y1('Y1', 1),
  y2('Y2', 2),
  y3('Y3', 3),
  y4('Y4', 4),
  y5('Y5', 5),
  y6('Y6', 6),
  postgrad('POSTGRAD', null),
  other('OTHER', null);

  const ClassYear(this.wire, this.year);

  final String wire;

  /// 1..6 için sınıf yılı; diğerleri null.
  final int? year;

  static ClassYear? fromWire(String? v) {
    for (final c in values) {
      if (c.wire == v) return c;
    }
    return null;
  }
}

/// Bölüme uygun sınıf seçenekleri. [programYears] (katalogdaki bölüm süresi) biliniyorsa daha uzun sınıflar elenir;
/// bilinmiyorsa TÜM seçenekler döner. Hazırlık, Lisansüstü ve Diğer her zaman vardır.
List<ClassYear> classYearsFor({int? programYears}) {
  final max = programYears;
  return [
    for (final c in ClassYear.values)
      if (c.year == null || max == null || max <= 0 || c.year! <= max) c,
  ];
}

/// Kullanıcı adı müsaitlik cevabı. [reason]: `TAKEN` / `INVALID` / `RESERVED` (müsait değilse).
class UsernameCheck {
  const UsernameCheck({required this.available, this.reason});

  factory UsernameCheck.fromJson(Object? j) {
    if (j is! Map || j['available'] is! bool) throw ApiError(0, 'BAD_RESPONSE', '');
    final r = j['reason'];
    return UsernameCheck(available: j['available'] as bool, reason: r is String ? r.toUpperCase() : null);
  }

  final bool available;
  final String? reason;
}

/// İstemci tarafı kullanıcı adı kuralı: 3-24 karakter, yalnız a-z 0-9 . _ (sunucu yine de doğrular).
final RegExp kUsernameRule = RegExp(r'^[a-z0-9._]{3,24}$');

/// Onboarding gövdesi (iki aşamanın birleşimi).
class OnboardingForm {
  const OnboardingForm({
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.classYear,
    this.universityName = 'Bingöl Üniversitesi',
    this.facultyId,
    this.facultyName,
    this.departmentId,
    this.departmentName,
    this.bio,
  });

  final String firstName;
  final String lastName;
  final String username;
  final ClassYear classYear;
  final String universityName;
  final String? facultyId;
  final String? facultyName;
  final String? departmentId;
  final String? departmentName;
  final String? bio;

  /// `PUT /users/me/onboarding` gövdesi. Fakülte/bölüm hem kimlikle hem kanonik (Türkçe) adla gider.
  Map<String, Object?> toJson() {
    String? clean(String? v) => v == null || v.trim().isEmpty ? null : v.trim();
    return {
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'username': username.trim().toLowerCase(),
      'universityName': universityName,
      // Sunucu OAuth'ta sözleşme kabulünü onboarding'de kaydeder (giriş ekranında "Devam ederek ... kabul etmiş olursun").
      'acceptTerms': true,
      if (clean(facultyId) != null) 'facultyId': facultyId,
      if (clean(facultyName) != null) 'facultyName': facultyName,
      if (clean(departmentId) != null) 'departmentId': departmentId,
      if (clean(departmentName) != null) 'departmentName': departmentName,
      'classYear': classYear.wire,
      if (clean(bio) != null) 'bio': bio!.trim(),
    };
  }
}

class OnboardingApi {
  OnboardingApi(this.api);

  final ApiClient api;

  /// `GET /users/username-available?u=`.
  Future<UsernameCheck> usernameAvailable(String username) async {
    final r = await api.get('/users/username-available?u=${Uri.encodeQueryComponent(username)}', force: true);
    return UsernameCheck.fromJson(r);
  }

  /// `PUT /users/me/onboarding`; başarıda profil önbelleği bayatlar. 409 `USERNAME_TAKEN`, 422 doğrulama ApiError olarak çıkar.
  Future<void> submit(OnboardingForm form) async {
    await api.put('/users/me/onboarding', form.toJson());
    api.invalidate('/users/me');
  }
}

/// Yarım kalan onboarding taslağı (yalnız güvenli yerel depo; kişisel veri minimum: biyografi ve fotoğraf SAKLANMAZ).
/// Apple yalnız ilk yetkilendirmede verdiği ad/soyadı da buraya yazılır; onboarding bitince ve çıkışta silinir.
class OnboardingDraft {
  const OnboardingDraft({
    this.firstName = '',
    this.lastName = '',
    this.username = '',
    this.facultyId,
    this.departmentId,
    this.classYear,
    this.step = 0,
  });

  factory OnboardingDraft.fromJson(Map<String, dynamic> j) {
    String s(String k) => j[k] is String ? j[k] as String : '';
    String? n(String k) => j[k] is String && (j[k] as String).isNotEmpty ? j[k] as String : null;
    return OnboardingDraft(
      firstName: s('firstName'),
      lastName: s('lastName'),
      username: s('username'),
      facultyId: n('facultyId'),
      departmentId: n('departmentId'),
      classYear: ClassYear.fromWire(n('classYear')),
      step: j['step'] == 1 ? 1 : 0,
    );
  }

  final String firstName;
  final String lastName;
  final String username;
  final String? facultyId;
  final String? departmentId;
  final ClassYear? classYear;
  final int step;

  Map<String, Object?> toJson() => {
        'firstName': firstName,
        'lastName': lastName,
        'username': username,
        if (facultyId != null) 'facultyId': facultyId,
        if (departmentId != null) 'departmentId': departmentId,
        if (classYear != null) 'classYear': classYear!.wire,
        'step': step,
      };
}

class OnboardingDraftStore {
  OnboardingDraftStore._();

  static const _key = 'onboarding_draft';
  static const FlutterSecureStorage _storage = kDeviceSecureStorage;

  static Future<OnboardingDraft?> load() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return null;
      final j = jsonDecode(raw);
      return j is Map<String, dynamic> ? OnboardingDraft.fromJson(j) : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(OnboardingDraft d) async {
    try {
      await _storage.write(key: _key, value: jsonEncode(d.toJson()));
    } catch (_) {}
  }

  /// Apple'ın yalnız bir kez verdiği ad/soyadı, onboarding açılana kadar saklar (mevcut taslağı bozmadan).
  static Future<void> savePrefill({String? firstName, String? lastName}) async {
    final f = (firstName ?? '').trim();
    final l = (lastName ?? '').trim();
    if (f.isEmpty && l.isEmpty) return;
    final cur = await load() ?? const OnboardingDraft();
    await save(OnboardingDraft(
      firstName: cur.firstName.isEmpty ? f : cur.firstName,
      lastName: cur.lastName.isEmpty ? l : cur.lastName,
      username: cur.username,
      facultyId: cur.facultyId,
      departmentId: cur.departmentId,
      classYear: cur.classYear,
      step: cur.step,
    ));
  }

  static Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
  }
}
