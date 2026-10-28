// Sohbet müdahalesi (P08) saf mantığı: mesaj durumu, hangi işlem açık, toplu seçim, dışa aktarma onay koşulları.
// Sunucu kuralları: hide yalnız hiç gizlenmemiş/silinmemiş mesajda; unhide yalnız YÖNETİCİ gizlemesinde (moderasyon
// gizlemesini geri açmaz); purge her mesajda (kalıcı silinmiş hariç) ve GERİ ALINAMAZ.
import { matchesTarget } from '../../../components/admin/guard/match';
import type { AdminChatMessage } from '../../../api/types';
import { EXPORT_MAX_MESSAGES, EXPORT_REASON_MIN } from '../../../api/adminChat';

export type MessageState = 'PURGED' | 'ADMIN_HIDDEN' | 'HIDDEN' | 'DELETED' | 'VISIBLE';

type StateFields = Pick<AdminChatMessage, 'deleted' | 'hidden'> & { adminHidden?: boolean; purged?: boolean };

export function messageState(m: StateFields): MessageState {
  if (m.purged) return 'PURGED';
  if (m.adminHidden) return 'ADMIN_HIDDEN';
  if (m.hidden) return 'HIDDEN'; // moderasyon (rapor kararı) gizlemesi
  if (m.deleted) return 'DELETED'; // kullanıcı "herkes için sil"
  return 'VISIBLE';
}

export interface MessageActionSet {
  hide: boolean;
  unhide: boolean;
  purge: boolean;
}

export function availableActions(state: MessageState): MessageActionSet {
  return {
    hide: state === 'VISIBLE',
    unhide: state === 'ADMIN_HIDDEN',
    purge: state !== 'PURGED',
  };
}

/** Toplu gizlemeye seçilebilir mi (yalnız görünür mesaj). */
export function isBulkSelectable(m: StateFields): boolean {
  return availableActions(messageState(m)).hide;
}

/** Sunucu toplu gizleme üst sınırı. */
export const BULK_HIDE_MAX = 200;

/** Seçimi değiştirir (yeni Set döner; sınır aşılırsa eklenmez). */
export function toggleSelection(sel: ReadonlySet<number>, id: number, on: boolean, max = BULK_HIDE_MAX): Set<number> {
  const next = new Set(sel);
  if (!on) {
    next.delete(id);
  } else if (next.size < max) {
    next.add(id);
  }
  return next;
}

/** Yalnız hâlâ seçilebilir olan kimlikleri tutar (liste yenilenince eskiyen seçim düşer). */
export function pruneSelection(sel: ReadonlySet<number>, messages: readonly (StateFields & { id: number })[]): Set<number> {
  const ok = new Set(messages.filter(isBulkSelectable).map((m) => m.id));
  return new Set([...sel].filter((id) => ok.has(id)));
}

export interface ExportGate {
  reasonOk: boolean;
  confirmOk: boolean;
  /** İki aşamanın ikisi de tamam: dışa aktarma düğmesi açılır. */
  ready: boolean;
}

/** Dışa aktarma iki aşamalı onayı: sebep >= 20 karakter + sohbet kimliğinin yazdırılması. */
export function exportGate(reason: string, typedId: string, conversationId: number): ExportGate {
  const reasonOk = reason.trim().length >= EXPORT_REASON_MIN;
  const confirmOk = matchesTarget(typedId, String(conversationId));
  return { reasonOk, confirmOk, ready: reasonOk && confirmOk };
}

/** Dosya adı: sohbet kimliği + biçim (+ devam imleci varsa). */
export function exportFileName(conversationId: number, format: 'json' | 'csv', afterId?: number | null): string {
  return `sohbet-${conversationId}${afterId ? `-sonrasi-${afterId}` : ''}.${format}`;
}

/** Toplu sonuç özeti: hata kodlarına göre say (kısmi başarı mesajı için). */
export function summarizeBulk(items: readonly { ok: boolean; error: string | null }[]): { ok: number; failed: number; codes: string[] } {
  const codes = new Set<string>();
  let ok = 0;
  let failed = 0;
  for (const i of items) {
    if (i.ok) ok += 1;
    else {
      failed += 1;
      if (i.error) codes.add(i.error);
    }
  }
  return { ok, failed, codes: [...codes] };
}

export { EXPORT_MAX_MESSAGES, EXPORT_REASON_MIN };
