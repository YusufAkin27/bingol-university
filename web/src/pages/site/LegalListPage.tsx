// SAYFA: Yasal belgeler listesi (/legal) — routes.tsx'te ayrı rota olmadığından NotFoundPage '/legal' için bunu çizer.
// API: GET /api/legal (herkese açık; her tür için güncel sürüm, başlık, yayın tarihi).
import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { listLegal } from '../../api/legal';
import { qk } from '../../api/queryKeys';
import { ErrorState, Icon, Skeleton } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { errorMessage } from '../../lib/errors';
import { paths } from '../../paths';
import { AdminAccessNotice } from './components/AdminAccessNotice';
import { PageHero } from './components/PageHero';
import { usePageMeta } from './components/usePageMeta';
import shared from './components/site.module.css';
import styles from './LegalListPage.module.css';

export default function LegalListPage() {
  const i18n = useI18n();
  const { t, lang, formatDate } = i18n;
  usePageMeta({ title: t('legal.list.title'), description: t('site.meta.legal'), path: '/legal' });
  const list = useQuery({ queryKey: [...qk.legal.list(), lang], queryFn: listLegal });
  return (
    <>
      <PageHero title={t('legal.list.title')} lead={t('legal.list.lead')} />
      <section className={`${shared.section} ${shared.sectionTop}`}>
        <div className={`container ${styles.wrap}`}>
          {list.isLoading && (
            <div role="status" aria-label={t('common.loading')} className={styles.sk}>
              {[0, 1, 2, 3].map((i) => (
                <Skeleton key={i} height="4.5rem" radius="12px" />
              ))}
            </div>
          )}
          {list.isError && (
            <ErrorState
              title={t('legal.list.error')}
              description={errorMessage(i18n, list.error)}
              onRetry={() => void list.refetch()}
            />
          )}
          {list.data && (
            <ul className={styles.list}>
              {list.data.map((d) => (
                <li key={d.type}>
                  <Link to={paths.site.legal(d.type)} className={styles.row}>
                    <span className={shared.ico}>
                      <Icon name="file" size={22} />
                    </span>
                    <span className={styles.text}>
                      <strong>{d.title}</strong>
                      <span>
                        {t('legal.version', { version: d.version })}, {t('legal.publishedAt', { date: formatDate(d.publishedAt) })}
                      </span>
                    </span>
                    <span className={styles.go}>
                      {t('legal.list.read')}
                      <Icon name="chevronRight" size={18} className={styles.arrow} />
                    </span>
                  </Link>
                </li>
              ))}
              <li>
                <Link to={paths.site.dataRequest} className={styles.row}>
                  <span className={shared.ico}>
                    <Icon name="shield" size={22} />
                  </span>
                  <span className={styles.text}>
                    <strong>{t('site.dataRequest.title')}</strong>
                    <span>{t('site.dataRequest.lead')}</span>
                  </span>
                  <span className={styles.go}>
                    {t('legal.list.read')}
                    <Icon name="chevronRight" size={18} className={styles.arrow} />
                  </span>
                </Link>
              </li>
            </ul>
          )}
          <AdminAccessNotice />
        </div>
      </section>
    </>
  );
}
