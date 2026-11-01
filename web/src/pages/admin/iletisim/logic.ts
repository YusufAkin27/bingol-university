// İletişim grubu (destek + bildirimler) için saf yardımcılar: grafik verisi dönüşümleri ve cümle kararları.
// React/DOM yok; tüm kurallar burada test edilir (logic.test.ts).
import type { ShareSegment } from '../../../components/kit/StackedShareIletisim';

const MIN = 60_000;
const HOUR = 60 * MIN;
const DAY = 24 * HOUR;

// ---------------- destek talepleri ----------------

export type AgeKey = 'lt4h' | 'lt24h' | 'lt3d' | 'gt3d';
export const AGE_KEYS: AgeKey[] = ['lt4h', 'lt24h', 'lt3d', 'gt3d'];

/** Bir bekleyen talebin yaş kovası; geçersiz tarih ya da gelecek tarih ilk kovaya düşer. */
export function ageKeyOf(iso: string, now: number = Date.now()): AgeKey {
  const at = new Date(iso).getTime();
  const diff = Number.isNaN(at) ? 0 : Math.max(0, now - at);
  if (diff < 4 * HOUR) return 'lt4h';
  if (diff < DAY) return 'lt24h';
  if (diff < 3 * DAY) return 'lt3d';
  return 'gt3d';
}

/** Bekleyen taleplerin yaş dağılımı (her kova her zaman vardır; sıra sabit: yeniden eskiye). */
export function ageBuckets(
  tickets: { updatedAt: string }[],
  now: number = Date.now(),
): { key: AgeKey; count: number }[] {
  const counts: Record<AgeKey, number> = { lt4h: 0, lt24h: 0, lt3d: 0, gt3d: 0 };
  for (const x of tickets) counts[ageKeyOf(x.updatedAt, now)] += 1;
  return AGE_KEYS.map((key) => ({ key, count: counts[key] }));
}

export interface TicketCounts {
  open: number;
  answered: number;
  closed: number;
}

export const ticketTotal = (c: TicketCounts) => c.open + c.answered + c.closed;

/** Taleplerin kaçı yanıt almış ya da kapanmış (yüzde 0-100); hiç talep yoksa null (uydurma oran yazılmaz). */
export function answeredShare(c: TicketCounts): number | null {
  const total = ticketTotal(c);
  if (total <= 0) return null;
  return Math.round(((c.answered + c.closed) / total) * 100);
}

export type Verdict = 'none' | 'good' | 'warn' | 'bad';

/** İlk yanıt süresi kararı: 1 günde iyi, 3 günde dikkat, daha uzunu kötü. */
export function firstReplyVerdict(minutes: number | null | undefined): Verdict {
  if (minutes === null || minutes === undefined || !Number.isFinite(minutes) || minutes <= 0) return 'none';
  if (minutes <= 24 * 60) return 'good';
  if (minutes <= 72 * 60) return 'warn';
  return 'bad';
}

export interface Humanized {
  unit: 'minutes' | 'hours' | 'days';
  value: number;
}

/** 95 dk -> 1,6 sa; 3000 dk -> 2,1 gün. Tek ondalık. */
export function humanizeDuration(minutes: number): Humanized {
  const r1 = (v: number) => Math.round(v * 10) / 10;
  if (minutes < 60) return { unit: 'minutes', value: Math.max(1, Math.round(minutes)) };
  if (minutes < 24 * 60) return { unit: 'hours', value: r1(minutes / 60) };
  return { unit: 'days', value: r1(minutes / (24 * 60)) };
}

/** Bekleyenler arasında 3 günden eski kaç talep var (uyarı cümlesi için). */
export const staleCount = (b: { key: AgeKey; count: number }[]) =>
  b.find((x) => x.key === 'gt3d')?.count ?? 0;

// ---------------- geri bildirim ----------------

/** Sunucudaki {key,count} listesinden belirli anahtarların sayıları (olmayan 0). */
export function countsByKey(
  list: { key: string; count: number }[] | undefined,
  keys: readonly string[],
): Record<string, number> {
  const out: Record<string, number> = {};
  for (const k of keys) out[k] = list?.find((x) => x.key === k)?.count ?? 0;
  return out;
}

