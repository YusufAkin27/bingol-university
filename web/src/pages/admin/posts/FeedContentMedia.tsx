// Şikâyet bağlamında Keşfet gönderisinin medya önizlemesi (yetkili uçtan blob; tıklayınca ortak Lightbox).
import { useMemo, useState } from 'react';
import { Lightbox } from '../chat/Lightbox';
import type { LightboxItem } from '../chat/chatLogic';
import { PostMediaThumb } from './PostParts';
import styles from './posts.module.css';

export interface FeedMediaRef {
  id: number;
  kind: string;
  url: string;
  thumbUrl: string;
}

export function FeedContentMedia({ media, createdAt }: { media: FeedMediaRef[]; createdAt?: string | null }) {
  const [lb, setLb] = useState<number | null>(null);
  const items = useMemo<LightboxItem[]>(
    () =>
      media.map((m) => ({
        key: `p${m.id}`,
        kind: m.kind,
        previewUrl: m.url,
        thumbUrl: m.thumbUrl,
        viewOnce: false,
        viewedBy: [],
        purged: false,
        hidden: false,
        messageDeleted: false,
        suppressed: false,
        width: 0,
        height: 0,
        bytes: 0,
        durationMs: null,
        senderName: null,
        createdAt: createdAt ?? new Date(0).toISOString(),
        conversationTitle: null,
        link: null,
      })),
    [media, createdAt],
  );
  return (
    <div className={styles.thumbs} data-testid="feed-content-media">
      {media.map((m, i) => (
        <PostMediaThumb
          key={m.id}
          media={{ id: m.id, kind: m.kind, url: m.url, thumbUrl: m.thumbUrl, width: null, height: null, durationMs: null, hidden: false }}
          onOpen={() => setLb(i)}
        />
      ))}
      {lb !== null && <Lightbox items={items} index={lb} onIndex={setLb} onClose={() => setLb(null)} />}
    </div>
  );
}
