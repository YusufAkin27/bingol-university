// SAYFA: Sık sorulan sorular (/faq)
// API: GET /api/faq (herkese açık, kategoriye göre gruplu, Accept-Language'e göre) → api/faq.ts `listFaq`, qk.faq.public(lang).
import { useQuery } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { listFaq } from '../../api/faq';
import { qk } from '../../api/queryKeys';
import { Link } from '../../components/LocalizedLink';
import { Button, ButtonLink, EmptyState, ErrorState, Icon, Skeleton } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { errorMessage } from '../../lib/errors';
import { paths } from '../../paths';
import { CtaBand } from './components/CtaBand';
import { FaqAccordion } from './components/FaqAccordion';
import { countFaq, filterFaq } from './components/faqFilter';
import { buildNewFaq } from './components/newFaq';
import { PageHero } from './components/PageHero';
import { PhoneMockup } from './components/PhoneMockup';
import { usePageMeta } from './components/usePageMeta';
import shared from './components/site.module.css';
import styles from './FaqPage.module.css';

const RESOURCES = [
  { to: paths.site.privacy, label: 'site.rd06.faq.res.privacy' },
  { to: paths.site.guidelines, label: 'site.rd06.faq.res.guidelines' },
  { to: paths.site.security, label: 'site.rd06.faq.res.security' },
  { to: paths.site.dataRequest, label: 'site.rd06.faq.res.data' },
] as const;

export default function FaqPage() {
  const i18n = useI18n();
  const { t, lang } = i18n;
  // Yardım merkezi araması `?q=` ile gelir; yalnız ilk değer olarak okunur
  const [params] = useSearchParams();
  const [query, setQuery] = useState(() => params.get('q')?.slice(0, 120) ?? '');
  const [cat, setCat] = useState<string | null>(null);
  usePageMeta({ route: 'faq' });
  const faq = useQuery({ queryKey: qk.faq.public(lang), queryFn: listFaq });
  const categories = useMemo(() => (faq.data ?? []).map((g) => g.category), [faq.data]);
  const activeCat = cat !== null && categories.includes(cat) ? cat : null;
  const groups = useMemo(
    () => filterFaq((faq.data ?? []).filter((g) => activeCat === null || g.category === activeCat), query),
    [faq.data, query, activeCat],
  );
  const total = countFaq(faq.data ?? []);
  const shown = countFaq(groups);

  return (
    <>
      <PageHero eyebrow={t('site.v3.eyebrow')} title={t('site.faq.title')} lead={t('site.faq.lead')} />
      <section className={`${shared.section} ${shared.sectionTop}`}>
        <div className={`container ${styles.layout}`}>
          <div className={styles.wrap}>
            {/* Statik bölüm ÜSTTE: API'den gelen dinamik liste (iskelet -> veri) sayfanın altında büyür, üstündeki içerik kaymaz (CLS, A3-11) */}
            <section className={styles.group} aria-labelledby="faq-new-title" data-testid="faq-new">
              <h2 id="faq-new-title" className={styles.groupTitle}>
                {t('site.faq.new.title')}
              </h2>
              <FaqAccordion items={buildNewFaq(t)} />
            </section>
            {faq.isLoading && (
              <div className={styles.skeletons} role="status" aria-label={t('common.loading')}>
                {[0, 1, 2, 3, 4].map((i) => (
                  <Skeleton key={i} height="3.2rem" radius="8px" />
                ))}
              </div>
            )}
            {faq.isError && (
              <ErrorState description={errorMessage(i18n, faq.error)} onRetry={() => void faq.refetch()} />
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
                {categories.length > 1 && (
                  <div className={styles.chips} role="group" aria-label={t('site.rd06.faq.filterLabel')}>
                    {[null, ...categories].map((c) => (
                      <button
                        key={c ?? '__all'}
                        type="button"
                        className={`${styles.chip} ${activeCat === c ? styles.chipOn : ''}`}
                        aria-pressed={activeCat === c}
                        onClick={() => setCat(c)}
                      >
                        {c ?? t('site.rd06.faq.all')}
                      </button>
                    ))}
                  </div>
                )}
                <p className={styles.count} role="status" aria-live="polite">
                  {t('site.faq.count', { count: shown })}
                </p>
                {shown === 0 ? (
                  <EmptyState
                    icon="search"
                    title={t('site.faq.empty')}
                    description={t('site.faq.emptyHint')}
                    action={
                      <Button
                        variant="secondary"
                        onClick={() => {
                          setQuery('');
                          setCat(null);
                        }}
                      >
                        {t('site.faq.clear')}
                      </Button>
                    }
                  />
                ) : (
                  groups.map((g) => (
                    <section key={g.category} className={styles.group} aria-label={g.category}>
                      <h2 className={styles.groupTitle}>{g.category}</h2>
                      <FaqAccordion items={g.items} />
                    </section>
                  ))
                )}
              </>
            )}
          </div>
          <aside className={styles.side}>
            <div className={styles.still}>
              <span className={styles.stillIcon} aria-hidden="true">
                <Icon name="lifebuoy" size={22} />
              </span>
              <h2 className={styles.stillTitle}>{t('site.faq.stillTitle')}</h2>
              <p className={shared.muted}>{t('site.faq.stillText')}</p>
              <ButtonLink to={paths.site.contact} fullWidth>
                {t('site.faq.stillLink')}
              </ButtonLink>
            </div>
            <nav className={styles.res} aria-label={t('site.rd06.faq.resTitle')}>
              <h2 className={styles.resTitle}>{t('site.rd06.faq.resTitle')}</h2>
              <ul>
                {RESOURCES.map((r) => (
                  <li key={r.to}>
                    <Link to={r.to} className={styles.resLink}>
                      {t(r.label)}
                      <Icon name="chevronRight" size={18} className={styles.resIcon} />
                    </Link>
                  </li>
                ))}
              </ul>
            </nav>
            <div className={styles.phone}>
              <PhoneMockup shot="support" width="240px" crop={0.78} tilt={3} />
            </div>
          </aside>

        </div>
      </section>
      <CtaBand title={t('site.home.ctaTitle')} text={t('site.v3.cta.text')} />
    </>
  );
}
