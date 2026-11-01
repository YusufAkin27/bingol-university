// Sistem sağlığı sayfaları (sistem1) için saf yardımcılar: trafik ışığı, oturum geçmişi, görev şeridi, büyüme tahmini,
// çökme sürüm dağılımı, bölge ölçeği. Hepsi birim testlidir; ekranda uydurma sayı yoktur (veri yoksa null döner).
import type { CrashGroup, CrashSummary } from '../../../api/crashes';
import type { RetentionTable, StorageReport } from '../../../api/dataRetention';
import { levelOf, toUnit, type SystemIndicator, type SystemLevel } from '../../../api/system';

/** İyi / Dikkat / Acil: yöneticinin gördüğü üç kelime. */
export type Verdict = 'good' | 'attention' | 'urgent' | 'unknown';

export function verdictOf(level: SystemLevel): Verdict {
  return level === 'OK' ? 'good' : level === 'WARN' ? 'attention' : level === 'CRIT' ? 'urgent' : 'unknown';
}

/** Bir grup göstergenin en kötü düzeyi (kritik > uyarı > bilinmiyor > normal). Boş küme: UNKNOWN. */
export function worstLevel(levels: SystemLevel[]): SystemLevel {
  if (levels.length === 0) return 'UNKNOWN';
  if (levels.includes('CRIT')) return 'CRIT';
  if (levels.includes('WARN')) return 'WARN';
  if (levels.includes('UNKNOWN')) return 'UNKNOWN';
  return 'OK';
}

// ---------- Oturum geçmişi (sağlık çizelgesi) ----------
export interface HistorySample {
  at: number;
  level: SystemLevel;
}

export const HISTORY_MAX = 48;

/** Yeni ölçümü ekler; aynı anın tekrarını yutar, en eski ölçümleri atar. */
export function pushSample(history: HistorySample[], sample: HistorySample, max = HISTORY_MAX): HistorySample[] {
  if (!Number.isFinite(sample.at) || sample.at <= 0) return history;
  if (history.some((h) => h.at === sample.at)) return history;
  const next = [...history, sample].sort((a, b) => a.at - b.at);
  return next.length > max ? next.slice(next.length - max) : next;
}

export interface HistorySummary {
  total: number;
  good: number;
  attention: number;
  urgent: number;
  unknown: number;
  /** En son iyi olmayan ölçümün zamanı; hiç yoksa null. */
  lastBadAt: number | null;
}

export function summarizeHistory(history: HistorySample[]): HistorySummary {
  const s: HistorySummary = { total: history.length, good: 0, attention: 0, urgent: 0, unknown: 0, lastBadAt: null };
  for (const h of history) {
    if (h.level === 'OK') s.good += 1;
    else if (h.level === 'WARN') s.attention += 1;
    else if (h.level === 'CRIT') s.urgent += 1;
    else s.unknown += 1;
    if (h.level === 'WARN' || h.level === 'CRIT') s.lastBadAt = Math.max(s.lastBadAt ?? 0, h.at);
  }
  return s;
}

/** sessionStorage'dan geçmişi güvenle okur (özel pencere / engelli depolama: boş liste). */
export function readHistory(key: string): HistorySample[] {
  try {
    const raw = window.sessionStorage.getItem(key);
    if (!raw) return [];
    const arr = JSON.parse(raw) as unknown;
    if (!Array.isArray(arr)) return [];
    return arr
      .filter((x): x is HistorySample => !!x && typeof (x as HistorySample).at === 'number' && typeof (x as HistorySample).level === 'string')
      .map((x) => ({ at: x.at, level: levelOf(x.level) }))
      .slice(-HISTORY_MAX);
  } catch {
    return [];
  }
}

export function writeHistory(key: string, history: HistorySample[]): void {
  try {
    window.sessionStorage.setItem(key, JSON.stringify(history));
  } catch {
    /* depolama yoksa çizelge yalnız bellekte kalır */
  }
}

// ---------- Bölge ölçeği (yeşil / sarı / kırmızı şerit üstünde işaret) ----------
export interface ZoneScale {
  /** Şeridin üst sınırı (aynı birim). */
  max: number;
  /** Yeşilin bittiği yer (yüzde 0-100) ve sarının bittiği yer; kritik eşik yoksa null. */
  warnPct: number | null;
  critPct: number | null;
  /** İşaretin yeri (yüzde 0-100). */
  markPct: number;
}

