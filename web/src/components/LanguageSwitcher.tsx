import { useLocation, useNavigate } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import { LANGS, type Lang } from '../i18n/lang';
import { splitLangPath, switchLangPath } from '../i18n/langPath';
import { Icon } from './ui/Icon';
import styles from './LanguageSwitcher.module.css';

/**
 * Dil seçici: yerel `<select>` (klavye ve ekran okuyucu uyumlu). Dil önekli sayfada URL'deki dil değişir
 * (/tr/privacy → /en/privacy; `bu.lang` LangScope tarafından güncellenir); önekli olmayan yerde doğrudan dil durumu yazılır.
 */
export function LanguageSwitcher({ compact }: { compact?: boolean }) {
  const { lang, setLang, t } = useI18n();
  const location = useLocation();
  const navigate = useNavigate();
  const change = (next: Lang) => {
    if (splitLangPath(location.pathname).lang) {
      navigate(switchLangPath(`${location.pathname}${location.search}${location.hash}`, next));
    } else {
      setLang(next);
    }
  };
  return (
    <label className={`${styles.wrap} ${compact ? styles.wrapCompact : ''}`}>
      <span className="sr-only">{t('common.language')}</span>
      <Icon name="globe" size={18} />
      {/* dar ekranda dil adı yerine kısa kod görünür; yerel <select> görünmez ama dokunulabilir kalır */}
      {compact && (
        <span className={styles.code} aria-hidden="true">
          {lang}
        </span>
      )}
      <select
        className={`${styles.select} ${compact ? styles.compact : ''}`}
        value={lang}
        onChange={(e) => change(e.target.value as Lang)}
      >
        {LANGS.map((l) => (
          <option key={l.code} value={l.code} lang={l.code}>
            {l.label}
          </option>
        ))}
      </select>
    </label>
  );
}
