// Mesaj eki küçük resmi. Önizleme ucu Bearer ister (<img> gönderemez) → blob olarak çekilip nesne adresine çevrilir.
import { useEffect, useState } from 'react';
import { apiBlob } from '../../../api/client';
import type { AdminChatAttachment } from '../../../api/types';
import { useI18n } from '../../../i18n/I18nProvider';
import { previewApiPath } from './chatLogic';
import styles from './chat.module.css';

export function AttachmentThumb({ a }: { a: AdminChatAttachment }) {
  const { t } = useI18n();
  const [src, setSrc] = useState<string | null>(null);
  const [failed, setFailed] = useState(false);
  const [full, setFull] = useState(false);

  useEffect(() => {
    let url: string | null = null;
    let cancelled = false;
    apiBlob(previewApiPath(full ? a.previewUrl : a.thumbUrl))
      .then((b) => {
        if (cancelled) return;
        url = URL.createObjectURL(b);
        setSrc(url);
      })
      .catch(() => {
        if (!cancelled) setFailed(true);
      });
    return () => {
      cancelled = true;
      if (url) URL.revokeObjectURL(url);
    };
  }, [a.previewUrl, a.thumbUrl, full]);

  return (
    <figure className={styles.attachment} data-testid="chat-attachment">
      {src && !failed ? (
        <button type="button" className={styles.thumbBtn} onClick={() => setFull((v) => !v)} aria-pressed={full}>
          <img src={src} alt={t('admin.chat.image')} className={full ? styles.imgFull : styles.imgThumb} />
        </button>
      ) : (
        <span className={styles.muted}>{failed ? t('admin.chat.imageFailed') : t('admin.chat.image')}</span>
      )}
      <figcaption className={styles.muted}>
        {t('admin.chat.image')} · {a.width}×{a.height}
        {a.hidden ? ` · ${t('admin.chat.hiddenImage')}` : ''}
      </figcaption>
    </figure>
  );
}
