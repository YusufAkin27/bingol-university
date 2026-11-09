import 'package:bu_kampus/core/push/push_targets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Gunun menusu push'u (sunucu: target=MEAL, value=tarih, mealDate, totalKcal): dokunus Yemek hedefine gider.
void main() {
  test('gunun menusu yuku Yemek hedefine cozulur', () {
    final payload = {
      'type': 'ANNOUNCEMENT',
      'subtype': 'MEAL_MENU',
      'target': 'MEAL',
      'value': '2026-11-09',
      'targetType': 'MEAL',
      'targetId': '2026-11-09',
      'mealDate': '2026-11-09',
      'totalKcal': '950',
      'style': 'MEAL',
    };
    expect(resolvePushTarget(payload).dest, PushDest.meal);
  });

  test('yalniz targetType MENU de Yemek hedefidir', () {
    expect(resolvePushTarget({"targetType": "MENU"}).dest, PushDest.meal);
  });
}
