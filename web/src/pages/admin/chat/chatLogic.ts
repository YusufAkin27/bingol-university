// Yönetici sohbet görüntüleyicisinin saf mantığı (testlenebilir): sayfa birleştirme, balon yönü, yukarı kaydırmada yükleme.
import type { AdminChatMessage, AdminChatMessagePage } from '../../../api/types';

/** Yukarıdan bu kadar piksel kala (scrollTop <= eşik) eski sayfa istenir. */
export const LOAD_OLDER_THRESHOLD_PX = 120;
export const MESSAGE_PAGE_SIZE = 50;

/**
 * useInfiniteQuery sayfaları "önce en yeni" sırasındadır (ilk sayfa en yeni 50 mesaj; sonrakiler daha eski).
 * Her sayfa kendi içinde eskiden yeniye sıralıdır. Ekranda eskiden yeniye tek liste gerekir.
 */
export function flattenPages(pages: AdminChatMessagePage[]): AdminChatMessage[] {
  const seen = new Set<number>();
  const out: AdminChatMessage[] = [];
  for (const page of [...pages].reverse()) {
    for (const m of page.items) {
      if (!seen.has(m.id)) {
        seen.add(m.id);
        out.push(m);
      }
    }
  }
  return out;
}

/** Sonraki (daha eski) sayfa imleci; yoksa undefined (react-query "devam yok" olarak okur). */
export function nextBeforeParam(last: AdminChatMessagePage): number | undefined {
  return last.nextBefore ?? undefined;
}

export type BubbleSide = 'self' | 'peer';

/** Açılan kullanıcının mesajı bir yanda ('self'), karşı taraflar diğer yanda ('peer'); Arapçada CSS ayna yapar. */
export function bubbleSide(m: Pick<AdminChatMessage, 'mine'>): BubbleSide {
  return m.mine ? 'self' : 'peer';
}

/** Yukarı kaydırmada eski sayfayı yükle: eşiğe gelindi, devam var ve zaten istek yok. */
export function shouldLoadOlder(scrollTop: number, hasMore: boolean, fetching: boolean): boolean {
  return hasMore && !fetching && scrollTop <= LOAD_OLDER_THRESHOLD_PX;
}

/** Eski sayfa eklenince görünüm zıplamasın: yeni scrollTop = eski scrollTop + yükseklik farkı. */
export function restoredScrollTop(prevScrollTop: number, prevScrollHeight: number, newScrollHeight: number): number {
  return prevScrollTop + Math.max(0, newScrollHeight - prevScrollHeight);
}

/** Gün ayracı için yerel takvim günü anahtarı. */
export function dayKey(iso: string): string {
  const d = new Date(iso);
  return `${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`;
}

/** Önizleme uç yolu (sunucu `/api/...` döner; api istemcisi tabanı kendisi ekler). */
export function previewApiPath(url: string): string {
  return url.replace(/^\/api(?=\/)/, '');
}
