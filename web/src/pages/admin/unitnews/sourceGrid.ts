// Kaynak sağlığı ızgarası için saf mantık: durum sınıflama, sıralama, özet. (Ağ ya da bileşen yok; test edilebilir.)
import type { UnitSource } from '../../../api/adminUnitNews';

export type SourceState = 'ok' | 'stale' | 'maintenance' | 'never' | 'disabled';

/** Gece çekilen kaynaklar için: son başarılı çekim bu kadar saatten eskiyse "güncel değil". */
export const NIGHTLY_STALE_HOURS = 48;
/** Yemek listesi ayda bir çekilir. */
export const MONTHLY_STALE_HOURS = 24 * 35;

export interface StateInput {
  enabled?: boolean;
  maintenance: boolean;
  lastSuccessAt: string | null;
}

export function sourceState(s: StateInput, staleHours = NIGHTLY_STALE_HOURS, now: number = Date.now()): SourceState {
  if (s.enabled === false) return 'disabled';
  if (s.maintenance) return 'maintenance';
  if (!s.lastSuccessAt) return 'never';
  const at = Date.parse(s.lastSuccessAt);
  if (Number.isNaN(at)) return 'never';
  return now - at > staleHours * 3_600_000 ? 'stale' : 'ok';
}

/** Dikkat gerektirenler üstte: bakımda, hiç çekilmemiş, eski, sorunsuz, kapalı. */
const ORDER: Record<SourceState, number> = { maintenance: 0, never: 1, stale: 2, ok: 3, disabled: 4 };

export interface GridTile {
  key: string;
  label: string;
  state: SourceState;
  lastAt: string | null;
  /** Birim kaynağıysa duyuru sayısı. */
  announcements?: number;
  /** Ana kaynak (haber/yemek) mı: birim sayfasına bağlanmaz. */
  core?: boolean;
}

export function sortTiles(tiles: GridTile[]): GridTile[] {
  return [...tiles].sort(
    (a, b) => ORDER[a.state] - ORDER[b.state] || a.label.localeCompare(b.label, 'tr'),
  );
}

export function unitTiles(units: UnitSource[], now: number = Date.now()): GridTile[] {
  return units.map((u) => ({
    key: `unit-${u.code}`,
    label: u.name,
    state: sourceState(u, NIGHTLY_STALE_HOURS, now),
    lastAt: u.lastSuccessAt,
    announcements: u.announcementCount,
  }));
}

/** Ana kaynaklar (haber/duyuru/etkinlik gece, yemek listesi ayda bir çekilir). */
export function coreTilesOf(
  news: { maintenance: boolean; lastSuccess: string | null },
  menu: { maintenance: boolean; lastSuccess: string | null },
  labels: { news: string; menu: string },
  now: number = Date.now(),
): GridTile[] {
  return [
    {
      key: 'core-news',
      label: labels.news,
      state: sourceState({ maintenance: news.maintenance, lastSuccessAt: news.lastSuccess }, NIGHTLY_STALE_HOURS, now),
      lastAt: news.lastSuccess,
      core: true,
    },
    {
      key: 'core-menu',
      label: labels.menu,
      state: sourceState({ maintenance: menu.maintenance, lastSuccessAt: menu.lastSuccess }, MONTHLY_STALE_HOURS, now),
      lastAt: menu.lastSuccess,
      core: true,
    },
  ];
}

export interface GridSummary {
  /** Kapalı olanlar hariç izlenen kaynak sayısı. */
  watched: number;
  ok: number;
  /** İlgi isteyen: bakımda, hiç çekilmemiş, güncel değil. */
  bad: number;
  disabled: number;
  counts: Record<SourceState, number>;
}

export function summarizeTiles(tiles: GridTile[]): GridSummary {
  const counts: Record<SourceState, number> = { ok: 0, stale: 0, maintenance: 0, never: 0, disabled: 0 };
  for (const t of tiles) counts[t.state] += 1;
  const bad = counts.stale + counts.maintenance + counts.never;
  return { watched: tiles.length - counts.disabled, ok: counts.ok, bad, disabled: counts.disabled, counts };
}
