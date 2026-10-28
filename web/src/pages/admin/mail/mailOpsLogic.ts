// Mail altyapısı (P13) saf yardımcıları: bastırma kaldırma kuralları, kota uyarı düzeyi, kuyruk seçimi/toplu özet.
import type {
  BulkResult,
  OutboxRow,
  OutboxStatus,
  QuotaLevel,
  SuppressionDetail,
  SuppressionReason,
} from '../../../api/adminMailOps';
import { BULK_MAX, DEFAULT_MIN_REASON, OPT_OUT_MIN_REASON } from '../../../api/adminMailOps';
import type { Tone } from '../../../components/ui/Badge';

/** Kullanıcının kendi iradesi: abonelikten çıktı ya da şikayet etti. */
export const isUserOptOut = (r: SuppressionReason): boolean => r === 'UNSUBSCRIBED' || r === 'COMPLAINT';

export function reasonTone(r: SuppressionReason): Tone {
  switch (r) {
    case 'UNSUBSCRIBED':
      return 'info';
    case 'COMPLAINT':
      return 'danger';
    case 'BOUNCED':
      return 'warning';
    default:
      return 'neutral';
  }
}

export interface RemovalPolicy {
  /** En kısa sebep uzunluğu. */
  minReason: number;
  /** Ek onay başlığı (`X-Admin-Confirm`) + yazarak onay zorunlu mu. */
  strong: boolean;
  /** Yazdırılacak metin: tam e-posta; çözülemiyorsa özet ön eki. */
  typeTarget: string | null;
}

/** Kaldırma kuralı: sunucu `removeMinReason/removeNeedsConfirm` verir; yoksa nedene göre türetilir. */
export function removalPolicy(d: Pick<SuppressionDetail, 'reason' | 'fullEmail' | 'hashPrefix'> &
  Partial<Pick<SuppressionDetail, 'removeMinReason' | 'removeNeedsConfirm'>>): RemovalPolicy {
  const strong = d.removeNeedsConfirm ?? isUserOptOut(d.reason);
  return {
    minReason: d.removeMinReason ?? (strong ? OPT_OUT_MIN_REASON : DEFAULT_MIN_REASON),
    strong,
    typeTarget: strong ? (d.fullEmail ?? d.hashPrefix) : null,
  };
}

/** Elle ekleme formu geçerli mi: basit e-posta biçimi + not (sebep) en az 5 karakter. */
export function isSuppressionFormValid(email: string, note: string): boolean {
  const e = email.trim();
  return e.length <= 254 && /^[^\s@,;<>]+@[^\s@,;<>]+\.[^\s@,;<>]{2,}$/.test(e) && note.trim().length >= DEFAULT_MIN_REASON;
}

/** Kota kullanım yüzdesine göre düzey (sunucuyla aynı eşikler: >= 80 uyarı, >= 95 kritik; sınırsız = OFF). */
export function quotaLevel(percent: number): QuotaLevel {
  if (percent < 0) return 'OFF';
  if (percent >= 95) return 'CRITICAL';
  if (percent >= 80) return 'WARN';
  return 'OK';
}

export function quotaTone(level: QuotaLevel): Tone {
  return level === 'CRITICAL' ? 'danger' : level === 'WARN' ? 'warning' : level === 'OK' ? 'success' : 'neutral';
}

export function statusTone(s: OutboxStatus): Tone {
  switch (s) {
    case 'SENT':
      return 'success';
    case 'DEAD':
      return 'danger';
    case 'FAILED':
      return 'warning';
    case 'PENDING':
      return 'info';
    default:
      return 'neutral';
  }
}


/** Seçili satırlardan toplu işlem özeti: kaç tanesi yeniden denenebilir / iptal edilebilir. */
export function bulkEligibility(rows: OutboxRow[], selected: ReadonlySet<string | number>) {
  const picked = rows.filter((r) => selected.has(r.id));
  return {
    total: picked.length,
    retryable: picked.filter((r) => r.retryable).length,
    cancellable: picked.filter((r) => r.cancellable).length,
    overLimit: picked.length > BULK_MAX,
  };
}

/** Toplu sonuçtan sebep koduna göre sayım (kısmi başarı özeti). */
export function summarizeBulk(res: BulkResult): { code: string; count: number }[] {
  const m = new Map<string, number>();
  for (const f of res.failed) m.set(f.code, (m.get(f.code) ?? 0) + 1);
  return [...m.entries()].map(([code, count]) => ({ code, count })).sort((a, b) => b.count - a.count);
}

/** Kota çubuğu için 0-100 arası tam sayı yüzde (taşma 100'e kırpılır; sınırsız 0). */
export function barPercent(percent: number): number {
  if (percent < 0) return 0;
  return Math.max(0, Math.min(100, Math.round(percent)));
}
