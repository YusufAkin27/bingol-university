// Kullanım sekmesi saf dönüşümleri (React'siz, testli): süre biçimi, ısı haritası, akış ve CSV.
import type {
  UsageFeatures,
  UsageFlow,
  UsageHourly,
  UsageSegments,
  UsageTopActions,
  UsageTopScreens,
} from '../../../../api/usage';

/** 75 sn → "1 dk 15 sn"; 8 sn → "8 sn"; null/negatif → null (veri yok). */
export function formatSeconds(sec: number | null | undefined): string | null {
  if (sec === null || sec === undefined || !Number.isFinite(sec) || sec < 0) return null;
  const s = Math.round(sec);
  if (s < 60) return `${s} sn`;
  const m = Math.floor(s / 60);
  const r = s % 60;
  if (m < 60) return r === 0 ? `${m} dk` : `${m} dk ${r} sn`;
  const h = Math.floor(m / 60);
  return `${h} sa ${m % 60} dk`;
}

/** ISO hafta günü (1=Pazartesi) → kısa Türkçe ad. */
export const DOW_LABELS = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'] as const;
export const DOW_LONG = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'] as const;

export interface HeatCell {
  dow: number;
  hour: number;
  sessions: number;
  views: number;
  /** 0-4: renk basamağı (0 = boş). */
  level: 0 | 1 | 2 | 3 | 4;
}

/** 7×24 ızgara (satır = gün, sütun = saat); eksik hücre 0. Basamak, en yoğun hücreye oranla 5'e bölünür. */
export function heatGrid(h: UsageHourly | undefined, metric: 'sessions' | 'views' = 'sessions'): HeatCell[][] {
  const map = new Map<string, { sessions: number; views: number }>();
  for (const c of h?.cells ?? []) map.set(`${c.dow}-${c.hour}`, { sessions: c.sessions, views: c.views });
  const max = Math.max(0, ...[...map.values()].map((v) => v[metric]));
  return Array.from({ length: 7 }, (_, d) =>
    Array.from({ length: 24 }, (_, hr) => {
      const v = map.get(`${d + 1}-${hr}`) ?? { sessions: 0, views: 0 };
      const x = v[metric];
      const ratio = max > 0 ? x / max : 0;
      const level = x <= 0 ? 0 : ratio > 0.75 ? 4 : ratio > 0.5 ? 3 : ratio > 0.25 ? 2 : 1;
      return { dow: d + 1, hour: hr, sessions: v.sessions, views: v.views, level: level as HeatCell['level'] };
    }),
  );
}

export interface FlowRow {
  from: string;
  to: string;
  count: number;
  /** En kalabalık geçişe göre 0-100. */
  widthPercent: number;
  /** Tüm geçişlerdeki payı (yüzde, tek ondalık). */
  sharePercent: number;
}

export function flowRows(f: UsageFlow | undefined): FlowRow[] {
  const edges = f?.edges ?? [];
  const max = Math.max(1, ...edges.map((e) => e.count));
  const total = f?.totalTransitions ?? 0;
  return edges.map((e) => ({
    from: e.from,
    to: e.to,
    count: e.count,
    widthPercent: Math.round((e.count / max) * 100),
    sharePercent: total > 0 ? Math.round((e.count * 1000) / total) / 10 : 0,
  }));
}

/** 'other' ve 'unknown' hep sonda; diğerleri değerine göre azalan. */
export function orderSegments<T extends { key: string; userDays: number }>(items: T[]): T[] {
  const tail = new Set(['other', 'unknown']);
  const head = items.filter((i) => !tail.has(i.key)).sort((a, b) => b.userDays - a.userDays);
  const rest = items.filter((i) => tail.has(i.key)).sort((a, b) => Number(a.key === 'other') - Number(b.key === 'other'));
  return [...head, ...rest];
}

// ---------- CSV ----------

