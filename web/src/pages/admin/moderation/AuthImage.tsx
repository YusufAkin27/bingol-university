// Moderasyon önizleme görseli. Yöneticiye özel görseller `/api/...` altındadır ve Bearer başlığı ister;
// `<img src>` başlık gönderemediğinden blob olarak çekilip geçici adrese çevrilir. `/files/...` ve https adresleri doğrudan gösterilir.
import { useEffect, useState } from 'react';
import { apiBlob } from '../../../api/client';
import { useI18n } from '../../../i18n/I18nProvider';
import { isSafeImageUrl, previewApiPath } from './modLogic';
import styles from './moderation.module.css';

export function AuthImage({ url, alt, className }: { url: string | null; alt: string; className?: string }) {
  const { t } = useI18n();
  const apiPath = previewApiPath(url);
  const direct = !apiPath && isSafeImageUrl(url) ? url : null;
  const [blobSrc, setBlobSrc] = useState<string | null>(null);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    if (!apiPath) return;
    let cancelled = false;
    let objectUrl: string | null = null;
    setBlobSrc(null);
    setFailed(false);
    apiBlob(apiPath)
      .then((b) => {
        if (cancelled) return;
        objectUrl = URL.createObjectURL(b);
        setBlobSrc(objectUrl);
      })
      .catch(() => {
        if (!cancelled) setFailed(true);
      });
    return () => {
      cancelled = true;
      if (objectUrl) URL.revokeObjectURL(objectUrl);
    };
  }, [apiPath]);

  const src = direct ?? blobSrc;
  if (!src) {
    return (
      <div className={styles.imgPlaceholder} role="img" aria-label={alt}>
        {failed || (!apiPath && !direct) ? t('admin.mod.preview.unavailable') : t('common.loading')}
      </div>
    );
  }
  return <img src={src} alt={alt} className={`${styles.img} ${className ?? ''}`} loading="lazy" />;
}
