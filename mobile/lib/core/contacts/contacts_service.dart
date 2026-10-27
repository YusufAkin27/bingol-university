import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../api.dart';

/// Rehberdeki e-posta adreslerini okur (yalnız e-posta; ad/telefon okunmaz).
abstract class ContactsProvider {
  Future<List<String>> readEmails();
}

/// Cihaz rehberi (`flutter_contacts`; Android + iOS, iOS SwiftPM destekli). İzin çağıran tarafça alınır.
class DeviceContactsProvider implements ContactsProvider {
  @override
  Future<List<String>> readEmails() async {
    final all = await FlutterContacts.getAll(properties: {ContactProperty.email});
    return [
      for (final c in all)
        for (final e in c.emails) e.address,
    ];
  }
}

/// E-posta -> küçük harf, kırpılmış.
String normalizeEmail(String e) => e.trim().toLowerCase();

/// Yalnız `@bingol.edu.tr` ve alt alan adları gönderilir.
bool isCampusEmail(String e) {
  final i = e.lastIndexOf('@');
  if (i <= 0 || i == e.length - 1) return false;
  final host = e.substring(i + 1);
  return host == 'bingol.edu.tr' || host.endsWith('.bingol.edu.tr');
}

/// Sunucu sözleşmesi: kırpılmış küçük harfli e-postanın UTF-8 SHA-256 özeti (küçük harf hex).
String emailHash(String email) => sha256.convert(utf8.encode(normalizeEmail(email))).toString();

/// Sunucudaki parça sınırı.
const contactsChunkSize = 500;

/// Sunucu limiti: saatte 6 istek.
const contactsHourlyLimit = 6;

class ContactMatch {
  ContactMatch({required this.hash, required this.userId, required this.displayName, this.avatarUrl, this.faculty, this.department});

  factory ContactMatch.fromJson(Map<String, dynamic> j) => ContactMatch(
        hash: '${j['hash'] ?? ''}',
        userId: (j['userId'] as num).toInt(), // bozuksa çağıran try/catch ile eşleşmeyi atlar
        displayName: '${j['displayName'] ?? ''}',
        avatarUrl: j['avatarUrl'] is String ? j['avatarUrl'] as String : null,
        faculty: j['faculty'] is String ? j['faculty'] as String : null,
        department: j['department'] is String ? j['department'] as String : null,
      );

  final String hash;
  final int userId;
  final String displayName;
  final String? avatarUrl;
  final String? faculty;
  final String? department;

  /// "Bölüm" yoksa fakülte.
  String get sub => (department?.isNotEmpty ?? false) ? department! : (faculty ?? '');
}

/// Hashleri parçalayıp `POST /users/contacts/match` çağırır. Sonuçlar yalnız bellekte tutulur.
class ContactsMatcher {
  ContactsMatcher(this.api, {this.ownEmail});

  final ApiClient api;
  final String? ownEmail;

  /// Saatlik pencere için istek zamanları (süreç ömrü; kalıcı değil).
  static final List<DateTime> _sent = [];

  /// Rehber e-postalarını süz: kampüs alan adı, tekil, kendi adresin hariç.
  List<String> campusEmails(Iterable<String> raw) {
    final own = ownEmail == null ? null : normalizeEmail(ownEmail!);
    final out = <String>{};
    for (final r in raw) {
      final e = normalizeEmail(r);
      if (isCampusEmail(e) && e != own) out.add(e);
    }
    return out.toList()..sort();
  }

  /// Saatlik limite göre bu çağrıda en çok kaç istek atılabilir.
  static int get remainingRequests {
    final cut = DateTime.now().subtract(const Duration(hours: 1));
    _sent.removeWhere((d) => d.isBefore(cut));
    return contactsHourlyLimit - _sent.length;
  }

  /// Testler için sayaç sıfırlama.
  static void resetLimiter() => _sent.clear();

  /// Eşleşenleri döner. Limit aşılacaksa kalan parçalar atlanır ([ContactsMatchResult.truncated]).
  Future<ContactsMatchResult> match(List<String> emails) async {
    final hashes = emails.map(emailHash).toList();
    final matches = <ContactMatch>[];
    var truncated = false;
    for (var i = 0; i < hashes.length; i += contactsChunkSize) {
      if (remainingRequests <= 0) {
        truncated = true;
        break;
      }
      final chunk = hashes.sublist(i, i + contactsChunkSize > hashes.length ? hashes.length : i + contactsChunkSize);
      _sent.add(DateTime.now());
      final res = await api.post('/users/contacts/match', {'hashes': chunk});
      final list = (res is Map ? res['matches'] : null) as List? ?? const [];
      for (final m in list.whereType<Map>()) {
        try {
          matches.add(ContactMatch.fromJson(Map<String, dynamic>.from(m)));
        } catch (_) {}
      }
    }
    final seen = <int>{};
    final unique = [
      for (final m in matches)
        if (seen.add(m.userId)) m,
    ]..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return ContactsMatchResult(unique, candidates: emails.length, truncated: truncated);
  }
}

class ContactsMatchResult {
  ContactsMatchResult(this.matches, {required this.candidates, required this.truncated});
  final List<ContactMatch> matches;

  /// Gönderilen kampüs e-postası sayısı.
  final int candidates;
  final bool truncated;
}
