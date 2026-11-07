import { useLocation, useNavigate } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import { LANGS, type Lang } from '../i18n/lang';
import { splitLangPath, switchLangPath } from '../i18n/langPath';
import { Icon } from './ui/Icon';
import styles from './LanguageSwitcher.module.css';

/**
 * Dil değiştirme eylemi: dil önekli sayfada URL'deki dil değişir (/tr/privacy → /en/privacy; `bu.lang` LangScope
 * tarafından güncellenir); önekli olmayan yerde doğrudan dil durumu yazılır.
 */
export function useChangeLang() {
  const { setLang } = useI18n();
  const location = useLocation();
  const navigate = useNavigate();
  return (next: Lang) => {
    if (splitLangPath(location.pathname).lang) {
      navigate(switchLangPath(`${location.pathname}${location.search}${location.hash}`, next));
    } else {
      setLang(next);
    }
  };
}

/**
 * Dil seçici: yerel `<select>` (klavye ve ekran okuyucu uyumlu), kenarlıklı hap görünümünde küre + kısa kod + ok.
 */
export function LanguageSwitcher({ compact }: { compact?: boolean }) {
  const { lang, t } = useI18n();
  const change = useChangeLang();
  return (
    <label className={`${styles.wrap} ${compact ? styles.wrapCompact : ''}`}>
      <span className="sr-only">{t('common.language')}</span>
      <Icon name="globe" size={18} />
      {/* görünen kısa dil kodu; yerel <select> kaplamanın üstüne saydam biner, dokunulabilir kalır */}
      <span className={styles.code} aria-hidden="true">
        {lang}
      </span>
      <Icon name="chevronDown" size={16} className={styles.chev} />
      <select
        className={styles.select}
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

/** Mobil çekmece için üç düğmeli dil seçici (TR / EN / AR). */
export function LanguageSegmented() {
  const { lang, t } = useI18n();
  const change = useChangeLang();
  return (
    <div role="group" aria-label={t('common.language')} className={styles.seg}>
      {LANGS.map((l) => (
        <button
          key={l.code}
          type="button"
          lang={l.code}
          className={`${styles.segBtn} ${l.code === lang ? styles.segOn : ''}`}
          aria-pressed={l.code === lang}
          aria-label={l.label}
          onClick={() => change(l.code)}
        >
          {l.code.toUpperCase()}
        </button>
      ))}
    </div>
  );
}
