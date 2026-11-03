import { useId, useMemo, useState } from 'react';
import { Icon, MarkdownText } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { useMediaQuery } from '../../../lib/useMediaQuery';
import { prepareLegal } from './legalDoc';
import { useActiveSection } from './useActiveSection';
import styles from './LegalDocument.module.css';

interface Props {
  title: string;
  content: string;
  /** Belgenin gerçek dili; seçili dilden farklıysa bilgi notu gösterilir. */
  docLang: string;
}

/**
 * Başlıklardan içindekiler üretir; metni MarkdownText ile (HTML enjekte etmeden) gösterir.
 * İçindekiler: masaüstünde yapışkan yan sütun, mobilde açılır "Bu sayfada" menüsü.
 */
export function LegalDocument({ title, content, docLang }: Props) {
  const { t, lang } = useI18n();
  const doc = useMemo(() => {
    const d = prepareLegal(content);
    // Metnin ilk başlığı belge adının tekrarıysa (sayfa başlığı zaten h1): yalnız sunumda gizlenir, içerik değişmez.
    const first = d.sections[0];
    const same =
      !!first?.title && first.title.trim().toLocaleLowerCase('tr') === title.trim().toLocaleLowerCase('tr');
    return {
      sections: same ? d.sections.map((x, i) => (i === 0 ? { ...x, title: null } : x)) : d.sections,
      toc: same ? d.toc.filter((e) => e.id !== first.id) : d.toc,
    };
  }, [content, title]);
  const minutes = useMemo(
    () => Math.max(1, Math.ceil(content.split(/\s+/).filter(Boolean).length / 200)),
    [content],
  );
  const active = useActiveSection(doc.toc.map((e) => e.id));
  const compact = useMediaQuery('(max-width: 900px)');
  const [open, setOpen] = useState(false);
  const panelId = useId();
  const links = (
    <ol>
      {doc.toc.map((e) => (
        <li key={e.id}>
          <a
            href={`#${e.id}`}
            onClick={() => setOpen(false)}
            className={active === e.id ? styles.tocActive : undefined}
            aria-current={active === e.id ? 'location' : undefined}
          >
            {e.title}
          </a>
        </li>
      ))}
    </ol>
  );
  return (
    <div className={styles.layout}>
      {doc.toc.length > 1 &&
        (compact ? (
          <nav className={`${styles.toc} ${styles.tocCompact}`} aria-label={t('legal.toc')}>
            <button
              type="button"
              className={styles.tocBtn}
              aria-expanded={open}
              aria-controls={panelId}
              onClick={() => setOpen((v) => !v)}
            >
              <span>{t('legal.onThisPage')}</span>
              <Icon
                name="chevronDown"
                size={20}
                className={`${styles.chev} ${open ? styles.chevOpen : ''}`}
              />
            </button>
            <div id={panelId} hidden={!open} className={styles.tocPanel}>
              {links}
            </div>
          </nav>
        ) : (
          <nav className={styles.toc} aria-label={t('legal.toc')}>
            <h2 className={styles.tocTitle}>{t('legal.toc')}</h2>
            {links}
            <p className={styles.tocMeta}>
              {t('site.rd09.legal.sections', { n: String(doc.toc.length) })} ·{' '}
              {t('site.rd09.legal.readTime', { n: String(minutes) })}
            </p>
          </nav>
        ))}
      <article className={styles.article} lang={docLang}>
        <h2 className={styles.printTitle}>{title}</h2>
        {docLang !== lang && (
          <div className={styles.note} role="note" lang={lang}>
            <Icon name="globe" size={20} />
            <p>{t('legal.fallbackLang')}</p>
          </div>
        )}
        {doc.sections.map((s, i) => (
          <section key={s.id ?? `intro-${i}`} aria-labelledby={s.title ? (s.id ?? undefined) : undefined}>
            {s.title &&
              (s.level === 2 ? (
                <h2 id={s.id ?? undefined} className={styles.h2}>
                  {s.title}
                </h2>
              ) : (
                <h3 id={s.id ?? undefined} className={styles.h3}>
                  {s.title}
                </h3>
              ))}
            {s.body && <MarkdownText text={s.body} className={styles.md} />}
          </section>
        ))}
      </article>
    </div>
  );
}
