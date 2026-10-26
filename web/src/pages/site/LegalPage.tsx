// SAYFA: Yasal metinler (/legal/:type — terms | privacy | kvkk | community-rules)
// API: GET /api/legal/{type} (herkese açık; Accept-Language'e göre, yoksa tr) → api/legal.ts `getLegal`, `parseLegalType`;
//      GET /api/legal/{type}/versions (sürüm geçmişi). Metin <MarkdownText> ile gösterilir (HTML enjekte edilmez).
import { useQuery } from '@tanstack/react-query';
import { useEffect } from 'react';
import { Link, useParams } from 'react-router-dom';
import { isApiError } from '../../api/client';
import { getLegal, parseLegalType } from '../../api/legal';
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
import { usePageMeta } from './components/usePageMeta';
import shared from './components/site.module.css';
import styles from './LegalPage.module.css';
import NotFoundPage from './NotFoundPage';

const TYPES: LegalType[] = ['TERMS', 'PRIVACY', 'KVKK', 'COMMUNITY_RULES'];
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
  usePageMeta({
    title,
    description: t('site.meta.legal'),
    path: type === 'PRIVACY' ? paths.site.privacy : type === 'TERMS' ? paths.site.terms : paths.site.legal(type),
  });

  // Yazdırma görünümü: site üst/alt bilgisi gizlenir (LegalPage.module.css)
  useEffect(() => {
    document.documentElement.classList.add('print-doc');
    return () => document.documentElement.classList.remove('print-doc');
  }, []);

  const lead = doc.data
    ? `${t('legal.version', { version: doc.data.version })}, ${t('legal.publishedAt', {
        date: formatDate(doc.data.publishedAt),
      })}`
    : undefined;
  const older = (versions.data ?? []).filter((v) => !doc.data || v.version < doc.data.version);

  return (
    <>
      <div className={styles.noPrint}>
        <PageHero
          title={title}
          lead={lead}
          crumbs={[{ label: t('legal.allDocs'), to: LEGAL_INDEX }, { label: title }]}
        />
      </div>
      <section className={`${shared.section} ${shared.sectionTop}`}>
        <div className="container">
          <div className={`${styles.tools} ${styles.noPrint}`}>
            <Link to={paths.site.dataRequest} className={styles.toolLink}>
              {t('legal.dataRequest')}
            </Link>
            <Button
              variant="secondary"
              size="sm"
              leftIcon={<Icon name="file" size={16} />}
              onClick={() => window.print()}
            >
              {t('legal.print')}
            </Button>
          </div>

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
          {doc.data && <LegalDocument title={doc.data.title} content={doc.data.content} docLang={doc.data.lang} />}

          {(type === 'PRIVACY' || type === 'KVKK') && <AdminAccessNotice />}

          <div className={`${styles.more} ${styles.noPrint}`}>
            <section aria-labelledby="legal-versions">
              <h2 id="legal-versions" className={shared.h3}>
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
            <nav aria-labelledby="legal-others">
              <h2 id="legal-others" className={shared.h3}>
                {t('legal.otherDocs')}
              </h2>
              <ul>
                {TYPES.filter((x) => x !== type).map((x) => (
                  <li key={x}>
                    <Link to={paths.site.legal(x)}>{t(`legal.title.${x}`)}</Link>
                  </li>
                ))}
                <li>
                  <Link to={LEGAL_INDEX}>{t('legal.allDocs')}</Link>
                </li>
              </ul>
            </nav>
          </div>
        </div>
      </section>
    </>
  );
}