/** Değer ve eşiklerden ölçek üretir. Eşik yoksa null (çubuk çizilmez, sayı uydurulmaz). */
export function zoneScale(value: number, warn: number | null | undefined, crit: number | null | undefined, fixedMax?: number): ZoneScale | null {
  if (!Number.isFinite(value) || value < 0) return null;
  const hasWarn = typeof warn === 'number' && Number.isFinite(warn) && warn > 0;
  const hasCrit = typeof crit === 'number' && Number.isFinite(crit) && crit > 0;
  if (!hasWarn && !hasCrit) return null;
  const top = Math.max(value, hasCrit ? (crit as number) : 0, hasWarn ? (warn as number) : 0);
  const max = fixedMax ?? Math.max(top * 1.15, 1);
  const pct = (n: number) => Math.min(100, Math.max(0, (n / max) * 100));
  return {
    max,
    warnPct: hasWarn ? pct(warn as number) : null,
    critPct: hasCrit ? pct(crit as number) : null,
    markPct: pct(value),
  };
}

// ---------- Otomatik görev şeridi ----------
export interface JobLane {
  id: string;
  level: SystemLevel;
  /** Son başarıdan beri geçen dakika; ölçülemediyse null. */
  ageMin: number | null;
  warnMin: number | null;
  critMin: number | null;
  scale: ZoneScale | null;
}

/** `jobs.*` göstergelerinden şerit modeli (sunucu saniye verir, dakikaya çevrilir). Sorunlu olanlar önce. */
export function jobLanes(entries: [string, SystemIndicator][]): JobLane[] {
  const order: Record<SystemLevel, number> = { CRIT: 0, WARN: 1, UNKNOWN: 2, OK: 3 };
  return entries
    .filter(([id]) => id.startsWith('jobs.'))
    .map(([id, ind]) => {
      const ageMin = typeof ind.value === 'number' ? toUnit('minutes', ind.value) : null;
      const warnMin = typeof ind.threshold?.warn === 'number' ? toUnit('minutes', ind.threshold.warn) : null;
      const critMin = typeof ind.threshold?.crit === 'number' ? toUnit('minutes', ind.threshold.crit) : null;
      return {
        id,
        level: levelOf(ind.status),
        ageMin,
        warnMin,
        critMin,
        scale: ageMin === null ? null : zoneScale(ageMin, warnMin, critMin),
      };
    })
    .sort((a, b) => order[a.level] - order[b.level] || a.id.localeCompare(b.id));
}

// ---------- Depolama büyüme tahmini (tablo boyutu / en eski kayıt yaşı) ----------
export interface GrowthRow {
  name: string;
  label: string;
  /** Günde ortalama büyüme (bayt). */
  perDay: number;
}

const DAY_MS = 86_400_000;

/**
 * Bir tablonun günde ortalama büyümesi: boyut / en eski kayıttan beri geçen gün. En az 1 günlük geçmiş ve
 * geçerli boyut yoksa null (tahmin uydurulmaz). Temizlik yapılmışsa gerçek büyümeden düşük çıkabilir: "ortalama" denir.
 */
export function growthPerDay(sizeBytes: number | null, oldestAt: string | null, now: number): number | null {
  if (sizeBytes === null || !Number.isFinite(sizeBytes) || sizeBytes <= 0 || !oldestAt) return null;
  const t = Date.parse(oldestAt);
  if (!Number.isFinite(t)) return null;
  const days = (now - t) / DAY_MS;
  if (days < 1) return null;
  return sizeBytes / days;
}

export function growthRows(tables: RetentionTable[] | undefined, now: number, limit = 6): GrowthRow[] {
  const rows: GrowthRow[] = [];
  for (const t of tables ?? []) {
    const perDay = growthPerDay(t.sizeBytes, t.oldestAt, now);
    if (perDay !== null) rows.push({ name: t.name, label: t.label, perDay });
  }
  return rows.sort((a, b) => b.perDay - a.perDay).slice(0, limit);
}

/** Boş yer ve günlük toplam büyümeden "kaç gün sonra dolar"; hesaplanamıyorsa null. */
export function daysUntilFull(freeBytes: number | null | undefined, perDayTotal: number): number | null {
  if (freeBytes === null || freeBytes === undefined || !Number.isFinite(freeBytes) || freeBytes < 0) return null;
  if (!Number.isFinite(perDayTotal) || perDayTotal <= 0) return null;
  return Math.floor(freeBytes / perDayTotal);
}

/** En dolu diskin boş baytı: veritabanı sunucusu ya da uygulama diskleri arasında en yüksek yüzdeli. */
export function fullestDisk(report: StorageReport | undefined): { key: string; percent: number; freeBytes: number | null } | null {
  if (!report) return null;
  const all = [report.dbServerDisk, ...report.appDisks].filter((d) => d.percent !== null);
  if (all.length === 0) return null;
  const worst = all.reduce((a, b) => ((b.percent ?? 0) > (a.percent ?? 0) ? b : a));
  return { key: worst.key, percent: worst.percent as number, freeBytes: worst.freeBytes };
}

