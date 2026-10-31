import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';
import 'locale_controller.dart' show L10nContext;
import 'session.dart';

/// Dile göre görünen ad: Türkçe [tr] kanoniktir (DB'de saklanan/eşleştirilen değer); çeviri yoksa Türkçeye düşer.
String _pickName(String lang, String tr, String? en, String? ar) {
  final v = switch (lang) {
    'en' => en,
    'ar' => ar,
    _ => null,
  };
  return (v == null || v.trim().isEmpty) ? tr : v;
}

class AcademicDepartment {
  const AcademicDepartment(this.id, this.name, this.faculty, {this.nameEn, this.nameAr});

  final String id;

  /// Kanonik Türkçe ad (API'ye gönderilen ve DB'de tutulan değer).
  final String name;
  final String? nameEn, nameAr;
  final AcademicFaculty faculty;

  /// [lang] = `tr` / `en` / `ar`; bilinmeyen dil ve eksik çeviri Türkçeye düşer.
  String label(String lang) => _pickName(lang, name, nameEn, nameAr);
}

class AcademicFaculty {
  AcademicFaculty(this.id, this.name, {this.nameEn, this.nameAr});

  final String id;
  final String name;
  final String? nameEn, nameAr;
  final List<AcademicDepartment> departments = [];

  String label(String lang) => _pickName(lang, name, nameEn, nameAr);
}

class AcademicGrade {
  const AcademicGrade(this.id, this.name, {this.nameEn, this.nameAr});

  final String id;
  final String name;
  final String? nameEn, nameAr;

  String label(String lang) => _pickName(lang, name, nameEn, nameAr);
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
  final _facByKey = <String, AcademicFaculty>{};
  final _depByKey = <String, List<AcademicDepartment>>{};

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
      final fac = AcademicFaculty(fm['id'].toString(), fm['name'] as String,
          nameEn: fm['nameEn'] as String?, nameAr: fm['nameAr'] as String?);
      for (final d in (fm['departments'] as List? ?? const [])) {
        final dm = d as Map<String, dynamic>;
        final dep = AcademicDepartment(dm['id'].toString(), dm['name'] as String, fac,
            nameEn: dm['nameEn'] as String?, nameAr: dm['nameAr'] as String?);
        fac.departments.add(dep);
        ds.add(dep);
      }
      fs.add(fac);
    }
    final gs = <AcademicGrade>[
      for (final g in (j['grades'] as List? ?? const []))
        AcademicGrade((g as Map<String, dynamic>)['id'].toString(), g['name'] as String,
            nameEn: g['nameEn'] as String?, nameAr: g['nameAr'] as String?),
    ];
    faculties = fs;
    departments = ds;
    if (gs.isNotEmpty) grades = gs;
    _folded
      ..clear()
      ..addEntries(ds.map((d) => MapEntry(d, foldTr(d.name))));
    _facByKey
      ..clear()
      ..addEntries(fs.map((f) => MapEntry(foldTr(f.name), f)));
    _depByKey.clear();
    for (final d in ds) {
      (_depByKey[foldTr(d.name)] ??= []).add(d);
    }
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

  /// Fakülte araması: Türkçe kanonik ad ile (verilmişse) [locale] dilindeki ad birlikte aranır.
  List<AcademicFaculty> searchFaculties(String q, {Locale? locale}) {
    final k = foldTr(q);
    if (k.isEmpty) return faculties;
    final lang = locale?.languageCode ?? 'tr';
    return [
      for (final f in faculties)
        if (foldTr(f.name).contains(k) || (lang != 'tr' && foldTr(f.label(lang)).contains(k))) f
    ];
  }

  /// Bölüm araması: Türkçe kanonik ad ile (verilmişse) [locale] dilindeki ad birlikte aranır
  /// (İngilizce/Arapça arayüzde hem "Computer" hem "Bilgisayar" bulur).
  List<AcademicDepartment> searchDepartments(String q, {AcademicFaculty? faculty, Locale? locale}) {
    final k = foldTr(q);
    final src = faculty?.departments ?? departments;
    if (k.isEmpty) return src;
    final lang = locale?.languageCode ?? 'tr';
    return [
      for (final d in src)
        if ((_folded[d] ?? foldTr(d.name)).contains(k) || (lang != 'tr' && foldTr(d.label(lang)).contains(k))) d
    ];
  }

  /// Kanonik Türkçe fakülte adının [locale] dilindeki görünen adı; katalog yüklenmediyse/bulunamazsa girdi aynen döner.
  String facultyLabel(String? canonicalTr, Locale locale) {
    if (canonicalTr == null || canonicalTr.isEmpty) return '';
    if (locale.languageCode == 'tr') return canonicalTr;
    return _facByKey[foldTr(canonicalTr)]?.label(locale.languageCode) ?? canonicalTr;
  }

  /// Kanonik Türkçe bölüm adının görünen adı. Aynı ad birden çok fakültede olabilir; [faculty] (kanonik) verilirse
  /// o fakülteye öncelik verilir. Bulunamazsa girdi aynen döner.
  String departmentLabel(String? canonicalTr, Locale locale, {String? faculty}) {
    if (canonicalTr == null || canonicalTr.isEmpty) return '';
    if (locale.languageCode == 'tr') return canonicalTr;
    final list = _depByKey[foldTr(canonicalTr)];
    if (list == null || list.isEmpty) return canonicalTr;
    var pick = list.first;
    if (faculty != null && faculty.isNotEmpty) {
      final fk = foldTr(faculty);
      for (final d in list) {
        if (foldTr(d.faculty.name) == fk) {
          pick = d;
          break;
        }
      }
    }
    return pick.label(locale.languageCode);
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

/// Katalog kapsamı: uygulamanın tepesinde durur; katalog yüklenince onu kullanan görünen-ad satırları yeniden çizilir.
/// Oturum açılınca (uç herkese açık ve önbellekli) kataloğu bir kez yükler.
class AcademicCatalogScope extends StatefulWidget {
  const AcademicCatalogScope({super.key, required this.session, required this.child});

  final Session session;
  final Widget child;

  @override
  State<AcademicCatalogScope> createState() => _AcademicCatalogScopeState();
}

class _AcademicCatalogScopeState extends State<AcademicCatalogScope> {
  late final AcademicCatalog _catalog = AcademicCatalog.of(widget.session);

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_loadIfSignedIn);
    // notifyListeners yapı sırasında çağrılmasın.
    Future.microtask(_loadIfSignedIn);
  }

  /// Oturum açıkken kataloğu bir kez yükler (kayıt ekranı kendi yükler); hata olursa Türkçe kanonik metin gösterilir.
  void _loadIfSignedIn() {
    if (mounted && widget.session.state == SessionState.signedIn) _catalog.load();
  }

  @override
  void dispose() {
    widget.session.removeListener(_loadIfSignedIn);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _CatalogInherited(notifier: _catalog, child: widget.child);
}

