// SAYFA: Yemek listesi (/menu) — günlük, haftalık ve aylık görünüm
// API: GET /api/menu?month=yyyy-MM (herkese açık, [{date, items[], imageUrl, dishes[{name,kcal}], totalKcal, kcalComplete}]);
// GET /api/status (MENU bakımda notu).
import { useQueries, useQuery } from '@tanstack/react-query';
import { useEffect, useMemo, useRef, useState } from 'react';
import { getMenuMonth, getSourceStatus } from '../../api/publicContent';
import { ButtonLink, EmptyState, ErrorState, Icon, IconButton, Skeleton } from '../../components/ui';
import type { TranslationKey } from '../../i18n';
import { useI18n } from '../../i18n/I18nProvider';
import { isoDate } from '../../lib/date';
import { errorMessage } from '../../lib/errors';
import { paths } from '../../paths';
import { MenuAppBand } from './components/MenuAppBand';
import { PageHero } from './components/PageHero';
import { usePageMeta } from './components/usePageMeta';
import shared from './components/site.module.css';
import { daysOfMonth, menuImageUrl, parseMenuDay, weekDates, type ParsedDay } from './menuLogic';
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

/** Hafta/ay ızgarasındaki kompakt gün menüsü: öğün bölümleri, kalori ve alerjen bilgisi (varsa). */
function DayMenu({ day }: { day: ParsedDay }) {
  const { t } = useI18n();
  return (
    <div className={styles.meals}>
      {day.sections.map((s) => (
        <section key={s.key} className={styles.meal} aria-label={t(`pg.menu.section.${s.key}` as TranslationKey)}>
          {(day.sections.length > 1 || s.key !== 'menu') && (
            <h3 className={styles.mealH}>{t(`pg.menu.section.${s.key}` as TranslationKey)}</h3>
          )}
          <ul className={styles.dishesCompact}>
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
          {day.totalKcal !== null && (
            <strong>
              {day.kcalComplete
                ? t('pg.menu.totalKcal', { n: day.totalKcal })
                : t('site.rd05.totalAtLeast', { n: day.totalKcal })}
            </strong>
          )}
          {day.allergens.length > 0 && <span>{t('pg.menu.allergens', { list: day.allergens.join(', ') })}</span>}
        </p>
      )}
    </div>
  );
}

/** Günün menüsü (günlük görünüm): isteğe bağlı fotoğraf, numaralı yemekler, yemek başına kalori ve günün toplamı. */
function DayCard({ date, day, isToday }: { date: string; day: ParsedDay; isToday: boolean }) {
  const { t, formatDate } = useI18n();
  const [imgOk, setImgOk] = useState(true);
  const photoUrl = menuImageUrl(day.imageUrl);
  let n = 0;
  return (
    <article className={`${styles.card} ${isToday ? styles.cardToday : ''}`}>
      <header className={styles.cardHead}>
        <div>
          <p className={styles.cardEyebrow}>
            {isToday ? t('pg.menu.todayTitle') : formatDate(date, { weekday: 'long' })}
          </p>
          <h2 className={styles.cardTitle}>
            <time dateTime={date}>{formatDate(date, { day: 'numeric', month: 'long', year: 'numeric' })}</time>
          </h2>
        </div>
        <span className={styles.count}>{t('pg.menu.itemCount', { n: day.dishCount })}</span>
      </header>
      {photoUrl && imgOk && (
        <div className={styles.photo}>
          <img
            src={photoUrl}
            alt={t('site.rd05.photoAlt')}
            loading="lazy"
            decoding="async"
            referrerPolicy="no-referrer"
            onError={() => setImgOk(false)}
          />
        </div>
      )}
      <div className={styles.cardBody}>
        {day.sections.map((s) => (
          <section key={s.key} className={styles.meal} aria-label={t(`pg.menu.section.${s.key}` as TranslationKey)}>
            {(day.sections.length > 1 || s.key !== 'menu') && (
              <h3 className={styles.mealH}>{t(`pg.menu.section.${s.key}` as TranslationKey)}</h3>
            )}
            <ol className={styles.dishList}>
              {s.dishes.map((d) => {
                n += 1;
                return (
                  <li key={n} className={styles.dish}>
                    <span className={styles.dishNo} aria-hidden="true">
                      {n}
                    </span>
                    <span className={styles.dishName}>{d.text}</span>
                    {d.kcal !== null && <span className={styles.dishKcal}>{t('pg.menu.kcal', { n: d.kcal })}</span>}
                  </li>
                );
              })}
            </ol>
          </section>
        ))}
        {(day.totalKcal !== null || day.allergens.length > 0) && (
          <div className={styles.sum}>
            {day.totalKcal !== null && (
              <div className={styles.total}>
                <span className={styles.totalLabel}>{t('site.rd05.totalLabel')}</span>
                <strong className={styles.totalNum}>
                  {day.kcalComplete
                    ? t('pg.menu.kcal', { n: day.totalKcal })
                    : t('site.rd05.totalAtLeast', { n: day.totalKcal })}
                </strong>
                {!day.kcalComplete && <span className={styles.totalNote}>{t('site.rd05.totalPartial')}</span>}
              </div>
            )}
            {day.allergens.length > 0 && (
              <p className={styles.allergens}>{t('pg.menu.allergens', { list: day.allergens.join(', ') })}</p>
            )}
          </div>
        )}
      </div>
    </article>
  );
}

/** Seçili günün menüsü yok: açıklama + (varsa) menü olan sonraki güne ve bugüne geçiş. */
function NoDay({
  nextDate,
  onPick,
  canToday,
  onToday,
}: {
  nextDate: string | null;
  onPick: (d: string) => void;
  canToday: boolean;
  onToday: () => void;
}) {
  const { t, formatDate } = useI18n();
  return (
    <div className={styles.noDay}>
      <span className={styles.noDayIcon} aria-hidden="true">
        <Icon name="calendar" size={30} />
      </span>
      <h2 className={styles.noDayTitle}>{t('pg.menu.noDay')}</h2>
      <p className={styles.noDayText}>{t('pg.menu.noDayHint')}</p>
      <div className={styles.noDayActions}>
        {nextDate && (
          <button type="button" className={styles.pri} onClick={() => onPick(nextDate)}>
            {t('site.rd05.nextMenu')}{' '}
            <bdi>({formatDate(nextDate, { weekday: 'short', day: 'numeric', month: 'short' })})</bdi>
          </button>
        )}
        {canToday && (
          <button type="button" className={styles.sec} onClick={onToday}>
            {t('pg.menu.today')}
          </button>
        )}
      </div>
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
  usePageMeta({ route: 'menu' });

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
        const p = parseMenuDay(d);
        if (p.dishCount > 0) map.set(d.date, p);
      }
    return map;
  }, [results]);
  const monthHasMenu = useMemo(() => daysOfMonth(month).some((d) => byDate.has(d)), [byDate, month]);
  // Seçili günden sonraki, menüsü olan ilk gün (yüklü aylar içinde)
  const nextDate = useMemo(() => [...byDate.keys()].filter((d) => d > date).sort()[0] ?? null, [byDate, date]);

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
  const menuStatus = status.data?.MENU;

  return (
    <>
      <PageHero eyebrow={t('site.v3.eyebrow')} title={title} lead={t('pg.menu.lead')} crumbs={[{ label: title }]} />
      <section className={`${shared.section} ${shared.sectionTop}`}>
        <div className={`container ${styles.wrap}`}>
          {menuStatus?.maintenance && (
            <p className={styles.maint} role="status">
              <Icon name="alert" size={20} />
              <span>
                {t('pg.menu.maintenance')}
                {menuStatus.lastSuccessAt && (
                  <small className={styles.maintSince}>
                    {t('site.rd05.maintSince', {
                      date: formatDate(menuStatus.lastSuccessAt, {
                        day: 'numeric',
                        month: 'long',
                        hour: '2-digit',
                        minute: '2-digit',
                      }),
                    })}
                  </small>
                )}
              </span>
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
                <bdi>{label}</bdi>
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
                  const parsed = byDate.get(d);
                  const has = parsed !== undefined;
                  const kcal = parsed?.totalKcal ?? null;
                  return (
                    <button
                      key={d}
                      type="button"
                      className={`${styles.chip} ${isSel ? styles.chipOn : ''} ${d === today ? styles.chipToday : ''} ${
                        has || !ready ? '' : styles.chipEmpty
                      }`}
                      aria-pressed={isSel}
                      aria-current={d === today ? 'date' : undefined}
                      onClick={() => setDate(d)}
                    >
                      <span className={styles.chipDow}>{formatDate(d, { weekday: 'short' })}</span>
                      <span className={styles.chipNum}>{Number(d.slice(8))}</span>
                      <span className={styles.chipKcal} aria-hidden={kcal === null || undefined}>
                        {kcal !== null ? (parsed?.kcalComplete ? t('pg.menu.kcal', { n: kcal }) : `≥ ${kcal}`) : ''}
                      </span>
                      {/* erişilebilir ad görünen metinle başlar (WCAG 2.5.3): aria-label yerine gizli ay adı eklenir */}
                      <span className="sr-only">{`, ${formatDate(d, { month: 'long' })}`}</span>
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

          {!loading && !failed && ready && view === 'day' && (
            <div className={styles.dayLayout}>
              {current ? (
                <DayCard date={date} day={current} isToday={date === today} />
              ) : (
                <NoDay nextDate={nextDate} onPick={setDate} canToday={date !== today} onToday={() => setDate(today)} />
              )}
              <aside className={styles.rate} aria-labelledby="menu-rate-h">
                <span className={styles.rateIcon} aria-hidden="true">
                  <Icon name="star" size={22} />
                </span>
                <h2 id="menu-rate-h" className={styles.rateTitle}>
                  {t('site.rd05.rateTitle')}
                </h2>
                <p className={styles.rateText}>{t('site.rd05.rateText')}</p>
                <ButtonLink to={paths.site.download} variant="accent" leftIcon={<Icon name="download" size={18} />}>
                  {t('site.home.ctaDownload')}
                </ButtonLink>
              </aside>
            </div>
          )}

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
                      <DayMenu day={byDate.get(d) as ParsedDay} />
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
                    <DayMenu day={byDate.get(d) as ParsedDay} />
                  </li>
                ))}
            </ul>
          )}
        </div>
      </section>
      <MenuAppBand />
    </>
  );
}
