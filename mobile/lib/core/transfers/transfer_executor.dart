import '../api.dart' show ApiError;
import 'transfer_job.dart';

/// Çalıştırıcının kuyruğa bildirdiği hata. [retryable] true ise kuyruk üstel geri çekilmeyle yeniden dener;
/// false ise (sunucu açıkça reddetti: 4xx) iş "Hata" olur ve kullanıcı "Yeniden dene" der (yeni Idempotency-Key ile).
class TransferFailure implements Exception {
  const TransferFailure(this.code, {this.retryable = true, this.network = false, this.message = ''});

  final String code;
  final bool retryable;

  /// Bağlantı yok / zaman aşımı: iş "Bağlantı bekleniyor" durumuna girer.
  final bool network;
  final String message;

  /// [ApiError] -> sınıflandırma: 0/408 ağ, 429/5xx geçici, diğer 4xx kalıcı.
  factory TransferFailure.fromError(Object e) {
    if (e is TransferFailure) return e;
    if (e is ApiError) {
      final s = e.status;
      if (s == 0 || s == 408) return TransferFailure(e.code, network: true, message: e.message);
      if (s == 429 || s >= 500) return TransferFailure(e.code, message: e.message);
      return TransferFailure(e.code, retryable: false, message: e.message);
    }
    return TransferFailure('UNKNOWN', message: e.toString());
  }

  @override
  String toString() => 'TransferFailure($code, retryable=$retryable, network=$network)';
}

/// Çalıştırıcıya verilen bağlam: ilerleme bildirimi, iptal sorgusu, sunucu aşaması işaretleri.
abstract class TransferRunContext {
  /// Kullanıcı iptal etti ya da hesap çıkışı: çalıştırıcı en kısa sürede bırakmalı.
  bool get canceled;

  /// Ölçülen aktarılan bayt (gönderilen/inen); [total] bilinmiyorsa null (yüzde uydurulmaz).
  void progress(int done, [int? total]);

  /// Dosya sunucuya ulaştı, sunucu işliyor / yayımlıyor (bayt ilerlemesi artık yok).
  void markProcessing();

  /// Yükleme aşamasının sunucu kimliği (örn. sohbet ek id'si). Kalıcıdır: yeniden denemede yükleme atlanabilir.
  void setServerRef(String ref);
}

/// Bir iş türünün gerçek yürütücüsü (G2 gönderi, G4 sohbet bu arayüzü uygular). Testte sahte yürütücü kullanılır.
abstract class TransferExecutor {
  /// Yükleme + sunucu tamamlama. DÖNÜŞ yalnız SUNUCU yayımlandığını doğruladıysa olur; [publishedRef] sunucu kimliği.
  /// Hata: [TransferFailure] (ya da ApiError; kuyruk sınıflandırır) fırlatır. [ctx.canceled] true ise [TransferFailure]('CANCELED') fırlatın.
  Future<String> run(TransferJob job, TransferRunContext ctx);

  /// İptal/hesap çıkışı: yayımlanmamış sunucu kalıntısını sil (örn. gönderilmemiş sohbet eki). Hata sızdırmaz.
  Future<void> discard(TransferJob job) async {}
}