class _CatalogInherited extends InheritedNotifier<AcademicCatalog> {
  const _CatalogInherited({required AcademicCatalog super.notifier, required super.child});
}

/// Arayüz dili (`tr`/`en`/`ar`); yerelleştirme kapsamı yoksa Türkçe (testler ve ilk kare dahil).
Locale uiLocale(BuildContext context) => Locale(context.l10n.localeName.split(RegExp('[_-]')).first);

/// Bölüm/fakülte gösteren yerlerin kullandığı bağlam yardımcıları. Kanonik değer (Türkçe) DEĞİŞMEZ; yalnız gösterim
/// dile göre çevrilir. Kapsam yoksa/katalog yüklenmediyse/ad bulunamazsa Türkçe kanonik metin döner.
extension AcademicLabels on BuildContext {
  AcademicCatalog? get _academicCatalog => dependOnInheritedWidgetOfExactType<_CatalogInherited>()?.notifier;

  /// Kanonik Türkçe fakülte adının arayüz dilindeki adı.
  String facultyName(String? canonicalTr) {
    final c = _academicCatalog;
    if (c == null) return canonicalTr ?? '';
    return c.facultyLabel(canonicalTr, uiLocale(this));
  }

  /// Kanonik Türkçe bölüm adının arayüz dilindeki adı ([faculty]: kanonik fakülte adı, isteğe bağlı).
  String departmentName(String? canonicalTr, {String? faculty}) {
    final c = _academicCatalog;
    if (c == null) return canonicalTr ?? '';
    return c.departmentLabel(canonicalTr, uiLocale(this), faculty: faculty);
  }

  /// "Bölüm yoksa fakülte" gösteren alt satırlar için: bölüm varsa bölüm adı, yoksa fakülte adı.
  String departmentOrFacultyName(String? department, String? faculty) {
    final d = department?.trim() ?? '';
    return d.isNotEmpty ? departmentName(d, faculty: faculty) : facultyName(faculty?.trim());
  }
}
