import 'dart:io';

import 'package:bu_kampus/features/widgets/widget_snapshots.dart';
import 'package:flutter_test/flutter_test.dart';

/// Android yapilandirma ekrani (QuickSelection.kt) ile Dart kisayol katalogu ayni 8 kimlik ve sirayi tasir;
/// yapilandirma metinleri 3 dilde eksiksizdir. Calisma dizini: mobile/.
void main() {
  final kt = File('android/app/src/main/kotlin/edu/bingol/bu_kampus/widgets/QuickSelection.kt').readAsStringSync();

  test('Kotlin ALL_IDS = kQuickAccessCatalog', () {
    final m = RegExp(r'ALL_IDS = listOf\(([^)]*)\)').firstMatch(kt)!;
    final ids = RegExp(r'"(\w+)"').allMatches(m[1]!).map((e) => e[1]!).toList();
    expect(ids, [for (final c in kQuickAccessCatalog) c.id]);
  });

  test('yapilandirma metinleri tr/en/ar tam', () {
    final keys = {
      for (final c in kQuickAccessCatalog) 'bw_qa_${c.id == 'timetable' ? 'timetable' : c.id}',
      'bw_qa_cfg_title', 'bw_qa_cfg_hint', 'bw_qa_cfg_save', 'bw_qa_cfg_min', 'bw_qa_cfg_up', 'bw_qa_cfg_down',
    };
    for (final dir in ['values', 'values-en', 'values-ar']) {
      final x = File('android/app/src/main/res/$dir/widget_config_strings.xml').readAsStringSync();
      for (final k in keys) {
        expect(x.contains('name="$k"'), isTrue, reason: '$dir $k');
      }
    }
  });
}
