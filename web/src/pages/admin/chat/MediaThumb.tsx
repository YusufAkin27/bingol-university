// Ek küçük resmi: tür/tek gönderimlik/silinmiş/saklama süresi rozetleri; tıklayınca büyük görüntüleyici açılır.
import { Badge } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { formatDuration, type LightboxItem } from './chatLogic';
import { useBlobUrl } from './useBlobUrl';
import styles from './chat.module.css';

export function MediaBadges({ item }: { item: LightboxItem }) {
  const { t } = useI18n();
  return (
    <span className={styles.badges}>
      {item.viewOnce && (
        <Badge tone="warning">
          <span data-testid="viewonce-badge">{t('admin.chat.media.viewOnce')}</span>
        </Badge>
      )}
      {item.kind === 'VIDEO' && (
        <Badge tone="info">
          {t('admin.chat.media.video')}
          {item.durationMs != null ? ` ${formatDuration(item.durationMs)}` : ''}
        </Badge>
      )}
      {item.messageDeleted && <Badge tone="danger">{t('admin.chat.badge.deleted')}</Badge>}
      {item.purged && (
        <Badge tone="neutral">
          <span data-testid="purged-badge">{t('admin.chat.media.purged')}</span>
        </Badge>
      )}
      {item.hidden && <Badge tone="warning">{t('admin.chat.badge.hidden')}</Badge>}
      {item.suppressed && <Badge tone="warning">{t('admin.chat.badge.suppressedShort')}</Badge>}
    </span>
  );
}

/** Tek gönderimlik medya için "Açan: …" satırı. */
export function ViewedByLine({ item }: { item: LightboxItem }) {
  const { t, formatDateTime } = useI18n();
  if (!item.viewOnce) return null;
  return (
    <span className={styles.muted} data-testid="viewed-by">
      {item.viewedBy.length === 0
        ? t('admin.chat.media.notViewed')
        : t('admin.chat.media.viewedBy', {
            names: item.viewedBy.map((v) => `${v.displayName ?? `#${v.id}`} (${formatDateTime(v.at)})`).join(', '),
          })}
    </span>
  );
}

export function MediaThumb({
  item,
  onOpen,
  tile,
}: {
  item: LightboxItem;
  onOpen: () => void;
  /** true: ızgara karesi (kare, kırpılır); false: sohbet içi küçük resim. */
  tile?: boolean;
}) {
  const { t } = useI18n();
  const { src, failed } = useBlobUrl(item.purged ? null : (item.thumbUrl ?? item.previewUrl));
  const label = item.kind === 'VIDEO' ? t('admin.chat.media.video') : t('admin.chat.image');
  return (
    <figure className={tile ? styles.tile : styles.attachment} data-testid="chat-attachment">
      <button
        type="button"
        className={tile ? styles.tileBtn : styles.thumbBtn}
        onClick={onOpen}
        aria-label={`${t('admin.chat.media.open')}: ${label}`}
      >
        {src && !failed ? (
          <img src={src} alt={label} className={tile ? styles.tileImg : styles.imgThumb} loading="lazy" />
        ) : (
          <span className={tile ? styles.tilePlaceholder : styles.placeholder}>
            {item.purged ? t('admin.chat.media.purged') : failed ? t('admin.chat.imageFailed') : label}
          </span>
        )}
      </button>
      {!tile && <MediaBadges item={item} />}
      {!tile && <ViewedByLine item={item} />}
    </figure>
  );
}
