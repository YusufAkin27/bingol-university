import 'package:bu_kampus/features/clubs/club_audience_picker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClubAudience (kulup oneri hedefi)', () {
    test('sunucu kulup JSON alanlarindan okunur, yoksa bos', () {
      final a = ClubAudience.fromClub({
        'targetFaculties': ['Mühendislik Fakültesi'],
        'targetDepartments': ['Bilgisayar Mühendisliği', 'Makine Mühendisliği'],
      });
      expect(a.faculties, {'Mühendislik Fakültesi'});
      expect(a.departments.length, 2);
      expect(a.count, 3);
      expect(a.isEmpty, isFalse);
      expect(ClubAudience.fromClub(null).isEmpty, isTrue);
      expect(ClubAudience.fromClub({'name': 'X'}).isEmpty, isTrue);
    });

    test('esitlik sirayi gozetmez; degisiklik algilanir (PATCH yalniz degisince gonderilir)', () {
      const a = ClubAudience(faculties: {'A', 'B'}, departments: {'D'});
      expect(a == const ClubAudience(faculties: {'B', 'A'}, departments: {'D'}), isTrue);
      expect(a == const ClubAudience(faculties: {'A'}, departments: {'D'}), isFalse);
      expect(a == const ClubAudience(), isFalse);
    });
  });
}
