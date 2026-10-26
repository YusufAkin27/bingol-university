// SAYFA: Yemek listesi (/menu) — günlük, haftalık ve aylık görünüm
// API: GET /api/menu?month=yyyy-MM (herkese açık, [{date, items[]}]); GET /api/status (MENU bakımda notu).
import { useQueries, useQuery } from '@tanstack/react-query';
import { useEffect, useMemo, useRef, useState } from 'react';
import { getMenuMonth, getSourceStatus } from '../../api/publicContent';
import { EmptyState, ErrorState, Icon, IconButton, Skeleton } from '../../components/ui';
import type { TranslationKey } from '../../i18n';
import { useI18n } from '../../i18n/I18nProvider';
import { isoDate } from '../../lib/date';
import { errorMessage } from '../../lib/errors';
import { paths } from '../../paths';
import { PageHero } from './components/PageHero';
import { usePageMeta } from './components/usePageMeta';
import shared from './components/site.module.css';
import { daysOfMonth, parseDay, weekDates, type ParsedDay } from './menuLogic';
import styles from './MenuPage.module.css';

type View = 'day' | 'week' | 'month';

export const monthOf = (iso: string) => iso.slice(0, 7);

/** yyyy-MM ayına delta ay ekler. */
export function shiftMonth(month: string, delta: number): string {
  const [y, m] = month.split('-').map(Number);
  const d = new Date(y, m - 1 + delta, 1);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
}

function shiftDay(iso: string, delta: number): string {
  const [y, m, d] = iso.split('-').map(Number);
  return isoDate(new Date(y, m - 1, d + delta));
}

/** Bir günün menüsü: öğün bölümleri, kalori ve alerjen bilgisi (varsa). */
function DayMenu({ day, compact = false }: { day: ParsedDay; compact?: boolean }) {
  const { t } = useI18n();
  return (
    <div className={styles.meals}>
      {day.sections.map((s) => (
        <section key={s.key} className={styles.meal} aria-label={t(`pg.menu.section.${s.key}` as TranslationKey)}>
          {(day.sections.length > 1 || s.key !== 'menu') && (
            <h3 className={styles.mealH}>{t(`pg.menu.section.${s.key}` as TranslationKey)}</h3>
          )}
          <ul className={compact ? styles.dishesCompact : styles.dishes}>
            {s.dishes.map((d, i) => (
              <li key={`${i}-${d.text}`}>
                <span>{d.text}</span>
                {d.kcal !== null && <span className={styles.kcal}>{t('pg.menu.kcal', { n: d.kcal })}</span>}
              </li>
            ))}
          </ul>
        </section>
      ))}
      {(day.totalKcal !== null || day.allergens.length > 0) && (
        <p className={styles.facts}>
          {day.totalKcal !== null && <strong>{t('pg.menu.totalKcal', { n: day.totalKcal })}</strong>}
          {day.allergens.length > 0 && <span>{t('pg.menu.allergens', { list: day.allergens.join(', ') })}</span>}
        </p>
      )}
    </div>
  );
}

