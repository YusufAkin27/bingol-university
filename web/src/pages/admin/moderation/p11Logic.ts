// Moderasyon + destek tamamlama (P11/P12) saf mantığı (birim testli): şablon doğrulama, sıralama, CSV adı, ihlal durumu.
import type { AdminMessage } from '../../../api/supportAdmin';
import type { StrikeRow } from '../../../api/modAdmin';
import type { ReportTargetType, TicketMessage } from '../../../api/types';

/** Moderasyon hedef türleri (sunucu ReportTargetType ile aynı). */
export const MOD_TARGET_TYPES: ReportTargetType[] = [
  'USER',
  'MESSAGE',
  'POST',
  'COMMUNITY',
  'EVENT',
  'MESSAGE_IMAGE',
  'USER_AVATAR',
  'COMMUNITY_COVER',
  'EVENT_COVER',
  'FEED_POST',
];

/** Sunucu kuralı: harfle başlar, harf/rakam/alt çizgi, 2-32 karakter (sunucu büyük harfe çevirir). */
export const TEMPLATE_CODE_RE = /^[A-Za-z][A-Za-z0-9_]{1,31}$/;
export const TEMPLATE_TEXT_MAX = 300;

export interface TemplateDraft {
  code: string;
  textTr: string;
  textEn: string;
  textAr: string;
  active: boolean;
  sortOrder: string;
}

export const EMPTY_TEMPLATE: TemplateDraft = { code: '', textTr: '', textEn: '', textAr: '', active: true, sortOrder: '' };

/** Alan hataları (anahtar → çeviri anahtarı). `isNew` iken kod da doğrulanır (kod sonradan değişmez). */
export function templateErrors(d: TemplateDraft, isNew: boolean): Partial<Record<'code' | 'textTr' | 'textEn' | 'textAr' | 'sortOrder', string>> {
  const e: Partial<Record<'code' | 'textTr' | 'textEn' | 'textAr' | 'sortOrder', string>> = {};
  if (isNew && !TEMPLATE_CODE_RE.test(d.code.trim())) e.code = 'admin.p11.tpl.err.code';
  if (!d.textTr.trim()) e.textTr = 'admin.p11.tpl.err.textTr';
  if (d.textTr.length > TEMPLATE_TEXT_MAX) e.textTr = 'admin.p11.tpl.err.tooLong';
  if (d.textEn.length > TEMPLATE_TEXT_MAX) e.textEn = 'admin.p11.tpl.err.tooLong';
  if (d.textAr.length > TEMPLATE_TEXT_MAX) e.textAr = 'admin.p11.tpl.err.tooLong';
  if (d.sortOrder.trim() && !/^\d{1,5}$/.test(d.sortOrder.trim())) e.sortOrder = 'admin.p11.tpl.err.order';
  return e;
}

/** İstek gövdesi: boş en/ar gönderilmez; sunucuda boş en/ar Türkçeye düşer. */
export function templateBody(d: TemplateDraft, isNew: boolean) {
  return {
    ...(isNew ? { code: d.code.trim().toUpperCase() } : {}),
    textTr: d.textTr.trim(),
    textEn: d.textEn.trim(),
    textAr: d.textAr.trim(),
    active: d.active,
    ...(d.sortOrder.trim() ? { sortOrder: Number.parseInt(d.sortOrder.trim(), 10) } : {}),
  };
}

/** Ek bir şablon eklenebilir mi (sunucu üst sınırı 50). */
export const canAddTemplate = (count: number, max: number) => count < max;

/** Bir ihlalin görünen durumu: sayılıyor / affedildi (yönetici) / iptal (itiraz kabulü). */
export type StrikeState = 'ACTIVE' | 'FORGIVEN' | 'REVOKED';
export function strikeState(s: Pick<StrikeRow, 'active' | 'forgiven'>): StrikeState {
  if (s.active) return 'ACTIVE';
  return s.forgiven ? 'FORGIVEN' : 'REVOKED';
}
/** Yalnız sayılan ihlal affedilebilir. */
export const canForgive = (s: Pick<StrikeRow, 'active'>) => s.active;

/** Geri alma düğmesi: yalnız geri alınabilir tür ve içerik hâlâ varsa. İkinci değer: neden kapalı (çeviri anahtarı). */
export function restoreAvailability(r: { reversible: boolean; exists: boolean }): { ok: boolean; why?: string } {
  if (!r.reversible) return { ok: false, why: 'admin.p11.hidden.why.notReversible' };
  if (!r.exists) return { ok: false, why: 'admin.p11.hidden.why.gone' };
  return { ok: true };
}

/** Yukarı/aşağı taşı: yeni dizi (sınır dışı ise aynı dizi). */
export function moveItem<T>(list: readonly T[], index: number, delta: -1 | 1): T[] {
  const to = index + delta;
  if (index < 0 || index >= list.length || to < 0 || to >= list.length) return [...list];
  const next = [...list];
  const [it] = next.splice(index, 1);
  next.splice(to, 0, it);
  return next;
}

/** İndirme dosya adı: `<ad>-YYYY-MM-DD.csv`. */
export function csvName(base: string, now: Date = new Date()): string {
  return `${base}-${now.toISOString().slice(0, 10)}.csv`;
}

/**
 * Personel yanıtı sonucunda dönen müşteri görünümü mesajlarını (iç not içermez) mevcut yönetici ayrıntısındaki
 * iç notlarla birleştirir: yanıt gelince iç notlar kaybolmasın. Zaman sırası; eşitlikte mesaj önce.
 */
export function mergeThread(replyMessages: TicketMessage[], previous: AdminMessage[]): AdminMessage[] {
  const thread: AdminMessage[] = replyMessages.map((m) => ({ ...m, internal: false, authorId: null }));
  const notes = previous.filter((m) => m.internal);
  return [...thread, ...notes].sort(
    (a, b) => Date.parse(a.createdAt) - Date.parse(b.createdAt) || Number(a.internal) - Number(b.internal) || a.id - b.id,
  );
}

/** Sohbet balonları: iç not olmayan mesajlar (alan yoksa mesajdır). */
export const threadMessages = (all: AdminMessage[]): AdminMessage[] => all.filter((m) => !m.internal);
export const internalNotes = (all: AdminMessage[]): AdminMessage[] => all.filter((m) => m.internal);

/** Atama kimliği alanı: pozitif tamsayı ya da null. */
export function parseAssignee(v: string): number | null {
  const s = v.trim();
  if (!/^\d{1,12}$/.test(s)) return null;
  const n = Number(s);
  return n > 0 ? n : null;
}
