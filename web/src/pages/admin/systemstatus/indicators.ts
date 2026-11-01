// Sistem durumu: gösterge adı/açıklaması, değer ve eşik cümleleri. Ham anahtar ya da birimsiz sayı ASLA gösterilmez.
import { toUnit, unitOf, type SystemIndicator, type SystemLevel } from '../../../api/system';
import type { I18n } from '../../../i18n/I18nProvider';

/** Anahtarın ekranda görünen adı; çevirisi olmayan anahtar ham haliyle değil "Diğer gösterge" olarak yazılır. */
export function nameOf(i18n: I18n, id: string): string {
  if (id.endsWith('.error')) return i18n.t('admin.v2n.sys.name.error');
  return i18n.td(`admin.v2n.sys.name.${id}`, i18n.t('admin.v2n.sys.name.other'));
}

/** Göstergenin ne işe yaradığını anlatan tek cümle (çocuk dili). */
export function aboutOf(i18n: I18n, id: string): string {
  if (id.endsWith('.error')) return i18n.t('admin.v2n.sys.about.error');
  return i18n.td(`admin.v2n.sys.about.${id}`, '');
}

/** "70 dk", "2 sa 10 dk" (dakika cinsinden). */
export function formatMinutes(i18n: I18n, minutes: number): string {
  const m = Math.max(0, Math.round(minutes));
  if (m < 60) return i18n.t('admin.system.unit.minutes', { n: i18n.formatNumber(m) });
  const h = Math.floor(m / 60);
  const rest = m % 60;
  if (h >= 48) return i18n.t('admin.v2n.sys.unit.days', { n: i18n.formatNumber(Math.floor(h / 24)) });
  if (rest === 0) return i18n.t('admin.system.unit.hours', { n: i18n.formatNumber(h) });
  return `${i18n.t('admin.system.unit.hours', { n: i18n.formatNumber(h) })} ${i18n.t('admin.system.unit.minutes', {
    n: i18n.formatNumber(rest),
  })}`;
}

/** Saat cinsinden süre (yedek yaşı): "6,5 sa", 2 günden uzunsa gün. */
export function formatHours(i18n: I18n, hours: number): string {
  if (hours >= 48) return i18n.t('admin.v2n.sys.unit.days', { n: i18n.formatNumber(Math.floor(hours / 24)) });
  return i18n.t('admin.system.unit.hours', { n: i18n.formatNumber(hours, { maximumFractionDigits: 1 }) });
}

/** Sayı + isim: "3 e-posta", "12 kişi". */
function countText(i18n: I18n, id: string, n: number): string {
  const noun = i18n.td(`admin.v2n.sys.noun.${id}`, '');
  const f = i18n.formatNumber(n);
  return noun ? `${f} ${noun}` : f;
}

function plainNumber(i18n: I18n, id: string, n: number): string {
  const unit = unitOf(id);
  const v = toUnit(unit, n);
  if (unit === 'minutes') return formatMinutes(i18n, v);
  if (unit === 'hours') return formatHours(i18n, v);
  if (unit === 'percent') return i18n.t('admin.system.unit.percent', { n: i18n.formatNumber(v, { maximumFractionDigits: 1 }) });
  if (unit === 'ms') return i18n.t('admin.system.unit.ms', { n: i18n.formatNumber(v) });
  return i18n.formatNumber(v);
}

/** Sayısal değerin kısa, birimli yazımı. */
export function valueText(i18n: I18n, id: string, ind: SystemIndicator): string {
  const v = ind.value;
  if (v === null || v === undefined) return '—';
  if (typeof v === 'string') return v;
  if (typeof v === 'object') return objectText(i18n, id, v);
  const unit = unitOf(id);
  const waiting = id.endsWith('Age') || id === 'campaign.overdue';
  if (waiting && v <= 0) return i18n.t('admin.v2n.sys.noWaiting');
  if (id.startsWith('jobs.')) {
    const min = toUnit('minutes', v);
    return min < 1 ? i18n.t('admin.v2n.sys.justNow') : i18n.t('admin.v2n.sys.ago', { t: formatMinutes(i18n, min) });
  }
  if (id === 'backup.age') return i18n.t('admin.v2n.sys.ago', { t: formatHours(i18n, v) });
  if (unit === 'percent') return i18n.t('admin.v2n.sys.usedPercent', { n: i18n.formatNumber(v, { maximumFractionDigits: 1 }) });
  if (unit === 'count') return countText(i18n, id, v);
  return plainNumber(i18n, id, v);
}

