// SAYFA: Sık sorulan sorular (/faq)
// API: GET /api/faq (herkese açık, kategoriye göre gruplu, Accept-Language'e göre) → api/faq.ts `listFaq`, qk.faq.public(lang).
import { useQuery } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { listFaq } from '../../api/faq';
import { qk } from '../../api/queryKeys';
import { Button, ButtonLink, EmptyState, ErrorState, Icon, Skeleton } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { errorMessage } from '../../lib/errors';
import { paths } from '../../paths';
import { FaqAccordion } from './components/FaqAccordion';
import { countFaq, filterFaq } from './components/faqFilter';
import { buildNewFaq } from './components/newFaq';
import { PageHero } from './components/PageHero';
import { usePageMeta } from './components/usePageMeta';
import shared from './components/site.module.css';
import styles from './FaqPage.module.css';

export default function FaqPage() {
  const i18n = useI18n();
  const { t, lang } = i18n;
  const [query, setQuery] = useState('');
  usePageMeta({ route: 'faq' });
  const faq = useQuery({ queryKey: qk.faq.public(lang), queryFn: listFaq });
  const groups = useMemo(() => filterFaq(faq.data ?? [], query), [faq.data, query]);
  const total = countFaq(faq.data ?? []);
  const shown = countFaq(groups);

  return (
    <>
      <PageHero title={t('site.faq.title')} lead={t('site.faq.lead')} />
      <section className={`${shared.section} ${shared.sectionTop}`}>
        <div className={`container ${styles.wrap}`}>
          {faq.isLoading && (
            <div className={styles.skeletons} role="status" aria-label={t('common.loading')}>
              {[0, 1, 2, 3, 4].map((i) => (
                <Skeleton key={i} height="3.2rem" radius="8px" />
              ))}
            </div>
          )}
          {faq.isError && (
            <ErrorState
              description={errorMessage(i18n, faq.error)}
              onRetry={() => void faq.refetch()}
            />
          )}
          {faq.isSuccess && total === 0 && (
            <EmptyState
              icon="help"
              title={t('site.faq.none')}
              description={t('site.faq.noneHint')}
              action={<ButtonLink to={paths.site.contact}>{t('site.faq.stillLink')}</ButtonLink>}
            />
          )}
          {faq.isSuccess && total > 0 && (
            <>
              <div className={styles.search}>
                <label htmlFor="faq-search" className="sr-only">
                  {t('site.faq.searchLabel')}
                </label>
                <span className={styles.searchIcon} aria-hidden="true">
                  <Icon name="search" size={20} />
                </span>
                <input
                  id="faq-search"
                  type="search"
                  className={styles.input}
                  value={query}
                  placeholder={t('site.faq.searchPlaceholder')}
                  onChange={(e) => setQuery(e.target.value)}
                />
                {query && (
                  <button
                    type="button"
                    className={styles.clear}
                    aria-label={t('site.faq.clear')}
                    onClick={() => setQuery('')}
                  >
                    <Icon name="x" size={16} />
                  </button>
                )}
              </div>
              <p className={styles.count} role="status" aria-live="polite">
                {t('site.faq.count', { count: shown })}
              </p>
              {shown === 0 ? (
                <EmptyState
                  icon="search"
                  title={t('site.faq.empty')}
                  description={t('site.faq.emptyHint')}
                  action={
                    <Button variant="secondary" onClick={() => setQuery('')}>
                      {t('site.faq.clear')}
                    </Button>
                  }
                />
              ) : (
                groups.map((g) => (
                  <section key={g.category} className={styles.group} aria-label={g.category}>
                    <h2 className={shared.h3}>{g.category}</h2>
                    <FaqAccordion items={g.items} />
                  </section>
                ))
              )}
              <aside className={styles.still}>
                <h2 className={shared.h3}>{t('site.faq.stillTitle')}</h2>
                <p className={shared.muted}>{t('site.faq.stillText')}</p>
                <ButtonLink to={paths.site.contact} variant="secondary">
                  {t('site.faq.stillLink')}
                </ButtonLink>
              </aside>
            </>
          )}
          <section className={styles.group} aria-labelledby="faq-new-title" data-testid="faq-new">
            <h2 id="faq-new-title" className={shared.h3}>
              {t('site.faq.new.title')}
            </h2>
            <FaqAccordion items={buildNewFaq(t)} />
          </section>
        </div>
      </section>
    </>
  );
}