export default function MenuPage() {
  const i18n = useI18n();
  const { t, formatDate } = i18n;
  const today = isoDate(new Date());
  const [view, setView] = useState<View>('day');
  const [date, setDate] = useState(today);
  const title = t('pg.menu.title');
  usePageMeta({ title, description: t('pg.menu.meta'), path: paths.site.menu });

  const month = monthOf(date);
  const week = useMemo(() => weekDates(date), [date]);
  // Hafta ay sınırını aşabilir: gereken ayların hepsi çekilir
  const months = useMemo(
    () => (view === 'week' ? [...new Set(week.map(monthOf))] : [month]),
    [view, week, month],
  );
  const results = useQueries({
    queries: months.map((m) => ({ queryKey: ['public', 'menu', m], queryFn: () => getMenuMonth(m) })),
  });
  const status = useQuery({ queryKey: ['public', 'status'], queryFn: getSourceStatus, retry: false });

  const loading = results.some((r) => r.isLoading);
  const failed = results.find((r) => r.isError);
  const ready = results.every((r) => r.isSuccess);
  const byDate = useMemo(() => {
    const map = new Map<string, ParsedDay>();
    for (const r of results)
      for (const d of r.data ?? []) {
        const p = parseDay(d.items);
        if (p.dishCount > 0) map.set(d.date, p);
      }
    return map;
  }, [results]);
  const monthHasMenu = useMemo(() => daysOfMonth(month).some((d) => byDate.has(d)), [byDate, month]);

  // Seçili günü şeritte görünür tut
  const stripRef = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const el = stripRef.current?.querySelector<HTMLElement>('[aria-current="date"], [aria-pressed="true"]');
    el?.scrollIntoView?.({ block: 'nearest', inline: 'center' });
  }, [date, ready]);

  const step = (delta: number) => {
    if (view === 'day') setDate(shiftDay(date, delta));
    else if (view === 'week') setDate(shiftDay(date, delta * 7));
    else {
      const next = shiftMonth(month, delta);
      setDate(next === monthOf(today) ? today : `${next}-01`);
    }
  };

  const prevIcon = i18n.dir === 'rtl' ? 'chevronRight' : 'chevronLeft';
  const nextIcon = i18n.dir === 'rtl' ? 'chevronLeft' : 'chevronRight';
  const label =
    view === 'day'
      ? formatDate(date, { weekday: 'long', day: 'numeric', month: 'long' })
      : view === 'week'
        ? t('pg.menu.weekOf', {
            from: formatDate(week[0], { day: 'numeric', month: 'short' }),
            to: formatDate(week[6], { day: 'numeric', month: 'short' }),
          })
        : formatDate(`${month}-01`, { month: 'long', year: 'numeric' });
  const unit = view === 'day' ? 'Day' : view === 'week' ? 'Week' : 'Month';
  const current = byDate.get(date);

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
              {(['day', 'week', 'month'] as const).map((v) => (
                <button
                  key={v}
                  type="button"
                  className={`${styles.segBtn} ${v === view ? styles.segOn : ''}`}
                  aria-pressed={v === view}
                  onClick={() => setView(v)}
                >
                  {t(`pg.menu.view.${v}` as TranslationKey)}
                </button>
              ))}
            </div>
            <div className={styles.nav}>
              <IconButton
                label={t(`pg.menu.prev${unit}` as TranslationKey)}
                variant="secondary"
                size="sm"
                onClick={() => step(-1)}
              >
                <Icon name={prevIcon} size={18} />
              </IconButton>
              <strong className={styles.label} aria-live="polite">
                {label}
              </strong>
              <IconButton
                label={t(`pg.menu.next${unit}` as TranslationKey)}
                variant="secondary"
                size="sm"
                onClick={() => step(1)}
              >
                <Icon name={nextIcon} size={18} />
              </IconButton>
              <button type="button" className={styles.today} onClick={() => setDate(today)}>
                {t('pg.menu.today')}
              </button>
            </div>
          </div>

          {view !== 'month' && (
            <div className={styles.stripWrap}>
              <div ref={stripRef} className={styles.strip} role="group" aria-label={t('pg.menu.dayStrip')}>
                {daysOfMonth(month).map((d) => {
                  const isSel = d === date;
                  const has = byDate.has(d);
                  return (
                    <button
                      key={d}
                      type="button"
                      className={`${styles.chip} ${isSel ? styles.chipOn : ''} ${d === today ? styles.chipToday : ''} ${
                        has || !ready ? '' : styles.chipEmpty
                      }`}
                      aria-pressed={isSel}
                      aria-current={d === today ? 'date' : undefined}
                      aria-label={formatDate(d, { weekday: 'long', day: 'numeric', month: 'long' })}
                      onClick={() => setDate(d)}
                    >
                      <span className={styles.chipDow}>{formatDate(d, { weekday: 'short' })}</span>
                      <span className={styles.chipNum}>{Number(d.slice(8))}</span>
                    </button>
                  );
                })}
              </div>
            </div>
          )}

          {loading && (
            <div role="status" aria-label={t('common.loading')} className={styles.skel}>
              <Skeleton height="1.4rem" />
              <Skeleton height="1.4rem" width="80%" />
              <Skeleton height="1.4rem" width="60%" />
            </div>
          )}
          {!loading && failed && (
            <ErrorState
              title={t('pg.menu.error')}
              description={errorMessage(i18n, failed.error)}
              onRetry={() => results.forEach((r) => void r.refetch())}
            />
          )}
          {!loading && !failed && ready && view === 'month' && !monthHasMenu && (
            <EmptyState icon="calendar" title={t('pg.menu.noMonth')} description={t('pg.menu.noMonthHint')} />
          )}

          {!loading && !failed && ready && view === 'day' &&
            (current ? (
              <article className={`${styles.card} ${date === today ? styles.cardToday : ''}`}>
                <header className={styles.cardHead}>
                  <div>
                    <p className={styles.cardEyebrow}>
                      {date === today ? t('pg.menu.todayTitle') : formatDate(date, { weekday: 'long' })}
                    </p>
                    <h2 className={styles.cardTitle}>
                      <time dateTime={date}>{formatDate(date, { day: 'numeric', month: 'long', year: 'numeric' })}</time>
                    </h2>
                  </div>
                  <span className={styles.count}>{t('pg.menu.itemCount', { n: current.dishCount })}</span>
                </header>
                <DayMenu day={current} />
              </article>
            ) : (
              <EmptyState icon="calendar" title={t('pg.menu.noDay')} description={t('pg.menu.noDayHint')} />
            ))}

          {!loading && !failed && ready && view === 'week' &&
            (week.some((d) => byDate.has(d)) ? (
              <ul className={styles.grid}>
                {week
                  .filter((d) => byDate.has(d))
                  .map((d) => (
                    <li key={d} className={`${styles.day} ${d === today ? styles.dayToday : ''}`}>
                      <h2 className={styles.dayH}>
                        <time dateTime={d}>{formatDate(d, { weekday: 'long', day: 'numeric', month: 'long' })}</time>
                        {d === today && <span className={styles.todayPill}>{t('pg.menu.todayBadge')}</span>}
                      </h2>
                      <DayMenu day={byDate.get(d) as ParsedDay} compact />
                    </li>
                  ))}
              </ul>
            ) : (
              <EmptyState icon="calendar" title={t('pg.menu.noWeek')} description={t('pg.menu.noMonthHint')} />
            ))}

          {!loading && !failed && ready && view === 'month' && monthHasMenu && (
            <ul className={styles.grid}>
              {daysOfMonth(month)
                .filter((d) => byDate.has(d))
                .map((d) => (
                  <li key={d} className={`${styles.day} ${d === today ? styles.dayToday : ''}`}>
                    <h2 className={styles.dayH}>
                      <time dateTime={d}>{formatDate(d, { weekday: 'short', day: 'numeric', month: 'short' })}</time>
                      {d === today && <span className={styles.todayPill}>{t('pg.menu.todayBadge')}</span>}
                    </h2>
                    <DayMenu day={byDate.get(d) as ParsedDay} compact />
                  </li>
                ))}
            </ul>
          )}
        </div>
      </section>
    </>
  );
}
