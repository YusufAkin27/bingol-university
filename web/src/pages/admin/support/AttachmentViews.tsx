// Destek mesajı ekleri: görsel küçük resimleri (tıklayınca büyük görüntüleyici), video (tıklayınca yüklenir, HTML5 kontrolleri).
// Ek adresleri yetkilidir (Bearer): <img>/<video> doğrudan açamaz, bu yüzden useBlobUrl ile nesne adresine çevrilir.
import { useEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { Icon, IconButton, Spinner, useFocusTrap } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import type { AttachmentView } from '../../../api/types';
import { formatBytes, formatDuration, stepIndex } from '../chat/chatLogic';
import { useBlobUrl } from '../chat/useBlobUrl';
import { aspectOf } from './attachmentLogic';
import styles from './Attachments.module.css';

export function ImageThumb({ a, onOpen }: { a: AttachmentView; onOpen: () => void }) {
  const { t } = useI18n();
  const { src, failed } = useBlobUrl(a.thumbUrl ?? a.url);
  return (
    <button
      type="button"
      className={styles.thumb}
      style={{ aspectRatio: String(Math.min(Math.max(aspectOf(a), 0.75), 1.8)) }}
      onClick={onOpen}
      aria-label={t('admin.support.att.open', { name: a.name })}
      title={a.name}
    >
      {src && !failed ? (
        <img src={src} alt={a.name} className={styles.thumbImg} loading="lazy" />
      ) : (
        <span className={styles.thumbPlaceholder}>
          <Icon name={failed ? 'imageOff' : 'image'} size={22} />
          <span>{failed ? t('admin.support.att.failed') : t('admin.support.att.loading')}</span>
        </span>
      )}
    </button>
  );
}

export function VideoPlayer({ a }: { a: AttachmentView }) {
  const { t } = useI18n();
  const [active, setActive] = useState(false);
  const poster = useBlobUrl(a.thumbUrl);
  const media = useBlobUrl(active ? a.url : null);
  const dur = formatDuration(a.durationMs);
  if (active) {
    return (
      <div className={styles.video} data-testid="support-video">
        {media.failed ? (
          <p className={styles.videoNote}>{t('admin.support.att.failed')}</p>
        ) : media.src ? (
          <video src={media.src} poster={poster.src ?? undefined} controls autoPlay playsInline preload="metadata" className={styles.videoEl} aria-label={a.name} />
        ) : (
          <div className={styles.videoLoading}>
            <Spinner />
            <span>{t('admin.support.att.videoLoading')}</span>
          </div>
        )}
      </div>
    );
  }
  return (
    <button
      type="button"
      className={`${styles.video} ${styles.videoPoster}`}
      onClick={() => setActive(true)}
      aria-label={t('admin.support.att.play', { name: a.name })}
      title={a.name}
      data-testid="support-video"
    >
      {poster.src && <img src={poster.src} alt="" className={styles.thumbImg} />}
      <span className={styles.playBadge}>
        <Icon name="play" size={22} />
      </span>
      <span className={styles.videoMeta}>
        {dur && <span>{dur}</span>}
        <span>{formatBytes(a.bytes)}</span>
      </span>
    </button>
  );
}

/** Mesaj içindeki ek ızgarası; görsele tıklanınca `onOpenImage(görselin ek kimliği)` çağrılır. */
export function AttachmentGrid({
  attachments,
  onOpenImage,
}: {
  attachments: AttachmentView[];
  onOpenImage: (id: number) => void;
}) {
  const { t } = useI18n();
  if (attachments.length === 0) return null;
  return (
    <ul className={styles.grid} aria-label={t('admin.support.att.list', { n: String(attachments.length) })}>
      {attachments.map((a) => (
        <li key={a.id} className={a.kind === 'VIDEO' ? styles.cellVideo : styles.cell}>
          {a.kind === 'VIDEO' ? <VideoPlayer a={a} /> : <ImageThumb a={a} onOpen={() => onOpenImage(a.id)} />}
        </li>
      ))}
    </ul>
  );
}

/** Büyük görüntüleyici: Esc kapatır, sol/sağ ok tuşları gezinir, odak içeride kalır ve kapanınca tetikleyiciye döner. */
export function AttachmentLightbox({
  items,
  index,
  onIndex,
  onClose,
}: {
  items: AttachmentView[];
  index: number;
  onIndex: (i: number) => void;
  onClose: () => void;
}) {
  const { t, dir } = useI18n();
  const ref = useRef<HTMLDivElement>(null);
  useFocusTrap(ref, true, onClose);
  const item = items[index];
  const { src, failed } = useBlobUrl(item?.url);

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
  return createPortal(
    <div className={styles.lbScrim} onMouseDown={(e) => e.target === e.currentTarget && onClose()}>
      <div ref={ref} role="dialog" aria-modal="true" aria-label={t('admin.support.att.viewer')} tabIndex={-1} className={styles.lb}>
        <div className={styles.lbClose}>
          <IconButton label={t('admin.support.att.close')} onClick={onClose}>
            <Icon name="x" size={20} />
          </IconButton>
        </div>
        <div className={styles.lbStage}>
          <IconButton label={t('admin.support.att.prev')} onClick={() => onIndex(stepIndex(index, -1, items.length))} disabled={index <= 0}>
            <Icon name={dir === 'rtl' ? 'chevronRight' : 'chevronLeft'} size={22} />
          </IconButton>
          <div className={styles.lbMedia} data-testid="support-lightbox">
            {failed ? (
              <p className={styles.lbNote}>{t('admin.support.att.failed')}</p>
            ) : !src ? (
              <Spinner />
            ) : (
              <img src={src} alt={item.name} className={styles.lbImg} />
            )}
          </div>
          <IconButton label={t('admin.support.att.next')} onClick={() => onIndex(stepIndex(index, 1, items.length))} disabled={index >= items.length - 1}>
            <Icon name={dir === 'rtl' ? 'chevronLeft' : 'chevronRight'} size={22} />
          </IconButton>
        </div>
        <div className={styles.lbInfo}>
          <strong dir="auto" className={styles.lbName}>
            {item.name}
          </strong>
          <span className={styles.lbMuted}>
            {formatBytes(item.bytes)}
            {item.width && item.height ? ` · ${item.width}×${item.height}` : ''}
            {' · '}
            {t('admin.support.att.counter', { i: String(index + 1), n: String(items.length) })}
          </span>
        </div>
      </div>
    </div>,
    document.body,
  );
}
