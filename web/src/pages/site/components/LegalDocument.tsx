import { useMemo } from 'react';
import { Icon, MarkdownText } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { prepareLegal } from './legalDoc';
import styles from './LegalDocument.module.css';

interface Props {
  title: string;
  content: string;
  /** Belgenin gerçek dili; seçili dilden farklıysa bilgi notu gösterilir. */
  docLang: string;
}

/** Başlıklardan içindekiler üretir; metni MarkdownText ile (HTML enjekte etmeden) gösterir. */
export function LegalDocument({ title, content, docLang }: Props) {
  const { t, lang } = useI18n();
  const doc = useMemo(() => prepareLegal(content), [content]);
  return (
    <div className={styles.layout}>
      {doc.toc.length > 1 && (
        <nav className={styles.toc} aria-label={t('legal.toc')}>
          <h2 className={styles.tocTitle}>{t('legal.toc')}</h2>
          <ol>
            {doc.toc.map((e) => (
              <li key={e.id}>
                <a href={`#${e.id}`}>{e.title}</a>
              </li>
            ))}
          </ol>
        </nav>
      )}
      <article className={styles.article} lang={docLang}>
        <h2 className={styles.printTitle}>{title}</h2>
        {docLang !== lang && (
          <div className={styles.note} role="note" lang={lang}>
            <Icon name="globe" size={20} />
            <p>{t('legal.fallbackLang')}</p>
          </div>
        )}
        {doc.sections.map((s, i) => (
          <section key={s.id ?? `intro-${i}`} aria-labelledby={s.id ?? undefined}>
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
