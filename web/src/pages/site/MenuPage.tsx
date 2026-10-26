// SAYFA: Yemek listesi (/menu) — günlük ve aylık görünüm
// API: GET /api/menu?month=yyyy-MM (herkese açık, [{date, items[]}]); GET /api/status (MENU bakımda notu).
import { useQuery } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { getMenuMonth, getSourceStatus, type MenuDay } from '../../api/publicContent';
import { EmptyState, ErrorState, Icon, IconButton, Skeleton } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { isoDate } from '../../lib/date';
import { errorMessage } from '../../lib/errors';
import { paths } from '../../paths';
import { PageHero } from './components/PageHero';
import { usePageMeta } from './components/usePageMeta';
import shared from './components/site.module.css';
import styles from './MenuPage.module.css';

type View = 'day' | 'month';

export const monthOf = (iso: string) => iso.slice(0, 7);

/** yyyy-MM ayına delta ay ekler. */
export function shiftMonth(month: string, delta: number): string {
  const [y, m] = month.split('-').map(Number);
  const d = new Date(y, m - 1 + delta, 1);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
}

export default function MenuPage() {
  const i18n = useI18n();
  const { t, formatDate } = i18n;
  const today = isoDate(new Date());
  const [view, setView] = useState<View>('day');
  const [month, setMonth] = useState(monthOf(today));
  const [date, setDate] = useState(today);
  const title = t('pg.menu.title');
  usePageMeta({ title, description: t('pg.menu.meta'), path: paths.site.menu });

  const menu = useQuery({ queryKey: ['public', 'menu', month], queryFn: () => getMenuMonth(month) });
  const status = useQuery({ queryKey: ['public', 'status'], queryFn: getSourceStatus, retry: false });
  const days: MenuDay[] = useMemo(
    () => [...(menu.data ?? [])].sort((a, b) => a.date.localeCompare(b.date)),
    [menu.data],
  );
  const current = days.find((d) => d.date === date);
  const idx = days.findIndex((d) => d.date === date);

  const goMonth = (delta: number) => {
    const next = shiftMonth(month, delta);
    setMonth(next);
    setDate(`${next}-01`);
  };
  const goToday = () => {
    setMonth(monthOf(today));
    setDate(today);
  };
  const stepDay = (delta: number) => {
    // Menüsü olan komşu güne atla; ay sınırında bir sonraki/önceki aya geç
    const target = days[idx + delta];
    if (target) setDate(target.date);
    else goMonth(delta);
  };

  const monthLabel = formatDate(`${month}-01`, { month: 'long', year: 'numeric' });
  const prevIcon = i18n.dir === 'rtl' ? 'chevronRight' : 'chevronLeft';
  const nextIcon = i18n.dir === 'rtl' ? 'chevronLeft' : 'chevronRight';

  return (
    <>
      <PageHero title={title} lead={t('pg.menu.lead')} crumbs={[{ label: title }]} />
      <section className={`${shared.section} ${shared.sectionTop}`}>
        <div className={`container ${styles.wrap}`}>
          {status.data?.MENU?.maintenance && (
            <p className={styles.maint} role="status">
              <Icon name="alert" size={18} /> {t('pg.menu.maintenance')}
            </p>
          )}
          <div className={styles.bar}>
            <div role="group" aria-label={t('pg.menu.view')} className={styles.seg}>
              {(['day', 'month'] as const).map((v) => (
                <button
                  key={v}
                  type="button"
                  className={`${styles.segBtn} ${v === view ? styles.segOn : ''}`}
                  aria-pressed={v === view}
                  onClick={() => setView(v)}
                >
                  {t(v === 'day' ? 'pg.menu.view.day' : 'pg.menu.view.month')}
                </button>
              ))}
            </div>
            <div className={styles.nav}>
              <IconButton
                label={view === 'day' ? t('pg.menu.prevDay') : t('pg.menu.prevMonth')}
                variant="secondary"
                size="sm"
                onClick={() => (view === 'day' ? stepDay(-1) : goMonth(-1))}
              >
                <Icon name={prevIcon} size={18} />
              </IconButton>
              <strong className={styles.label} aria-live="polite">
                {view === 'day' ? formatDate(date, { weekday: 'long', day: 'numeric', month: 'long' }) : monthLabel}
              </strong>
              <IconButton
                label={view === 'day' ? t('pg.menu.nextDay') : t('pg.menu.nextMonth')}
                variant="secondary"
                size="sm"
                onClick={() => (view === 'day' ? stepDay(1) : goMonth(1))}
              >
                <Icon name={nextIcon} size={18} />
              </IconButton>
              <button type="button" className={styles.today} onClick={goToday}>
                {t('pg.menu.today')}
              </button>
            </div>
          </div>

          {menu.isLoading && (
            <div role="status" aria-label={t('common.loading')} className={styles.skel}>
              <Skeleton height="1.4rem" />
              <Skeleton height="1.4rem" width="80%" />
              <Skeleton height="1.4rem" width="60%" />
            </div>
          )}
          {menu.isError && (
            <ErrorState
              title={t('pg.menu.error')}
              description={errorMessage(i18n, menu.error)}
              onRetry={() => void menu.refetch()}
            />
          )}
          {menu.isSuccess && days.length === 0 && (
            <EmptyState icon="calendar" title={t('pg.menu.noMonth')} description={t('pg.menu.noMonthHint')} />
          )}
          {menu.isSuccess && days.length > 0 && view === 'day' &&
            (current ? (
              <ul className={styles.dishes}>
                {current.items.map((it, i) => (
                  <li key={`${i}-${it}`}>{it}</li>
                ))}
              </ul>
            ) : (
              <EmptyState icon="calendar" title={t('pg.menu.noDay')} description={t('pg.menu.noDayHint')} />
            ))}
          {menu.isSuccess && days.length > 0 && view === 'month' && (
            <ul className={styles.month}>
              {days.map((d) => (
                <li key={d.date} className={`${styles.day} ${d.date === today ? styles.dayToday : ''}`}>
                  <h2 className={styles.dayH}>
                    <time dateTime={d.date}>{formatDate(d.date, { weekday: 'short', day: 'numeric', month: 'short' })}</time>
                  </h2>
                  <ul>
                    {d.items.map((it, i) => (
                      <li key={`${i}-${it}`}>{it}</li>
                    ))}
                  </ul>
                </li>
              ))}
            </ul>
          )}
          <p className={shared.muted}>{t('pg.menu.source')}</p>
        </div>
      </section>
    </>
  );
}
