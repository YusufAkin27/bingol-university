// Gönderi yönetimi için saf yardımcılar (test edilebilir): Lightbox öğesi dönüşümü, süzgeç temizliği, metin özeti.
import type { AdminPostMedia, AdminPostRow } from '../../../api/adminPosts';
import type { LightboxItem } from '../chat/chatLogic';

export interface PostFilterState {
  q: string;
  hidden: boolean;
  deleted: boolean;
  hasMedia: boolean;
  from: string;
  to: string;
}

export const EMPTY_POST_FILTERS: PostFilterState = { q: '', hidden: false, deleted: false, hasMedia: false, from: '', to: '' };

/** Liste satırında gösterilecek metin özeti (uzunsa kırpılır, satır sonları boşluk olur). */
export function excerpt(text: string | null | undefined, max = 160): string {
  if (!text) return '';
  const flat = text.replace(/\s+/g, ' ').trim();
  return flat.length <= max ? flat : `${flat.slice(0, max).trim()}…`;
}

/** Gönderinin medyasını ortak büyük görüntüleyicinin (Lightbox) öğelerine çevirir. */
export function mediaToLightbox(post: AdminPostRow): LightboxItem[] {
  return post.media.map((m: AdminPostMedia) => ({
    key: `p${m.id}`,
    kind: m.kind,
    previewUrl: m.url,
    thumbUrl: m.thumbUrl,
    viewOnce: false,
    viewedBy: [],
    purged: false,
    hidden: m.hidden,
    messageDeleted: post.deleted,
    suppressed: false,
    width: m.width ?? 0,
    height: m.height ?? 0,
    bytes: 0,
    durationMs: m.durationMs,
    senderName: post.author.displayName,
    createdAt: post.createdAt,
    conversationTitle: null,
    link: null,
  }));
}

/** Durum rozeti: silinmiş her şeyin önünde gelir. */
export function postStatus(p: Pick<AdminPostRow, 'hidden' | 'deleted'>): 'deleted' | 'hidden' | 'visible' {
  return p.deleted ? 'deleted' : p.hidden ? 'hidden' : 'visible';
}
