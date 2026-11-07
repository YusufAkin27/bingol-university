// Yaptırım kuyrukları (itiraz, askı önerisi, ihlal, gizli içerik) için saf yardımcılar: kuyruk yaşı, öncelik, toplu işlem.
// Hiçbiri React'e ya da ağa bağlı değildir; testleri queueLogic.test.ts içindedir.

export const HOUR_MS = 3_600_000;
export const DAY_MS = 24 * HOUR_MS;

/** Kuyruk yaşı kovaları: sırayla "taze", "yakın", "yaşlanıyor", "bayat". */
export type AgeBucketId = 'fresh' | 'recent' | 'aging' | 'stale';
export type Urgency = 'urgent' | 'attention' | 'normal';

export const AGE_BUCKETS: ReadonlyArray<{ id: AgeBucketId; maxMs: number }> = [
  { id: 'fresh', maxMs: DAY_MS },
  { id: 'recent', maxMs: 3 * DAY_MS },
  { id: 'aging', maxMs: 7 * DAY_MS },
  { id: 'stale', maxMs: Number.POSITIVE_INFINITY },
];

/** 7 günü geçen bekleme acil, 3 günü geçen dikkat gerektirir. */
export const URGENT_AGE_MS = 7 * DAY_MS;
export const ATTENTION_AGE_MS = 3 * DAY_MS;

/** Askı önerisinde ihlal sayısına göre öncelik eşikleri. */
export const URGENT_STRIKES = 5;
export const ATTENTION_STRIKES = 3;

/** Kayıttan bu yana geçen süre (ms); geçersiz tarih null, gelecek tarih 0. */
export function ageMs(iso: string | null | undefined, now: number): number | null {
  if (!iso) return null;
  const at = new Date(iso).getTime();
  if (Number.isNaN(at)) return null;
  return Math.max(0, now - at);
}

export function bucketOf(ms: number): AgeBucketId {
  for (const b of AGE_BUCKETS) if (ms < b.maxMs) return b.id;
  return 'stale';
}

/** Tarih listesinden 4 kovalı yaş dağılımı; kova sırası sabittir, boş kovalar 0 ile döner. */
export function ageHistogram(dates: ReadonlyArray<string | null | undefined>, now: number): Array<{ id: AgeBucketId; count: number }> {
  const counts: Record<AgeBucketId, number> = { fresh: 0, recent: 0, aging: 0, stale: 0 };
  for (const d of dates) {
    const ms = ageMs(d, now);
    if (ms !== null) counts[bucketOf(ms)] += 1;
  }
  return AGE_BUCKETS.map((b) => ({ id: b.id, count: counts[b.id] }));
}

export function urgencyOfAge(ms: number | null): Urgency {
  if (ms === null) return 'normal';
  if (ms >= URGENT_AGE_MS) return 'urgent';
  if (ms >= ATTENTION_AGE_MS) return 'attention';
  return 'normal';
}

export function urgencyOfStrikes(count: number): Urgency {
  if (count >= URGENT_STRIKES) return 'urgent';
  if (count >= ATTENTION_STRIKES) return 'attention';
  return 'normal';
}

const RANK: Record<Urgency, number> = { urgent: 2, attention: 1, normal: 0 };

export const urgencyRank = (u: Urgency): number => RANK[u];

export function maxUrgency(a: Urgency, b: Urgency): Urgency {
  return RANK[a] >= RANK[b] ? a : b;
}

/** En eski kaydın bekleme süresi (ms); kayıt yoksa null. */
export function oldestAgeMs(dates: ReadonlyArray<string | null | undefined>, now: number): number | null {
  let max: number | null = null;
  for (const d of dates) {
    const ms = ageMs(d, now);
    if (ms !== null && (max === null || ms > max)) max = ms;
  }
  return max;
}

/** Acil sayılan (7 gün ve üstü) kayıt sayısı. */
export function countUrgentByAge(dates: ReadonlyArray<string | null | undefined>, now: number): number {
  return dates.reduce<number>((n, d) => n + (urgencyOfAge(ageMs(d, now)) === 'urgent' ? 1 : 0), 0);
}

export interface PriorityKey {
  urgency: Urgency;
  /** Aynı aciliyette büyük olan önce (örn. ihlal sayısı). */
  weight: number;
  createdAt: string;
}

/** Önce acil, sonra ağırlık, sonra EN ESKİ olan üstte. Girdiyi değiştirmez. */
export function sortByPriority<T>(items: readonly T[], key: (item: T) => PriorityKey): T[] {
  return [...items].sort((a, b) => {
    const ka = key(a);
    const kb = key(b);
    if (RANK[kb.urgency] !== RANK[ka.urgency]) return RANK[kb.urgency] - RANK[ka.urgency];
    if (kb.weight !== ka.weight) return kb.weight - ka.weight;
    return ka.createdAt < kb.createdAt ? -1 : ka.createdAt > kb.createdAt ? 1 : 0;
  });
}

export interface QueueFetchResult<T> {
  items: T[];
  /** Sınıra rağmen daha fazla kayıt var (kesin toplam bilinmiyor). */
  truncated: boolean;
}

