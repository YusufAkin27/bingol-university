// SAYFA: Yasal metinler (/legal/:type — terms | privacy | kvkk | community-rules)
// API: GET /api/legal/{type} (herkese açık; Accept-Language'e göre, yoksa tr) → api/legal.ts `getLegal`, `parseLegalType`;
//      GET /api/legal/{type}/versions (sürüm geçmişi). Metin <MarkdownText> ile gösterilir (HTML enjekte edilmez).
import { useQuery } from '@tanstack/react-query';
import { useEffect } from 'react';
import { useParams } from 'react-router-dom';
import { Link } from '../../components/LocalizedLink';
import { isApiError } from '../../api/client';
import { LEGAL_TYPES, getLegal, parseLegalType } from '../../api/legal';
import { qk } from '../../api/queryKeys';
import type { LegalType } from '../../api/types';
import { Button, EmptyState, ErrorState, Icon, Skeleton } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { errorMessage } from '../../lib/errors';
import { paths } from '../../paths';
import { AdminAccessNotice } from './components/AdminAccessNotice';
import { LegalDocument } from './components/LegalDocument';
import { listPublicLegalVersions } from './components/legalApi';
import { PageHero } from './components/PageHero';
import { legalRouteId } from '../../seo/routeMeta';
import { usePageMeta } from './components/usePageMeta';
import shared from './components/site.module.css';
import styles from './LegalPage.module.css';
import NotFoundPage from './NotFoundPage';

const TYPES: LegalType[] = [...LEGAL_TYPES];
/** paths.ts'te liste yolu yok; /legal NotFoundPage üzerinden LegalListPage'e düşer (routes.tsx'e dokunulmadı). */
const LEGAL_INDEX = '/legal';

/** `fixedType`: /privacy ve /terms gibi sabit kısa URL'ler aynı bileşeni kullanır (Play/App Store için kalıcı adres). */
export default function LegalPage({ fixedType }: { fixedType?: LegalType } = {}) {
  const { type } = useParams();
  const parsed = fixedType ?? parseLegalType(type);
  if (!parsed) return <NotFoundPage />;
  return <LegalDocPage type={parsed} />;
}

function LegalDocPage({ type }: { type: LegalType }) {
  const i18n = useI18n();
  const { t, lang, formatDate } = i18n;
  const doc = useQuery({ queryKey: qk.legal.doc(type, lang), queryFn: () => getLegal(type) });
  const versions = useQuery({
    queryKey: ['legal', 'public-versions', type, lang],
    queryFn: () => listPublicLegalVersions(type),
  });
  const title = doc.data?.title ?? t(`legal.title.${type}`);
  usePageMeta({ route: legalRouteId(type), title });

  // Yazdırma görünümü: site üst/alt bilgisi gizlenir (LegalPage.module.css)
  useEffect(() => {
    document.documentElement.classList.add('print-doc');
    return () => document.documentElement.classList.remove('print-doc');
  }, []);

  const older = (versions.data ?? []).filter((v) => !doc.data || v.version < doc.data.version);
  const idx = TYPES.indexOf(type);
  const prev = idx > 0 ? TYPES[idx - 1] : null;
  const next = idx >= 0 && idx < TYPES.length - 1 ? TYPES[idx + 1] : null;

  return (
    <>
      <div className={styles.noPrint}>
        <PageHero title={title} crumbs={[{ label: t('legal.allDocs'), to: LEGAL_INDEX }, { label: title }]}>
          {/* Sürüm/tarih/araçlar tek satırda; yüklenirken yer tutulur (CLS) */}
          <div className={styles.meta}>
            {doc.data && (
              <>
                <span className={`${styles.pill} ${styles.pillCurrent}`}>
                  <Icon name="check" size={14} />
                  {t('legal.version', { version: doc.data.version })} · {t('site.rd09.legal.current')}
                </span>
                <span className={styles.pill}>
                  <Icon name="clock" size={14} />
                  {t('legal.publishedAt', { date: formatDate(doc.data.publishedAt) })}
                </span>
              </>
            )}
            <span className={styles.metaTools}>
              <Link to={paths.site.dataRequest} className={styles.toolLink}>
                {t('legal.dataRequest')}
              </Link>
              <Button
                variant="secondary"
                size="md"
                leftIcon={<Icon name="file" size={16} />}
                onClick={() => window.print()}
              >
                {t('legal.print')}
              </Button>
            </span>
          </div>
        </PageHero>
      </div>
      <section className={`${shared.section} ${styles.docSection}`}>
        <div className="container">
          {doc.isLoading && (
            <div className={styles.skeleton} role="status" aria-label={t('common.loading')}>
              {[90, 70, 85, 60, 80, 50].map((w, i) => (
                <Skeleton key={i} height="1.1rem" width={`${w}%`} />
              ))}
            </div>
          )}
          {doc.isError &&
            (isApiError(doc.error) && doc.error.status === 404 ? (
              <EmptyState icon="file" title={t('legal.notFound')} />
            ) : (
              <ErrorState
                title={t('legal.loadError')}
                description={errorMessage(i18n, doc.error)}
                onRetry={() => void doc.refetch()}
              />
            ))}
          {doc.data && (
            <LegalDocument title={doc.data.title} content={doc.data.content} docLang={doc.data.lang} />
          )}

          {(type === 'PRIVACY' || type === 'KVKK') && (
            <div className={styles.notice}>
              <AdminAccessNotice />
            </div>
          )}

          <div className={`${styles.more} ${styles.noPrint}`}>
            <section aria-labelledby="legal-versions" className={styles.history}>
              <h2 id="legal-versions" className={styles.moreTitle}>
                {t('legal.versions')}
              </h2>
              {older.length === 0 ? (
                <p className={shared.muted}>{t('legal.versionsNone')}</p>
              ) : (
                <ul>
                  {older.map((v) => (
                    <li key={`${v.version}-${v.lang}`}>
                      {t('legal.versionRow', { version: v.version, date: formatDate(v.publishedAt) })}
                    </li>
                  ))}
                </ul>
              )}
            </section>
            <nav aria-labelledby="legal-others" className={styles.pager}>
              <h2 id="legal-others" className="sr-only">
                {t('legal.otherDocs')}
              </h2>
              {prev ? (
                <Link to={paths.site.legal(prev)} className={styles.pagerLink} rel="prev">
                  <Icon name="chevronLeft" size={20} className={styles.flip} />
                  <span>
                    <small>{t('site.rd09.legal.prev')}</small>
                    <strong>{t(`legal.title.${prev}`)}</strong>
                  </span>
                </Link>
              ) : (
                <span />
              )}
              {next ? (
                <Link
                  to={paths.site.legal(next)}
                  className={`${styles.pagerLink} ${styles.pagerNext}`}
                  rel="next"
                >
                  <span>
                    <small>{t('site.rd09.legal.next')}</small>
                    <strong>{t(`legal.title.${next}`)}</strong>
                  </span>
                  <Icon name="chevronRight" size={20} className={styles.flip} />
                </Link>
              ) : (
                <span />
              )}
              <Link to={LEGAL_INDEX} className={styles.allLink}>
                {t('legal.allDocs')}
              </Link>
            </nav>
          </div>
        </div>
      </section>
    </>
  );
}