/**
 * CSV hücresi: tırnak/virgül/satır sonu içerenler çift tırnağa alınır; '=', '+', '-', '@', sekme ya da CR ile
 * BAŞLAYAN değerlerin başına tek tırnak konur (CSV/formül enjeksiyonu; sunucu tarafı kuralıyla aynı). Sayılar dokunulmaz.
 */
export function csvCell(v: string | number | null | undefined): string {
  if (v === null || v === undefined) return '';
  if (typeof v === 'number') return Number.isFinite(v) ? String(v) : '';
  let s = v;
  if (/^[=+\-@\t\r]/.test(s)) s = `'${s}`;
  return /[",\r\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

export type CsvRow = (string | number | null | undefined)[];

export function toCsv(rows: CsvRow[]): string {
  return rows.map((r) => r.map(csvCell).join(',')).join('\r\n');
}

export interface UsageExportInput {
  screens?: UsageTopScreens;
  actions?: UsageTopActions;
  flow?: UsageFlow;
  hourly?: UsageHourly;
  segments?: UsageSegments;
  features?: UsageFeatures;
  screenLabel: (key: string) => string;
  actionLabel: (key: string) => string;
  featureLabel: (key: string) => string;
}

/** Uzun biçim: bölüm, öğe, ölçü, değer. Tek dosyada tüm raporlar; kimlik/kişi bilgisi yoktur. */
export function usageCsvRows(x: UsageExportInput): CsvRow[] {
  const rows: CsvRow[] = [['bolum', 'oge', 'olcu', 'deger']];
  for (const s of x.screens?.items ?? []) {
    const l = x.screenLabel(s.screen);
    rows.push(['ekran', l, 'goruntuleme', s.views], ['ekran', l, 'kullanici_gun', s.userDays]);
    rows.push(['ekran', l, 'ort_sure_sn', s.avgSeconds], ['ekran', l, 'medyan_sure_sn', s.medianSeconds]);
    rows.push(['ekran', l, 'cikis_yuzde', s.exitPercent]);
  }
  for (const a of x.actions?.items ?? []) {
    const l = x.actionLabel(a.action);
    rows.push(['eylem', l, 'sayi', a.count], ['eylem', l, 'kullanici_gun', a.userDays]);
    rows.push(['eylem', l, 'benimseme_yuzde', a.adoptionPercent]);
  }
  for (const e of x.flow?.edges ?? []) {
    rows.push(['akis', `${x.screenLabel(e.from)} > ${x.screenLabel(e.to)}`, 'gecis', e.count]);
  }
  for (const c of x.hourly?.cells ?? []) {
    if (c.sessions === 0 && c.views === 0) continue;
    const l = `${DOW_LABELS[c.dow - 1] ?? c.dow} ${String(c.hour).padStart(2, '0')}:00`;
    rows.push(['saat', l, 'oturum', c.sessions], ['saat', l, 'goruntuleme', c.views]);
  }
  const seg = (kind: string, items: { key: string; userDays: number; percent: number }[] | undefined) => {
    for (const i of items ?? []) rows.push([kind, i.key, 'kullanici_gun', i.userDays], [kind, i.key, 'yuzde', i.percent]);
  };
  seg('platform', x.segments?.platforms);
  seg('surum', x.segments?.versions);
  seg('fakulte', x.segments?.faculties);
  seg('bolum', x.segments?.departments);
  for (const f of x.features?.items ?? []) {
    const l = x.featureLabel(f.feature);
    rows.push(['ozellik', l, 'kullanici_30gun', f.users], ['ozellik', l, 'mau_yuzde', f.percentOfMau]);
  }
  return rows;
}

/** Hiç veri yok mu (CSV düğmesi pasif, boş durum gösterilir). */
export function isEmptyUsage(x: Pick<UsageExportInput, 'screens' | 'actions' | 'flow' | 'hourly'>): boolean {
  return (
    (x.screens?.items.length ?? 0) === 0 &&
    (x.actions?.items.length ?? 0) === 0 &&
    (x.flow?.edges.length ?? 0) === 0 &&
    (x.hourly?.totalSessions ?? 0) === 0
  );
}