/** Nesne değerleri (kampanya sayıları, bildirim servisi) tek cümleye çevirilir. */
function objectText(i18n: I18n, id: string, v: Record<string, unknown>): string {
  if (id === 'fcm') {
    const delivered = Number(v.delivered ?? 0);
    const failures = Number(v.failures ?? 0);
    const base = i18n.t('admin.v2n.sys.fcm.sentFailed', {
      sent: i18n.formatNumber(delivered),
      failed: i18n.formatNumber(failures),
    });
    const last = typeof v.lastFailureAt === 'string' ? v.lastFailureAt : null;
    return last ? `${base} ${i18n.t('admin.v2n.sys.fcm.lastFail', { when: i18n.formatDateTime(last) })}` : base;
  }
  const parts = campaignParts(i18n, v);
  return parts.length === 0 ? i18n.t('admin.v2n.sys.campaign.none') : parts.map((p) => `${p.n} ${p.label}`).join(', ');
}

/** Kampanya durum sayıları (sıfırlar atılır), çevrilmiş durum adıyla. */
export function campaignParts(i18n: I18n, v: Record<string, unknown>): { key: string; n: number; label: string }[] {
  return Object.entries(v)
    .map(([key, raw]) => ({ key, n: Number(raw) }))
    .filter((p) => Number.isFinite(p.n) && p.n > 0)
    .map((p) => ({ ...p, label: i18n.td(`admin.v2n.sys.campaign.${p.key}`, i18n.td(`admin.campaigns.status.${p.key}`, p.key)) }));
}

/** Eşikleri aynı birimde ve düz cümleyle yazar; eşik yoksa null. */
export function thresholdText(i18n: I18n, id: string, th: SystemIndicator['threshold']): string | null {
  if (!th || th.warn === undefined) return null;
  const warn = plainNumber(i18n, id, th.warn);
  if (th.crit === undefined) return i18n.t('admin.v2n.sys.th.warn', { warn });
  return i18n.t('admin.v2n.sys.th.both', { warn, crit: plainNumber(i18n, id, th.crit) });
}

/** Meter: değer ve eşik aynı birimde (dakika/saat/yüzde/ham). Sayısal olmayan ya da eşiksiz göstergede null. */
export interface MeterModel {
  value: number;
  warn: number;
  crit: number | null;
  max: number;
}

export function meterOf(id: string, ind: SystemIndicator): MeterModel | null {
  if (typeof ind.value !== 'number' || !ind.threshold || ind.threshold.warn === undefined) return null;
  const unit = unitOf(id);
  const value = toUnit(unit, ind.value);
  const warn = toUnit(unit, ind.threshold.warn);
  const crit = ind.threshold.crit === undefined ? null : toUnit(unit, ind.threshold.crit);
  const top = Math.max(value, crit ?? 0, warn);
  const max = unit === 'percent' ? 100 : Math.max(top * 1.15, 1);
  return { value, warn, crit, max };
}

/** Yüzde halkası gösterilecek göstergeler. */
export function isRing(id: string, ind: SystemIndicator): boolean {
  return unitOf(id) === 'percent' && typeof ind.value === 'number';
}

/** Düzey sırası: sorunlu olan önce. */
export const LEVEL_ORDER: Record<SystemLevel, number> = { CRIT: 0, WARN: 1, UNKNOWN: 2, OK: 3 };
