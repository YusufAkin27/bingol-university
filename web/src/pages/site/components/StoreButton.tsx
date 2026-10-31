import { useId } from 'react';
import { useI18n } from '../../../i18n/I18nProvider';
import { AppleIcon, GooglePlayIcon } from './StoreIcons';
import styles from './StoreButton.module.css';

interface Props {
  store: 'android' | 'ios';
  /**
   * Mağaza bağlantısı (`useStoreLinks()`; sunucudaki store_url_android / store_url_ios ayarı).
   * Boşsa rozet TIKLANAMAZ ve "Yakında" gösterir. Buraya ASLA uydurma/yer tutucu adres yazılmaz.
   */
  href: string | null | undefined;
  /** `solid` (varsayılan): koyu rozet; `outline`: yüzey zeminli, ince çerçeveli açık rozet. */
  variant?: 'solid' | 'outline';
  /** Eski ad: koyu zemin üzerinde beyaz rozet (`variant` yerine). */
  onDark?: boolean;
  /** `lg` hero ve CTA için biraz büyük rozet. */
  size?: 'md' | 'lg';
  /** "Henüz yayınlanmadı" açıklaması görünür olsun mu (varsayılan evet); kapalıyken yalnız ekran okuyucuya gider. */
  note?: boolean;
}

/**
 * Sitenin TEK mağaza düğmesi: Google Play / App Store marka simgesi + "Şuradan edinin / Google Play" metni (tr/en/ar).
 * Bağlantı varsa yeni sekmede açılan gerçek bir <a>; yoksa devre dışı <button aria-disabled> + "Yakında" etiketi.
 * Alt bilgideki `StoreBadge` bunun ince bir ön ayarıdır.
 *
 * NOT: Resmî rozet SVG'leri marka kuralları gereği kendi mağaza sayfalarından alınmalıdır; mağazalar yayınlanınca
 * `body` bölümü onlarla değiştirilebilir (props ve çağıran sayfalar aynı kalır).
 */
export function StoreButton({ store, href, variant = 'solid', onDark, size = 'md', note = true }: Props) {
  const { t } = useI18n();
  const noteId = useId();
  const android = store === 'android';
  const name = android ? t('site.store.googlePlay') : t('site.store.appStore');
  const top = href ? (android ? t('site.store.getItOn') : t('site.store.downloadOn')) : t('site.store.soon');
  const Glyph = android ? GooglePlayIcon : AppleIcon;
  const body = (
    <>
      <Glyph className={styles.glyph} />
      <span className={styles.label}>
        <span className={styles.top}>{top}</span>
        <span className={styles.main}>{name}</span>
      </span>
    </>
  );
  const kind = onDark ? styles.inverse : variant === 'outline' ? styles.outline : '';
  const cls = [styles.btn, kind, size === 'lg' ? styles.lg : ''].filter(Boolean).join(' ');
  const visibleNote = !href && note;
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
      <span id={noteId} className={visibleNote ? styles.note : 'sr-only'}>
        {href ? t('site.store.newTab') : t('site.store.soonNote')}
      </span>
    </span>
  );
}