/**
 * İmleç sayfalı kuyruğu en çok `maxPages` sayfa boyunca art arda okur. Böylece liste ve yaş grafiği kuyruğun
 * gerçek eski ucunu görür; çok uzun kuyrukta sessizce kesmez, `truncated` ile bildirir.
 */
export async function fetchQueue<T, C>(
  fetchPage: (cursor: C | null) => Promise<{ items: T[]; nextCursor?: C | null }>,
  maxPages = 4,
): Promise<QueueFetchResult<T>> {
  const items: T[] = [];
  let cursor: C | null = null;
  for (let i = 0; i < maxPages; i++) {
    const page = await fetchPage(cursor);
    items.push(...page.items);
    const next = page.nextCursor ?? null;
    if (next === null || page.items.length === 0) return { items, truncated: false };
    cursor = next;
  }
  return { items, truncated: true };
}

export interface BatchOutcome<T> {
  ok: T[];
  failed: Array<{ item: T; error: unknown }>;
  /** Hız sınırına (429) takılıp kalan kayıtlar işlenmeden bırakıldı. */
  rateLimited: boolean;
  /** İşlenmeden kalanlar (hız sınırı nedeniyle). */
  skipped: T[];
}

const isRateLimit = (e: unknown): boolean => (e as { status?: number } | null)?.status === 429;

/**
 * Seçili kayıtlara tek tek istek atar (toplu uç yok). Sınırlı eşzamanlılık; 429 gelince yeni istek BAŞLATMAZ,
 * bekleyenleri `skipped` olarak döndürür ki yönetici ne kaldığını bilsin. Hiçbir hata dışarı sızmaz.
 */
export async function runBatch<T>(
  items: readonly T[],
  fn: (item: T) => Promise<unknown>,
  concurrency = 3,
): Promise<BatchOutcome<T>> {
  const out: BatchOutcome<T> = { ok: [], failed: [], rateLimited: false, skipped: [] };
  let next = 0;
  async function worker() {
    for (;;) {
      if (out.rateLimited) return;
      const i = next++;
      if (i >= items.length) return;
      const item = items[i];
      try {
        await fn(item);
        out.ok.push(item);
      } catch (error) {
        if (isRateLimit(error)) {
          out.rateLimited = true;
          out.skipped.push(item);
        } else {
          out.failed.push({ item, error });
        }
      }
    }
  }
  await Promise.all(Array.from({ length: Math.min(concurrency, Math.max(1, items.length)) }, worker));
  // 429 sonrası hiç denenmemiş kalanları da bildir
  while (next < items.length) out.skipped.push(items[next++]);
  return out;
}

/** Klavye kısayolu yoksayılacak mı: yazı alanında, açık pencere içinde ya da değiştirici tuşla basıldıysa. */
export function shouldIgnoreShortcut(e: Pick<KeyboardEvent, 'target' | 'ctrlKey' | 'metaKey' | 'altKey'>): boolean {
  if (e.ctrlKey || e.metaKey || e.altKey) return true;
  const el = e.target as HTMLElement | null;
  if (el && typeof el.tagName === 'string') {
    const tag = el.tagName.toLowerCase();
    // Onay kutusu/düğme odakta iken de kısayollar çalışmalı (satırı işaretledikten sonra J/K sürmeli)
    const type = (el as HTMLInputElement).type;
    const nonText = tag === 'input' && ['checkbox', 'radio', 'button', 'submit', 'reset'].includes(type);
    if (!nonText && (tag === 'input' || tag === 'textarea' || tag === 'select' || el.isContentEditable)) return true;
  }
  if (typeof document !== 'undefined' && document.querySelector('[role="dialog"], [aria-modal="true"]')) return true;
  return false;
}

/** Etkin sırayı sınır içinde tutar. */
export function clampIndex(i: number, length: number): number {
  if (length <= 0) return -1;
  return Math.min(length - 1, Math.max(0, i));
}

/**
 * Son `days` günün (24 saatlik kayan pencereler) kayıt sayıları, eskiden yeniye. Pencerenin dışındakiler sayılmaz.
 * Takvim günü değil kayan pencere: saat dilimi kaymasından etkilenmez, "son 7 gün" cümlesiyle birebir uyar.
 */
export function dailyCounts(dates: ReadonlyArray<string | null | undefined>, now: number, days: number): number[] {
  const out = Array.from({ length: days }, () => 0);
  for (const d of dates) {
    const ms = ageMs(d, now);
    if (ms === null) continue;
    const i = Math.floor(ms / DAY_MS);
    if (i < days) out[days - 1 - i] += 1;
  }
  return out;
}

/** Son 7 pencere toplamı ile ondan önceki 7 pencere toplamı (en az 14 değer beklenir). */
export function weekOverWeek(daily: readonly number[]): { current: number; previous: number } {
  const cur = daily.slice(-7).reduce((a, b) => a + b, 0);
  const prev = daily.slice(-14, -7).reduce((a, b) => a + b, 0);
  return { current: cur, previous: prev };
}