// ---------------- kampanyalar ----------------

export interface ReachInput {
  status: string;
  recipientCount: number | null;
  audienceSize?: number | null;
}

/**
 * Gönderilmiş kampanyalarda hedef kitleye ulaşma oranı (yüzde 0-100): ulaşılan / hedeflenen.
 * Hedef büyüklüğü bilinmeyen kampanyalar paydaya girmez; hiç ölçülebilir kampanya yoksa null.
 */
export function reachRate(
  items: ReachInput[],
): { reached: number; audience: number; percent: number } | null {
  let reached = 0;
  let audience = 0;
  for (const c of items) {
    if (c.status !== 'SENT') continue;
    if (c.recipientCount === null || !c.audienceSize || c.audienceSize <= 0) continue;
    reached += Math.min(c.recipientCount, c.audienceSize);
    audience += c.audienceSize;
  }
  if (audience <= 0) return null;
  return { reached, audience, percent: Math.round((reached / audience) * 100) };
}

/** Durum -> parça tonu (kampanya durumları). */
export function campaignTone(status: string): ShareSegment['tone'] {
  switch (status) {
    case 'SENT':
    case 'DONE':
      return 'success';
    case 'SENDING':
      return 'info';
    case 'SCHEDULED':
    case 'PAUSED':
    case 'DRAFT':
      return 'neutral';
    case 'FAILED':
      return 'danger';
    case 'CANCELLED':
      return 'warning';
    default:
      return 'neutral';
  }
}

/** Duruma göre sayım: sıra `order` ile verilir; sayısı 0 olanlar da döner (açıklamada "0" görünsün). */
export function statusCounts(
  items: { status: string }[],
  order: readonly string[],
): { key: string; count: number }[] {
  return order.map((key) => ({ key, count: items.filter((x) => x.status === key).length }));
}

// ---------------- kuyruk sağlığı (mail ve push) ----------------

export interface QueueCounts {
  pending: number;
  failed: number;
  dead: number;
  skipped?: number;
}

export type Health = 'good' | 'warn' | 'bad';

/** Kuyruk kararı: ölü kayıt varsa kötü, başarısız/geri çekilmede bekleyen varsa dikkat, yoksa iyi. */
export function queueHealth(q: QueueCounts): Health {
  if (q.dead > 0) return 'bad';
  if (q.failed > 0) return 'warn';
  return 'good';
}

/** Kuyrukta insan müdahalesi isteyen kayıt sayısı (başarısız + ölü). */
export const queueProblems = (q: QueueCounts) => q.failed + q.dead;

/** Bekleyen en eski kaydın yaşı (dakika); tarih yoksa null. */
export function ageMinutes(iso: string | null | undefined, now: number = Date.now()): number | null {
  if (!iso) return null;
  const at = new Date(iso).getTime();
  if (Number.isNaN(at)) return null;
  return Math.max(0, Math.round((now - at) / MIN));
}

/** Teslim oranı: gönderilen / (gönderilen + başarısız + ölü), yüzde 0-100; payda 0 ise null. */
export function deliveryRate(sent: number, failed: number, dead: number): number | null {
  const denom = sent + failed + dead;
  if (denom <= 0) return null;
  return Math.round((sent / denom) * 100);
}

// ---------------- mail kampanyası ----------------

export interface MailCounters {
  target: number;
  pending: number;
  queued: number;
  skipped: number;
  failed: number;
  cancelled: number;
}

/** Mail kampanyası alıcı dağılımı: kuyruğa alınan / bekleyen / atlanan / başarısız / iptal (toplam = hedef). */
export function mailShareSegments(
  k: MailCounters,
  labels: Record<'queued' | 'pending' | 'skipped' | 'failed' | 'cancelled', string>,
): ShareSegment[] {
  return [
    { key: 'queued', label: labels.queued, value: k.queued, tone: 'success' },
    { key: 'pending', label: labels.pending, value: k.pending, tone: 'info' },
    { key: 'skipped', label: labels.skipped, value: k.skipped, tone: 'neutral' },
    { key: 'failed', label: labels.failed, value: k.failed, tone: 'danger' },
    { key: 'cancelled', label: labels.cancelled, value: k.cancelled, tone: 'warning' },
  ];
}
