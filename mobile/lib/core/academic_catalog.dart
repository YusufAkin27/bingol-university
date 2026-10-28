import 'package:flutter/foundation.dart';

import '../l10n/app_localizations.dart';
import 'session.dart';

class AcademicDepartment {
  const AcademicDepartment(this.id, this.name, this.faculty);

  final String id;
  final String name;
  final AcademicFaculty faculty;
}

class AcademicFaculty {
  AcademicFaculty(this.id, this.name);

  final String id;
  final String name;
  final List<AcademicDepartment> departments = [];
}

class AcademicGrade {
  const AcademicGrade(this.id, this.name);

  final String id;
  final String name;
}

enum CatalogState { idle, loading, ready, error }

/// Arama için aksan ve büyük/küçük harf duyarsız normalleştirme ("Mühendislik" -> "muhendislik").
String foldTr(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    switch (c) {
      case 'İ' || 'I' || 'ı' || 'î' || 'Î':
        b.write('i');
      case 'Ö' || 'ö' || 'Ô' || 'ô':
        b.write('o');
      case 'Ü' || 'ü' || 'Û' || 'û':
        b.write('u');
      case 'Ş' || 'ş':
        b.write('s');
      case 'Ç' || 'ç':
        b.write('c');
      case 'Ğ' || 'ğ':
        b.write('g');
      case 'Â' || 'â':
        b.write('a');
      default:
        b.write(c.toLowerCase());
    }
  }
  return b.toString().trim();
}

const _defaultGrades = [
  AcademicGrade('PREP', 'Hazırlık'),
  AcademicGrade('1', '1. sınıf'),
  AcademicGrade('2', '2. sınıf'),
  AcademicGrade('3', '3. sınıf'),
  AcademicGrade('4', '4. sınıf'),
  AcademicGrade('5', '5. sınıf'),
  AcademicGrade('6', '6. sınıf'),
  AcademicGrade('MASTER', 'Yüksek lisans'),
  AcademicGrade('PHD', 'Doktora'),
];

/// Sınıf kimliğinin kullanıcıya gösterilen adı (katalog yüklenmemiş olsa da çalışır).
String gradeLabel(String? id) {
  if (id == null || id.isEmpty) return '';
  for (final g in _defaultGrades) {
    if (g.id == id) return g.name;
  }
  return id;
}

/// Sınıf kimliğinin dile göre adı (PREP, 1..6, MASTER, PHD); bilinmeyen kimlik olduğu gibi döner.
String gradeLabelL(AppLocalizations l, String? id) {
  if (id == null || id.isEmpty) return '';
  return switch (id) {
    'PREP' => l.acadGradePrep,
    'MASTER' => l.acadGradeMaster,
    'PHD' => l.acadGradePhd,
    '1' || '2' || '3' || '4' || '5' || '6' => l.acadGradeN(id),
    _ => id,
  };
}

/// Fakülte/bölüm/sınıf kataloğu: oturum başına bir kez yüklenir, bellekte tutulur.
/// Kayıt öncesi (token yok) anonim çağrı çalışır.
class AcademicCatalog extends ChangeNotifier {
  AcademicCatalog(this.session);

  final Session session;

  static final _byApi = Expando<AcademicCatalog>();

  /// Oturuma bağlı tek örnek.
  static AcademicCatalog of(Session s) => _byApi[s] ??= AcademicCatalog(s);

  CatalogState state = CatalogState.idle;
  List<AcademicFaculty> faculties = const [];
  List<AcademicDepartment> departments = const [];
  List<AcademicGrade> grades = _defaultGrades;
  final _folded = <AcademicDepartment, String>{};

  bool get ready => state == CatalogState.ready;

  /// Yüklenmediyse yükler; yüklüyken/yüklenirken yeniden istek atmaz.
  Future<void> load() async {
    if (state == CatalogState.loading || state == CatalogState.ready) return;
    state = CatalogState.loading;
    notifyListeners();
    try {
      final r = await session.api.get('/catalog/academic');
      _parse(r as Map<String, dynamic>);
      state = CatalogState.ready;
    } catch (_) {
      state = CatalogState.error;
    }
    notifyListeners();
  }

  Future<void> retry() {
    if (state == CatalogState.error) state = CatalogState.idle;
    return load();
  }

  void _parse(Map<String, dynamic> j) {
    final fs = <AcademicFaculty>[];
    final ds = <AcademicDepartment>[];
    for (final f in (j['faculties'] as List? ?? const [])) {
      final fm = f as Map<String, dynamic>;
      final fac = AcademicFaculty(fm['id'].toString(), fm['name'] as String);
      for (final d in (fm['departments'] as List? ?? const [])) {
        final dm = d as Map<String, dynamic>;
        final dep = AcademicDepartment(dm['id'].toString(), dm['name'] as String, fac);
        fac.departments.add(dep);
        ds.add(dep);
      }
      fs.add(fac);
    }
    final gs = <AcademicGrade>[
      for (final g in (j['grades'] as List? ?? const []))
        AcademicGrade((g as Map<String, dynamic>)['id'].toString(), g['name'] as String),
    ];
    faculties = fs;
    departments = ds;
    if (gs.isNotEmpty) grades = gs;
    _folded
      ..clear()
      ..addEntries(ds.map((d) => MapEntry(d, foldTr(d.name))));
  }

  AcademicFaculty? facultyByName(String? name) {
    if (name == null || name.isEmpty) return null;
    final k = foldTr(name);
    for (final f in faculties) {
      if (foldTr(f.name) == k) return f;
    }
    return null;
  }

  AcademicDepartment? departmentByName(String? name, {AcademicFaculty? faculty}) {
    if (name == null || name.isEmpty) return null;
    final k = foldTr(name);
    for (final d in faculty?.departments ?? departments) {
      if (foldTr(d.name) == k) return d;
    }
    return null;
  }

  List<AcademicFaculty> searchFaculties(String q) {
    final k = foldTr(q);
    if (k.isEmpty) return faculties;
    return [for (final f in faculties) if (foldTr(f.name).contains(k)) f];
  }

  List<AcademicDepartment> searchDepartments(String q, {AcademicFaculty? faculty}) {
    final k = foldTr(q);
    final src = faculty?.departments ?? departments;
    if (k.isEmpty) return src;
    return [for (final d in src) if ((_folded[d] ?? foldTr(d.name)).contains(k)) d];
  }

  /// Adı verilen sınıf kimliğinin etiketi (katalogdaki adla).
  String gradeName(String? id) {
    for (final g in grades) {
      if (g.id == id) return g.name;
    }
    return gradeLabel(id);
  }

  /// [gradeName] ile aynı, ama adı dile göre verir (sunucu adı yerine sabit çeviri).
  String gradeNameL(AppLocalizations l, String? id) {
    final label = gradeLabelL(l, id);
    if (label != (id ?? '')) return label;
    for (final g in grades) {
      if (g.id == id) return g.name;
    }
    return label;
  }
}
