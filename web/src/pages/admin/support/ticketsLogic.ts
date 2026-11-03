// Talep listesi süzgeci. Sunucu yalnız durum ve "hesapsız" süzer (imeç sayfalı); kategori ve arama yüklenen satırlar üzerinde çalışır.
import type { AdminTicketSummary, TicketCategory } from '../../../api/types';

export const CATEGORIES: TicketCategory[] = ['ACCOUNT', 'TECHNICAL', 'CONTENT', 'OTHER'];

const norm = (s: string) => s.toLocaleLowerCase('tr').trim();

export function filterTickets<T extends AdminTicketSummary>(
  rows: T[],
  f: { category: TicketCategory | ''; q: string },
): T[] {
  const q = norm(f.q).replace(/^#/, '');
  return rows.filter((r) => {
    if (f.category && r.category !== f.category) return false;
    if (!q) return true;
    return (
      String(r.id) === q ||
      norm(r.subject).includes(q) ||
      norm(r.userEmail ?? '').includes(q)
    );
  });
}

/** Yanıt bekleyenin kenar rengi/tonu: bekleyen vurgulanır, diğerleri sakin kalır. */
export const rowTone = (status: AdminTicketSummary['status']) =>
  status === 'OPEN' ? 'warn' : status === 'ANSWERED' ? 'ok' : 'idle';
