// Anket grafiklerinin veri dönüşümleri (saf işlevler, testlidir). Gizli oy: yalnız toplamlar kullanılır, kimlik yoktur.
import type { AdminPollStats, PollDetail, PollScope } from '../../../api/adminPolls';
import type { ShareSegment } from './StackedShare';

export const POLL_SCOPES: PollScope[] = ['GLOBAL', 'COMMUNITY', 'MENU'];

/** Anket durumu payı: açık / kapalı / taslak / iptal. */
export function pollStateSegments(
  s: Pick<AdminPollStats, 'open' | 'closed' | 'draft' | 'cancelled'>,
  label: (k: 'open' | 'closed' | 'draft' | 'cancelled') => string,
): ShareSegment[] {
  return [
    { key: 'open', label: label('open'), value: s.open, tone: 'success' },
    { key: 'closed', label: label('closed'), value: s.closed, tone: 'neutral' },
    { key: 'draft', label: label('draft'), value: s.draft, tone: 'warning' },
    { key: 'cancelled', label: label('cancelled'), value: s.cancelled, tone: 'danger' },
  ];
}

export interface OptionShare {
  id: number;
  name: string;
  count: number;
  percent: number;
}

/** Seçenekler + sunucu sonuçları → sıralı oy payları. Sonucu olmayan seçenek 0 oy sayılır. */
export function optionShares(poll: Pick<PollDetail, 'options' | 'results' | 'type'>, starLabel: (n: number) => string): OptionShare[] {
  const byId = new Map((poll.results ?? []).map((r) => [r.optionId, r]));
  return poll.options.map((o) => {
    const r = byId.get(o.id);
    return {
      id: o.id,
      name: poll.type === 'RATING' ? starLabel(o.position) : o.text,
      count: r?.count ?? 0,
      percent: r?.percent ?? 0,
    };
  });
}

/** En çok oyu alan seçenek(ler). Hiç oy yoksa boş dizi; beraberlikte hepsi döner. */
export function leaders(shares: OptionShare[]): OptionShare[] {
  const max = Math.max(0, ...shares.map((s) => s.count));
  return max > 0 ? shares.filter((s) => s.count === max) : [];
}

/** Puanlamada ortalama (sunucu `average` vermezse oy sayısından hesaplanır; yıldız = seçenek sırası). */
export function ratingAverage(poll: Pick<PollDetail, 'average' | 'options' | 'results'>): number | null {
  if (poll.average != null && Number.isFinite(poll.average)) return poll.average;
  const byId = new Map((poll.results ?? []).map((r) => [r.optionId, r.count]));
  let n = 0;
  let sum = 0;
  for (const o of poll.options) {
    const c = byId.get(o.id) ?? 0;
    n += c;
    sum += c * o.position;
  }
  return n > 0 ? sum / n : null;
}
