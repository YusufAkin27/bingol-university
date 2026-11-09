import { useEffect, useId, useRef, useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import { LANGS, type Lang } from '../i18n/lang';
import { splitLangPath, switchLangPath } from '../i18n/langPath';
import { Icon } from './ui/Icon';
import styles from './LanguageSwitcher.module.css';

/**
 * Dil seçici: düğme + açılır liste (listbox). Seçenekler kendi dilinde yazılır (Türkçe / English / العربية),
 * seçili olan onay işaretiyle belirtilir. Klavye: Enter/Space/Aşağı açar; Yukarı/Aşağı/Home/End gezer; Esc kapatır ve odağı düğmeye verir.
 * Dil önekli sayfada URL'deki dil değişir (/tr/privacy → /en/privacy; `bu.lang` LangScope tarafından güncellenir);
 * önekli olmayan yerde doğrudan dil durumu yazılır.
 */
export function LanguageSwitcher({ compact }: { compact?: boolean }) {
  const { lang, setLang, t } = useI18n();
  const location = useLocation();
  const navigate = useNavigate();
  const [open, setOpen] = useState(false);
  const wrap = useRef<HTMLDivElement>(null);
  const btn = useRef<HTMLButtonElement>(null);
  const listId = useId();
  const current = LANGS.find((l) => l.code === lang) ?? LANGS[0];

  const change = (next: Lang) => {
    if (splitLangPath(location.pathname).lang) {
      navigate(switchLangPath(`${location.pathname}${location.search}${location.hash}`, next));
    } else {
      setLang(next);
    }
  };

  const options = () => Array.from(wrap.current?.querySelectorAll<HTMLElement>('[role="option"]') ?? []);

  // açılınca seçili (yoksa ilk) seçeneğe odaklan
  useEffect(() => {
    if (!open) return;
    const opts = options();
    (opts.find((o) => o.getAttribute('aria-selected') === 'true') ?? opts[0])?.focus();
    const onDown = (e: MouseEvent) => {
      if (wrap.current && !wrap.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener('mousedown', onDown);
    return () => document.removeEventListener('mousedown', onDown);
  }, [open]);

  const pick = (code: Lang) => {
    setOpen(false);
    btn.current?.focus();
    if (code !== lang) change(code);
  };

  const onListKey = (e: React.KeyboardEvent) => {
    const opts = options();
    const i = opts.indexOf(document.activeElement as HTMLElement);
    const go = (n: number) => {
      e.preventDefault();
      opts[(n + opts.length) % opts.length]?.focus();
    };
    if (e.key === 'ArrowDown') go(i + 1);
    else if (e.key === 'ArrowUp') go(i - 1);
    else if (e.key === 'Home') go(0);
    else if (e.key === 'End') go(opts.length - 1);
    else if (e.key === 'Escape') {
      e.preventDefault();
      setOpen(false);
      btn.current?.focus();
    }
  };

  return (
    <div
      className={styles.wrap}
      ref={wrap}
      onBlur={(e) => {
        // odak bileşenin dışına çıkınca kapat (Tab ile ayrılma)
        if (open && !e.currentTarget.contains(e.relatedTarget as Node | null)) setOpen(false);
      }}
    >
      <button
        ref={btn}
        type="button"
        className={styles.trigger}
        aria-haspopup="listbox"
        aria-expanded={open}
        aria-controls={open ? listId : undefined}
        aria-label={`${t('common.language')}: ${current.label}`}
        onClick={() => setOpen((v) => !v)}
        onKeyDown={(e) => {
          if (e.key === 'ArrowDown' && !open) {
            e.preventDefault();
            setOpen(true);
          }
        }}
      >
        <Icon name="globe" size={18} />
        <span className={`${styles.label} ${compact ? styles.labelCompact : ''}`} lang={current.code} aria-hidden="true">
          {current.label}
        </span>
        <span className={styles.code} aria-hidden="true">
          {current.code}
        </span>
        <Icon name="chevronDown" size={16} className={styles.chev} />
      </button>
      {open && (
        <div id={listId} role="listbox" aria-label={t('common.language')} className={styles.menu} onKeyDown={onListKey}>
          {LANGS.map((l) => {
            const selected = l.code === lang;
            return (
              <button
                key={l.code}
                type="button"
                role="option"
                aria-selected={selected}
                tabIndex={-1}
                lang={l.code}
                dir={l.dir}
                className={styles.option}
                onClick={() => pick(l.code)}
              >
                <span>{l.label}</span>
                {selected && <Icon name="check" size={18} className={styles.tick} />}
              </button>
            );
          })}
        </div>
      )}
    </div>
  );
}

/** Dil değiştirme eylemi (düğme/segment bileşenleri için): önekli sayfada URL'deki dil değişir. */
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
