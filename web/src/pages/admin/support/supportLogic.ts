import { readStorage, writeStorage } from '../../../lib/storage';
import type {
  AdminFeedbackView,
  FeedbackStatus,
  TicketStatus,
  UpdateFeedbackRequest,
} from '../../../api/types';

export const MAX_REPLY = 2000;
export const MAX_FEEDBACK_RESPONSE = 1000;
export const FEEDBACK_STATUSES: FeedbackStatus[] = ['NEW', 'IN_REVIEW', 'PLANNED', 'DONE', 'REJECTED'];

/** Talep durumu geçişleri: yanıt → ANSWERED, kapat → CLOSED; kapalı talebe yanıt yazılamaz. */
export function nextTicketStatus(current: TicketStatus, event: 'reply' | 'close'): TicketStatus {
  if (event === 'close') return 'CLOSED';
  return current === 'CLOSED' ? 'CLOSED' : 'ANSWERED';
}
export const canReply = (s: TicketStatus) => s !== 'CLOSED';
export const canClose = (s: TicketStatus) => s !== 'CLOSED';

/** Ctrl+Enter / Cmd+Enter gönderir. */
export function isSubmitShortcut(e: { key: string; ctrlKey: boolean; metaKey: boolean }): boolean {
  return e.key === 'Enter' && (e.ctrlKey || e.metaKey);
}

// ---------- Hazır yanıtlar (yerel) ----------
export const TEMPLATES_KEY = 'bu.admin.replyTemplates';
export const MAX_TEMPLATES = 20;

export interface ReplyTemplate {
  id: string;
  text: string;
}

export function loadTemplates(): ReplyTemplate[] {
  try {
    const raw = readStorage('local', TEMPLATES_KEY);
    if (!raw) return [];
    const parsed: unknown = JSON.parse(raw);
    if (!Array.isArray(parsed)) return [];
    return parsed
      .filter(
        (x): x is ReplyTemplate =>
          typeof x === 'object' && x !== null && typeof (x as ReplyTemplate).id === 'string' &&
          typeof (x as ReplyTemplate).text === 'string',
      )
      .slice(0, MAX_TEMPLATES);
  } catch {
    return [];
  }
}

export function saveTemplates(list: ReplyTemplate[]): void {
  writeStorage('local', TEMPLATES_KEY, JSON.stringify(list.slice(0, MAX_TEMPLATES)));
}

/** Şablon ekler: boşu ve aynı metni (tekrar) reddeder, üst sınırı korur. Yeni listeyi döner. */
export function addTemplate(list: ReplyTemplate[], text: string): ReplyTemplate[] {
  const t = text.trim().slice(0, MAX_REPLY);
  if (!t || list.some((x) => x.text === t) || list.length >= MAX_TEMPLATES) return list;
  const id = `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 6)}`;
  return [...list, { id, text: t }];
}
export const removeTemplate = (list: ReplyTemplate[], id: string) => list.filter((x) => x.id !== id);

// ---------- Geri bildirim ----------
export interface FeedbackDraft {
  status: FeedbackStatus;
  adminResponse: string;
  publicVisible: boolean;
}

export const canPublish = (category: AdminFeedbackView['category']) => category === 'SUGGESTION';

/** Yalnızca değişen alanları içeren PATCH gövdesi; boş yanıt gönderilmez. Değişiklik yoksa null. */
export function feedbackPatch(orig: AdminFeedbackView, d: FeedbackDraft): UpdateFeedbackRequest | null {
  const patch: UpdateFeedbackRequest = {};
  if (d.status !== orig.status) patch.status = d.status;
  const resp = d.adminResponse.trim();
  if (resp !== '' && resp !== (orig.adminResponse ?? '')) patch.adminResponse = resp;
  if (canPublish(orig.category) && d.publicVisible !== orig.publicVisible) patch.publicVisible = d.publicVisible;
  return Object.keys(patch).length ? patch : null;
}