// ---------- Çökme sürüm dağılımı ----------
export interface VersionTotal {
  key: string;
  version: string;
  platform: string;
  count: number;
}

/** Gruplardaki sürüm sayılarını (sürüm + platform) toplar; en çok çökme olan önce. */
export function crashVersionTotals(groups: CrashGroup[] | undefined): VersionTotal[] {
  const map = new Map<string, VersionTotal>();
  for (const g of groups ?? []) {
    for (const v of g.versions) {
      const key = `${v.version}|${v.platform}`;
      const cur = map.get(key);
      if (cur) cur.count += v.count;
      else map.set(key, { key, version: v.version, platform: v.platform, count: v.count });
    }
  }
  return [...map.values()].sort((a, b) => b.count - a.count);
}

export interface StatusShare {
  key: 'NEW' | 'ACK' | 'RESOLVED';
  count: number;
}

/** Çökme gruplarının durum payları (yığılmış çubuk). */
export function crashStatusShares(s: CrashSummary | undefined): StatusShare[] {
  if (!s) return [];
  return [
    { key: 'NEW' as const, count: s.newGroups },
    { key: 'ACK' as const, count: s.ackGroups },
    { key: 'RESOLVED' as const, count: s.resolvedGroups },
  ];
}

// ---------- Kuyruk parçaları ----------
export interface QueueSegment {
  key: string;
  count: number;
  tone: 'success' | 'info' | 'warning' | 'danger' | 'neutral';
}

/** Yığılmış kuyruk çubuğu için parçalar (sıfırlar atılır). */
export function queueSegments(parts: { key: string; count: number | undefined; tone: QueueSegment['tone'] }[]): QueueSegment[] {
  return parts
    .filter((p): p is { key: string; count: number; tone: QueueSegment['tone'] } => typeof p.count === 'number' && p.count > 0)
    .map((p) => ({ key: p.key, count: p.count, tone: p.tone }));
}

// ---------- Operasyon özeti (trafik ışığı girdileri) ----------
export interface OpsInputs {
  /** Sağlık uç yanıtı; ulaşılamadıysa null/undefined (özete katılmaz). */
  healthStatus?: string | null;
  mailDead?: number | null;
  pushDead?: number | null;
  /** Yedek uç yanıtı; uç yoksa null. */
  backup?: { status: string; lastSuccessAt: string | null } | null;
  now: number;
}

export type OpsProblem = 'health' | 'queues' | 'backupStale' | 'backupNever' | 'backupFailed';

export interface OpsSummaryResult {
  level: SystemLevel;
  problems: OpsProblem[];
  deadTotal: number;
  backupHours: number | null;
  /** Özete giren kaynak sayısı (0: hiçbir uçtan veri gelmedi). */
  known: number;
}

const BACKUP_STALE_HOURS = 48;

export function summarizeOps(i: OpsInputs): OpsSummaryResult {
  const levels: SystemLevel[] = [];
  const problems: OpsProblem[] = [];
  let known = 0;
  if (i.healthStatus !== undefined && i.healthStatus !== null) {
    known += 1;
    const s = i.healthStatus.toUpperCase();
    const level: SystemLevel =
      s === 'UP' || s === 'OK' ? 'OK' : s === 'DOWN' || s === 'FAILED' || s === 'OUT_OF_SERVICE' ? 'CRIT' : s === 'UNKNOWN' ? 'UNKNOWN' : 'WARN';
    levels.push(level);
    if (level === 'CRIT' || level === 'WARN') problems.push('health');
  }
  const dead = (i.mailDead ?? 0) + (i.pushDead ?? 0);
  if (typeof i.mailDead === 'number' || typeof i.pushDead === 'number') {
    known += 1;
    levels.push(dead > 0 ? 'WARN' : 'OK');
    if (dead > 0) problems.push('queues');
  }
  let backupHours: number | null = null;
  if (i.backup) {
    known += 1;
    const last = i.backup.lastSuccessAt ? Date.parse(i.backup.lastSuccessAt) : NaN;
    backupHours = Number.isFinite(last) ? Math.max(0, (i.now - last) / 3_600_000) : null;
    if (i.backup.status.toUpperCase() === 'FAILED') {
      levels.push('CRIT');
      problems.push('backupFailed');
    } else if (backupHours === null) {
      levels.push('WARN');
      problems.push('backupNever');
    } else if (backupHours > BACKUP_STALE_HOURS) {
      levels.push('WARN');
      problems.push('backupStale');
    } else levels.push('OK');
  }
  return { level: known === 0 ? 'UNKNOWN' : worstLevel(levels), problems, deadTotal: dead, backupHours, known };
}
