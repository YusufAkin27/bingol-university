import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// JSON Schema alt kumesi dogrulayici (type, required, properties, items, enum, const, pattern, minimum/maximum,
/// maxItems, allOf, $ref #/$defs/...). Ek alanlar serbest. Yalniz bu sozlesme icin; genel amacli degildir.
List<String> validate(Object? v, Map<String, dynamic> s, Map<String, dynamic> defs, String path) {
  final errs = <String>[];
  if (s.containsKey(r'$ref')) {
    final name = (s[r'$ref'] as String).split('/').last;
    return validate(v, defs[name] as Map<String, dynamic>, defs, path);
  }
  for (final sub in (s['allOf'] as List? ?? const [])) {
    errs.addAll(validate(v, sub as Map<String, dynamic>, defs, path));
  }
  if (s.containsKey('const') && v != s['const']) errs.add('$path: const ${s['const']} bekleniyordu, $v');
  if (s.containsKey('enum') && !(s['enum'] as List).contains(v)) errs.add('$path: enum disi $v');
  if (s.containsKey('type')) {
    final types = s['type'] is List ? (s['type'] as List).cast<String>() : [s['type'] as String];
    bool ok(String t) => switch (t) {
          'string' => v is String,
          'integer' => v is int,
          'number' => v is num,
          'boolean' => v is bool,
          'null' => v == null,
          'array' => v is List,
          'object' => v is Map,
          _ => false,
        };
    if (!types.any(ok)) {
      errs.add('$path: tip ${types.join('|')} bekleniyordu, ${v.runtimeType}');
      return errs;
    }
  }
  if (v is String && s['pattern'] != null && !RegExp(s['pattern'] as String).hasMatch(v)) errs.add('$path: desen uymuyor "$v"');
  if (v is num) {
    if (s['minimum'] != null && v < (s['minimum'] as num)) errs.add('$path: < minimum');
    if (s['maximum'] != null && v > (s['maximum'] as num)) errs.add('$path: > maximum');
  }
  if (v is List) {
    if (s['maxItems'] != null && v.length > (s['maxItems'] as int)) errs.add('$path: en cok ${s['maxItems']} oge');
    if (s['items'] != null) {
      for (var i = 0; i < v.length; i++) {
        errs.addAll(validate(v[i], s['items'] as Map<String, dynamic>, defs, '$path[$i]'));
      }
    }
  }
  if (v is Map) {
    for (final r in (s['required'] as List? ?? const [])) {
      if (!v.containsKey(r)) errs.add('$path: zorunlu alan yok "$r"');
    }
    final props = (s['properties'] as Map<String, dynamic>?) ?? const {};
    for (final e in props.entries) {
      if (v.containsKey(e.key)) errs.addAll(validate(v[e.key], e.value as Map<String, dynamic>, defs, '$path.${e.key}'));
    }
    final ap = s['additionalProperties'];
    if (ap is Map<String, dynamic>) {
      for (final e in v.entries) {
        if (!props.containsKey(e.key)) errs.addAll(validate(e.value, ap, defs, '$path.${e.key}'));
      }
    }
  }
  return errs;
}

void main() {
  final root = Directory('../design/widget-previews');
  final schemaFile = File('${root.path}/schemas/widget-snapshots.schema.json');
  final defs = (jsonDecode(schemaFile.readAsStringSync()) as Map<String, dynamic>)[r'$defs'] as Map<String, dynamic>;
  final examples = Directory('${root.path}/examples').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.json')).toList();

  test('ornek dosyalar var (3 dil x 9 + bos durum + oturumsuz)', () {
    expect(examples.length, greaterThanOrEqualTo(34));
  });

  for (final f in examples) {
    final rel = f.path.replaceAll('\\', '/').split('/examples/').last;
    test('sema: $rel', () {
      final json = jsonDecode(f.readAsStringSync());
      final name = rel.split('/').last.replaceAll('.json', '');
      final String def;
      if (name.startsWith('meta')) {
        def = 'meta';
      } else if (rel.contains('signed-out/')) {
        def = 'envelope';
      } else {
        def = name;
      }
      final errs = validate(json, defs[def] as Map<String, dynamic>, defs, rel);
      expect(errs, isEmpty, reason: errs.join('\n'));
      if (json is Map && json.containsKey('slug')) {
        expect(json['slug'], name.replaceAll('empty/', ''), reason: 'slug dosya adiyla ayni');
        expect(json['lang'], rel.split('/').first, reason: 'dil klasorle ayni');
        if (rel.contains('empty/')) expect(json['state'], 'empty');
      }
    });
  }

  test('ornekte RTL yalniz Arapca', () {
    for (final f in examples) {
      final rel = f.path.replaceAll('\\', '/').split('/examples/').last;
      final json = jsonDecode(f.readAsStringSync());
      if (json is Map && json.containsKey('rtl')) expect(json['rtl'], rel.startsWith('ar/'), reason: rel);
    }
  });

  test('dogrulayici bozuk veriyi yakalar (negatif kontrol)', () {
    final bad = {'schema': 2, 'slug': 'menu', 'state': 'x'};
    expect(validate(bad, defs['envelope'] as Map<String, dynamic>, defs, 'bad'), isNotEmpty);
  });
}
