import { useMemo } from 'react';
import { Icon, MarkdownText } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { prepareLegal } from './legalDoc';
import { ReadingToc } from './ReadingToc';
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
  const doc = useMemo(() => prepareLegal(content), [content]);
  return (
    <div className={styles.layout}>
      {doc.toc.length > 1 && (
        <ReadingToc
          items={doc.toc}
          navLabel={t('legal.toc')}
          heading={t('legal.toc')}
          buttonLabel={t('legal.onThisPage')}
          compactBelow={900}
        />
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
