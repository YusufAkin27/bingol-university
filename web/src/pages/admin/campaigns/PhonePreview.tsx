import type { Lang } from '../../../api/types';
import { Logo } from '../../../components/brand/Logo';
import { useI18n } from '../../../i18n/I18nProvider';
import type { LangContent } from './lib';
import styles from './phone.module.css';

/**
 * Telefon kilit ekranı bildirimi önizlemesi. Seçili dilde içerik yoksa Türkçe gösterilir (sunucu da öyle gönderir).
 * Metin yönü bildirimin diline göre (ar: RTL) ayarlanır; panel dilinden bağımsızdır.
 */
export function PhonePreview({
  lang,
  contents,
  system,
}: {
  lang: Lang;
  contents: Record<Lang, LangContent>;
  system: boolean;
}) {
  const { t } = useI18n();
  const own = contents[lang];
  const hasOwn = !!own.title.trim() && !!own.body.trim();
  const shown = hasOwn ? own : contents.tr;
  const shownLang: Lang = hasOwn ? lang : 'tr';
  const empty = !shown.title.trim() && !shown.body.trim();
  const title = empty ? t('admin.campaigns.preview.sampleTitle') : shown.title;
  const body = empty ? t('admin.campaigns.preview.sampleBody') : shown.body;
  const time = new Intl.DateTimeFormat('tr-TR', { hour: '2-digit', minute: '2-digit' }).format(new Date());

  return (
    <figure className={styles.wrap} aria-label={t('admin.campaigns.preview.label', { lang: t(`admin.campaigns.lang.${lang}`) })}>
      <div className={styles.phone}>
        <div className={styles.notch} aria-hidden="true" />
        <div className={styles.screen}>
          <p className={`${styles.clock} ltr`}>{time}</p>
          <div
            className={`${styles.notif} ${empty ? styles.sample : ''}`}
            lang={shownLang}
            dir={shownLang === 'ar' ? 'rtl' : 'ltr'}
            data-testid="phone-notification"
          >
            <div className={styles.notifHead}>
              <span className={styles.appIcon} aria-hidden="true">
                <Logo variant="mark" height={18} decorative />
              </span>
              <span className={styles.appName}>{t('common.appName')}</span>
              <span className={styles.dotSep} aria-hidden="true">
                •
              </span>
              <span className={styles.when}>{t('admin.campaigns.preview.now')}</span>
              {system && <span className={styles.sys}>{t('admin.campaigns.type.SYSTEM')}</span>}
            </div>
            <p className={styles.nTitle}>{title}</p>
            <p className={styles.nBody}>{body}</p>
          </div>
        </div>
      </div>
      {!hasOwn && lang !== 'tr' && (
        <figcaption className={styles.caption}>{t('admin.campaigns.preview.fallbackNote')}</figcaption>
      )}
    </figure>
  );
}
