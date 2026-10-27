// Büyük medya görüntüleyici: yan yana gezinme (düğme + ok tuşları), sağ üstte kapat, altta gönderen/zaman/boyut bilgisi.
import { useEffect, useRef } from 'react';
import { Link } from 'react-router-dom';
import { Icon, IconButton, Spinner, useFocusTrap } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { formatBytes, formatDuration, stepIndex, type LightboxItem } from './chatLogic';
import { MediaBadges, ViewedByLine } from './MediaThumb';
import { useBlobUrl } from './useBlobUrl';
import styles from './chat.module.css';

export function Lightbox({
  items,
  index,
  onIndex,
  onClose,
}: {
  items: LightboxItem[];
  index: number;
  onIndex: (i: number) => void;
  onClose: () => void;
}) {
  const { t, formatDateTime, dir } = useI18n();
  const ref = useRef<HTMLDivElement>(null);
  useFocusTrap(ref, true, onClose);
  const item = items[index];
  const { src, failed } = useBlobUrl(item && !item.purged ? (item.previewUrl ?? item.thumbUrl) : null);

  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      const next = dir === 'rtl' ? 'ArrowLeft' : 'ArrowRight';
      const prev = dir === 'rtl' ? 'ArrowRight' : 'ArrowLeft';
      if (e.key === next) onIndex(stepIndex(index, 1, items.length));
      else if (e.key === prev) onIndex(stepIndex(index, -1, items.length));
    }
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [index, items.length, onIndex, dir]);

  if (!item) return null;
  const isVideo = item.kind === 'VIDEO';
  return (
    <div className={styles.lbScrim} onMouseDown={(e) => e.target === e.currentTarget && onClose()}>
      <div ref={ref} role="dialog" aria-modal="true" aria-label={t('admin.chat.media.viewer')} tabIndex={-1} className={styles.lb}>
        <div className={styles.lbClose}>
          <IconButton label={t('admin.chat.media.close')} onClick={onClose}>
            <Icon name="x" size={20} />
          </IconButton>
        </div>
        <div className={styles.lbStage}>
          <IconButton
            label={t('admin.chat.media.prev')}
            onClick={() => onIndex(stepIndex(index, -1, items.length))}
            disabled={index <= 0}
          >
            <Icon name={dir === 'rtl' ? 'chevronRight' : 'chevronLeft'} size={22} />
          </IconButton>
          <div className={styles.lbMedia} data-testid="lightbox-media">
            {item.purged ? (
              <p className={styles.lbNote}>
                {t('admin.chat.media.purged')}
                <br />
                <small>{t('admin.chat.media.purgedHint')}</small>
              </p>
            ) : failed ? (
              <p className={styles.lbNote}>{t('admin.chat.imageFailed')}</p>
            ) : !src ? (
              <Spinner />
            ) : isVideo ? (
              <video src={src} controls className={styles.lbImg} />
            ) : (
              <img src={src} alt={t('admin.chat.image')} className={styles.lbImg} />
            )}
          </div>
          <IconButton
            label={t('admin.chat.media.next')}
            onClick={() => onIndex(stepIndex(index, 1, items.length))}
            disabled={index >= items.length - 1}
          >
            <Icon name={dir === 'rtl' ? 'chevronLeft' : 'chevronRight'} size={22} />
          </IconButton>
        </div>
        <div className={styles.lbInfo} data-testid="lightbox-info">
          <span>
            <strong dir="auto">{item.senderName ?? '?'}</strong> ·{' '}
            <time dateTime={item.createdAt}>{formatDateTime(item.createdAt)}</time>
          </span>
          <span className={styles.muted}>
            {formatBytes(item.bytes)}
            {item.width > 0 ? ` · ${item.width}×${item.height}` : ''}
            {isVideo && item.durationMs != null ? ` · ${formatDuration(item.durationMs)}` : ''}
            {' · '}
            {t('admin.chat.media.counter', { i: index + 1, n: items.length })}
          </span>
          {item.conversationTitle && (
            <span className={styles.muted} dir="auto">
              {item.conversationTitle}
            </span>
          )}
          <MediaBadges item={item} />
          <ViewedByLine item={item} />
          {item.link && (
            <Link to={item.link} onClick={onClose}>
              {t('admin.chat.showInChat')}
            </Link>
          )}
        </div>
      </div>
    </div>
  );
}
