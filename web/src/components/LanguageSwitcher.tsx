import { useI18n } from '../i18n/I18nProvider';
import { LANGS, type Lang } from '../i18n/lang';
import { Icon } from './ui/Icon';
import styles from './LanguageSwitcher.module.css';

/** Dil seçici: yerel `<select>` (klavye ve ekran okuyucu uyumlu). Seçim localStorage'a yazılır. */
export function LanguageSwitcher({ compact }: { compact?: boolean }) {
  const { lang, setLang, t } = useI18n();
  return (
    <label className={styles.wrap}>
      <span className="sr-only">{t('common.language')}</span>
      <Icon name="globe" size={18} />
      <select
        className={`${styles.select} ${compact ? styles.compact : ''}`}
        value={lang}
        onChange={(e) => setLang(e.target.value as Lang)}
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
