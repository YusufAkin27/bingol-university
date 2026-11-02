import '../../api.dart' show ApiError;
import 'rich_actions.dart';
import 'rich_card.dart';

/// Bildirim eylemini yürüten saf iş akışı: ağ çağrısı ve bildirim işlemleri DIŞARIDAN verilir (arka plan isolate'inde de,
/// ana isolate'te de, testte de aynı kod çalışır).
enum RichOutcome {
  /// İstek başarılı: bildirim kaldırıldı.
  done,

  /// İstek atılamadı/başarısız: bildirim yerine "Gönderilemedi, uygulamada tekrar deneyin" gösterildi.
  failed,

  /// Uygulamayı açmak gerekir ([RichRunResult.openData] `PushRouter.open` yüküdür).
  open,

  /// Bilinmeyen eylem ya da eksik veri: hiçbir şey yapılmadı (bildirim kalır).
  ignored,
}

class RichRunResult {
  const RichRunResult(this.outcome, [this.openData]);

  final RichOutcome outcome;
  final Map<String, dynamic>? openData;

  @override
  String toString() => 'RichRunResult($outcome${openData == null ? '' : ', $openData'})';
}

/// `ApiClient.get/post/put/delete` sarmalayıcısı (yol `/api` öneksiz).
typedef RichExec = Future<dynamic> Function(String method, String path, Object? body);

class RichActionRunner {
  RichActionRunner({
    required this.exec,
    required this.remove,
    required this.fail,
    required this.confirm,
  });

  /// Oturum yoksa null: arka plan eylemleri "gönderilemedi" ile biter.
  final RichExec? exec;
  final Future<void> Function(RichCard card) remove;
  final Future<void> Function(RichCard card) fail;

  /// `not_me` başarısında (oturumlar kapandı) bilgi bildirimi.
  final Future<void> Function(RichCard card) confirm;

  Future<RichRunResult> run(String actionId, Map<String, dynamic> data, {String? input, String? clientId}) async {
    if (!kRichActionIds.contains(actionId)) return const RichRunResult(RichOutcome.ignored);
    final card = RichCard.tryParse(data);
    final plan = planRichAction(actionId, data, input: input, clientId: clientId);
    switch (plan) {
      case NoopPlan():
        return const RichRunResult(RichOutcome.ignored);
      case OpenPlan(:final data):
        return RichRunResult(RichOutcome.open, data);
      case HttpPlan():
        final call = exec;
        if (call == null) {
          if (card != null) await _safe(() => fail(card));
          return const RichRunResult(RichOutcome.failed);
        }
        try {
          await call(plan.method, plan.path, plan.body);
        } on ApiError {
          if (card != null) await _safe(() => fail(card));
          return const RichRunResult(RichOutcome.failed);
        } catch (_) {
          if (card != null) await _safe(() => fail(card));
          return const RichRunResult(RichOutcome.failed);
        }
        if (card != null) {
          await _safe(() => remove(card));
          if (plan.confirmation) await _safe(() => confirm(card));
        }
        return const RichRunResult(RichOutcome.done);
    }
  }

  Future<void> _safe(Future<void> Function() f) async {
    try {
      await f();
    } catch (_) {}
  }
}
