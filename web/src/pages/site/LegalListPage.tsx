// SAYFA: Yasal belgeler listesi (/legal) — routes.tsx'te ayrı rota olmadığından NotFoundPage '/legal' için bunu çizer.
// API: GET /api/legal (herkese açık; her tür için güncel sürüm, başlık, yayın tarihi).
import { useQuery } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { Link } from '../../components/LocalizedLink';
import { LEGAL_TYPES, listLegal } from '../../api/legal';
import { qk } from '../../api/queryKeys';
import { ButtonLink, ErrorState, Icon, Skeleton, type IconName } from '../../components/ui';
import type { TranslationKey } from '../../i18n';
import { useI18n } from '../../i18n/I18nProvider';
import { errorMessage } from '../../lib/errors';
import { paths } from '../../paths';
import { AdminAccessNotice } from './components/AdminAccessNotice';
import { PageHero } from './components/PageHero';
import { usePageMeta } from './components/usePageMeta';
import styles from './LegalListPage.module.css';

/** "Güven ve güvenlik" bağlantıları: yalnız var olan sayfalar (başlık anahtarı pg.<slug>.title). */
const TRUST: { to: string; title: TranslationKey; icon: IconName }[] = [
  { to: paths.site.security, title: 'pg.security.title', icon: 'shield' },
  { to: paths.site.childSafety, title: 'pg.childsafety.title', icon: 'users' },
  { to: paths.site.guidelines, title: 'pg.guidelines.title', icon: 'flag' },
  { to: paths.site.accessibility, title: 'pg.accessibility.title', icon: 'eye' },
  { to: paths.site.cookies, title: 'pg.cookies.title', icon: 'info' },
  { to: paths.site.deleteAccount, title: 'pg.delete.title', icon: 'logout' },
];

export default function LegalListPage() {
  const i18n = useI18n();
  const { t, lang, formatDate } = i18n;
  usePageMeta({ route: 'legal' });
  const list = useQuery({ queryKey: [...qk.legal.list(), lang], queryFn: listLegal });
  const [q, setQ] = useState('');
  const shown = useMemo(() => {
    const needle = q.trim().toLocaleLowerCase(lang);
    return (list.data ?? []).filter((d) => !needle || d.title.toLocaleLowerCase(lang).includes(needle));
  }, [list.data, q, lang]);
  return (
    <>
      <PageHero title={t('legal.list.title')} lead={t('legal.list.lead')} />
      <section className={styles.section}>
        <div className={`container ${styles.wrap}`}>
          <div className={styles.main}>
            {/* Bildirim listenin ÜSTÜNDE: liste (iskelet -> veri) altta büyür, bildirim kaymaz (CLS, A3-11) */}
            <div className={styles.notice}>
              <AdminAccessNotice />
            </div>
            {list.isLoading && (
              <div role="status" aria-label={t('common.loading')} className={styles.sk}>
                {/* satır sayısı/yüksekliği gerçek listeye yakın tutulur: altındaki bildirim kaymasın (CLS, A3-11) */}
                {Array.from({ length: LEGAL_TYPES.length + 1 }, (_, i) => (
                  <Skeleton key={i} height="5.2rem" radius="12px" />
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
              <>
                <div className={styles.toolbar}>
                  <label className={styles.search}>
                    <Icon name="search" size={18} />
                    <input
                      type="search"
                      value={q}
                      onChange={(e) => setQ(e.target.value)}
                      placeholder={t('site.rd09.legal.search')}
                      aria-label={t('site.rd09.legal.search')}
                      autoComplete="off"
                    />
                  </label>
                  <p className={styles.count} role="status">
                    {shown.length === 0
                      ? t('site.rd09.legal.noMatch')
                      : t('site.rd09.legal.count', { n: String(shown.length) })}
                  </p>
                </div>
                <ul className={styles.list}>
                  {shown.map((d) => (
                    <li key={d.type}>
                      <Link to={paths.site.legal(d.type)} className={styles.row}>
                        <span className={styles.ico}>
                          <Icon name="file" size={22} />
                        </span>
                        <span className={styles.text}>
                          <strong>
                            {d.title}
                            <span className={styles.ver}>{t('legal.version', { version: d.version })}</span>
                          </strong>
                          <span>{t('legal.publishedAt', { date: formatDate(d.publishedAt) })}</span>
                        </span>
                        <span className={styles.go}>
                          <span className={styles.goLabel}>{t('legal.list.read')}</span>
                          <Icon name="chevronRight" size={18} className={styles.arrow} />
                        </span>
                      </Link>
                    </li>
                  ))}
                  {!q.trim() && (
                    <li>
                      <Link to={paths.site.dataRequest} className={styles.row}>
                        <span className={styles.ico}>
                          <Icon name="shield" size={22} />
                        </span>
                        <span className={styles.text}>
                          <strong>{t('site.dataRequest.title')}</strong>
                          <span>{t('site.dataRequest.lead')}</span>
                        </span>
                        <span className={styles.go}>
                          <span className={styles.goLabel}>{t('legal.list.read')}</span>
                          <Icon name="chevronRight" size={18} className={styles.arrow} />
                        </span>
                      </Link>
                    </li>
                  )}
                </ul>
              </>
            )}
          </div>
          <div className={styles.side}>
            <section className={styles.more} aria-labelledby="legal-trust">
              <h2 id="legal-trust" className={styles.sideTitle}>
                {t('site.trust.list.moreTitle')}
              </h2>
              <ul className={styles.trust}>
                {TRUST.map((x) => (
                  <li key={x.to}>
                    <Link to={x.to} className={styles.chip}>
                      <Icon name={x.icon} size={20} />
                      <span>{t(x.title)}</span>
                      <Icon name="chevronRight" size={18} className={styles.arrow} />
                    </Link>
                  </li>
                ))}
              </ul>
            </section>
            <aside className={styles.help} aria-labelledby="legal-help">
              <div>
                <h2 id="legal-help">{t('site.rd09.legal.helpTitle')}</h2>
                <p>{t('site.rd09.legal.helpText')}</p>
              </div>
              <div className={styles.helpActions}>
                <ButtonLink to={paths.site.contact}>{t('site.nav.contact')}</ButtonLink>
                <ButtonLink to={paths.site.dataRequest} variant="secondary">
                  {t('legal.dataRequest')}
                </ButtonLink>
              </div>
            </aside>
          </div>
        </div>
      </section>
    </>
  );
}
