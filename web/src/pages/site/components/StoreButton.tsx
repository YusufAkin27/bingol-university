import { useId } from 'react';
import { Icon } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import styles from './StoreButton.module.css';

interface Props {
  store: 'android' | 'ios';
  /** Mağaza bağlantısı; yoksa düğme "Yakında" durumundadır ve tıklanamaz. */
  href: string | null | undefined;
  /** Koyu zemin (lacivert bölüm, alt bilgi) üzerinde kullanım. */
  onDark?: boolean;
  /** "Henüz yayınlanmadı" açıklaması görünür olsun mu (varsayılan evet); kapalıyken yalnız ekran okuyucuya gider. */
  note?: boolean;
}

/**
 * Sitenin tek mağaza düğmesi (alt bilgi, ana sayfa, indirme ve özellikler sayfaları bunu kullanır).
 *
 * YAYIN ÖNCESİ NOT: Resmî Google Play / App Store rozet görselleri (marka kuralları gereği değiştirilmeden,
 * kendi indirme sayfalarından alınmış SVG) bu ortamda indirilemediği için rozet benzeri, nötr bir düğme çiziyoruz:
 * simge + "Yakında" / "Şuradan indirin" + mağaza adı. Mağaza bağlantıları yayınlandığında bu bileşenin gövdesi
 * resmî rozet SVG'siyle değiştirilmelidir (props ve çağıran sayfalar aynı kalır). Bkz. web/README.md "Mağaza rozetleri".
 */
export function StoreButton({ store, href, onDark, note = true }: Props) {
  const { t } = useI18n();
  const noteId = useId();
  const name = store === 'android' ? t('site.store.googlePlay') : t('site.store.appStore');
  const top = href
    ? store === 'android'
      ? t('site.store.getItOn')
      : t('site.store.downloadOn')
    : t('site.store.soon');
  const body = (
    <>
      <Icon name={store === 'android' ? 'play' : 'apple'} size={28} className={styles.glyph} />
      <span className={styles.label}>
        <span className={styles.top}>{top}</span>
        <span className={styles.main}>{name}</span>
      </span>
    </>
  );
  const cls = `${styles.btn} ${onDark ? styles.onDark : ''}`;
  const noteText = href ? t('site.store.newTab') : t('site.store.soonNote');
  const noteEl = (
    <span id={noteId} className={href || !note ? 'sr-only' : `${styles.note} ${onDark ? styles.noteOnDark : ''}`}>
      {noteText}
    </span>
  );
  return (
    <span className={styles.wrap}>
      {href ? (
        <a className={cls} href={href} target="_blank" rel="noopener noreferrer" aria-describedby={noteId}>
          {body}
        </a>
      ) : (
        <button type="button" className={`${cls} ${styles.soon}`} aria-disabled="true" aria-describedby={noteId}>
          {body}
        </button>
      )}
      {noteEl}
    </span>
  );
}
