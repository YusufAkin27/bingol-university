import 'package:bu_kampus/features/scan/scan_resolver.dart';
import 'package:bu_kampus/features/share/share_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tek QR tarayıcı çözümleme tablosu', () {
    test('profil: başkası / kendisi', () {
      final o = resolveScan('https://bukampus.com.tr/s/u/7', selfId: 1);
      expect(o.kind, ScanKind.profile);
      expect(o.target, const ShareTarget(ShareType.user, 7));
      expect(resolveScan('bukampus://s/u/1', selfId: 1).kind, ScanKind.ownProfile);
    });

    test('kulüp, anket, etkinlik bağlantısı içerik olarak açılır', () {
      expect(resolveScan('https://bukampus.com.tr/s/c/5').target, const ShareTarget(ShareType.club, 5));
      expect(resolveScan('https://bukampus.com.tr/s/o/9').target, const ShareTarget(ShareType.poll, 9));
      expect(resolveScan('bukampus://s/e/3').kind, ScanKind.content);
    });

    test('etkinlik yoklama yükü', () {
      final r = resolveScan('bingol-checkin:12.345.abcDEF_-x');
      expect(r.kind, ScanKind.checkin);
      expect(r.eventId, 12);
      expect(r.code, 'bingol-checkin:12.345.abcDEF_-x');
    });

    test('ders yoklama yükü', () {
      const p = 'bingol-lesson:42.368000000.AbC_-defGhIjKlMnOpQrSt';
      final r = resolveScan(p);
      expect(r.kind, ScanKind.lesson);
      expect(r.code, p);
      expect(r.valid, isTrue);
      expect(resolveScan('  $p  ').code, p);
    });

    test('ders yoklama yükü: uzun / önek / sayı olmayan oturum / boşluk: geçersiz', () {
      for (final v in [
        'bingol-lesson:42.${'a' * 260}',
        'bingol-lesson:${'9' * 19}.1.sig',
        'BINGOL-LESSON:42.1.sig',
        'xbingol-lesson:42.1.sig',
        'bingol-lessons:42.1.sig',
        'bingol-lesson:abc.1.sig',
        'bingol-lesson:42',
        'bingol-lesson:42.',
        'bingol-lesson:.1.sig',
        'bingol-lesson: 42.1.sig',
        'bingol-lesson:42.1.sig sig',
        'bingol-lesson:42.1.\nsig',
        'bingol-lesson:42.1.sig\tx',
        'bingol-lesson:42.1.sig/../x',
      ]) {
        expect(resolveScan(v).kind, ScanKind.invalid, reason: v);
      }
    });

    test('ders yoklama yükü diğer türleri etkilemez', () {
      expect(resolveScan('bingol-clubjoin:7.1.sig').kind, ScanKind.clubJoin);
      expect(resolveScan('bingol-checkin:12.345.abc').kind, ScanKind.checkin);
      expect(resolveScan('https://bukampus.com.tr/s/u/7', selfId: 1).kind, ScanKind.profile);
      expect(resolveScan('https://bukampus.com.tr/s/c/5').kind, ScanKind.content);
    });

    test('yabancı alan adı / şema / şüpheli / uzun / boş: geçersiz', () {
      for (final v in [
        'https://evil.com/s/c/5',
        'https://bukampus.com.tr.evil.com/s/c/5',
        'https://user:pw@bukampus.com.tr/s/c/5',
        'http://192.168.0.1/x',
        'javascript:alert(1)',
        'tel:+905555555555',
        'WIFI:S:x;T:WPA;P:y;;',
        'bingol-checkin:abc.def',
        'bingol-checkin:12',
        'bingol-checkin:12.x y',
        'https://bukampus.com.tr/s/c/5 \n rm -rf',
        'merhaba',
        '',
        ' ',
        'https://bukampus.com.tr/s/c/${'1' * 400}',
      ]) {
        expect(resolveScan(v).kind, ScanKind.invalid, reason: v);
      }
      expect(resolveScan(null).valid, isFalse);
    });

    test('kulüp/anket bağlantısı biçimi ve ayrıştırma', () {
      expect(const ShareTarget(ShareType.club, 5).url, 'https://bukampus.com.tr/s/c/5');
      expect(const ShareTarget(ShareType.poll, 6).url, 'https://bukampus.com.tr/s/o/6');
      expect(ShareType.fromApi('CLUB'), ShareType.club);
      expect(ShareType.fromApi('POLL'), ShareType.poll);
    });
  });
}
