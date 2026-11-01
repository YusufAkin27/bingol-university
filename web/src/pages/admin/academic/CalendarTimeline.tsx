// Akademik takvim çizelgesi (Gantt benzeri): olay türüne göre şeritler, bugün çizgisi, yaklaşan olaylar.
// Veriyi sayfa verir (ay görünümüyle aynı sorgu); burada yalnız yerleşim ve görünüm vardır.
import { useMemo, useState } from 'react';
import { CALENDAR_KINDS, type AcademicEvent, type CalendarKind } from '../../../api/academic';
import { Button, EmptyState, Insight, ScrollShadow, Skeleton } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { gt } from '../icerik/dict';
import styles from './academic.module.css';
import tl from './timeline.module.css';
import {
  buildLanes,
  eventSpan,
  keyOfDay,
  layoutBox,
  shiftWindowStart,
  summarizeUpcoming,
  timelineWindow,
  todayPct,
  type PlacedEvent,
  type UpcomingItem,
} from './timelineLogic';

const SPAN_MONTHS = 6;
const STEP_MONTHS = 3;

export interface CalendarTimelineProps {
  events: AcademicEvent[];
  loading?: boolean;
  /** Yerel bugün, "YYYY-MM-DD". */
  todayKey: string;
  kindLabel: (k: CalendarKind) => string;
  onOpen: (ev: AcademicEvent) => void;
}

export function CalendarTimeline({ events, loading, todayKey, kindLabel, onOpen }: CalendarTimelineProps) {
  const i18n = useI18n();
  const t = gt(i18n);
  const { formatDate, formatNumber } = i18n;
  const [start, setStart] = useState(() => ({
    year: Number(todayKey.slice(0, 4)),
    month0: Number(todayKey.slice(5, 7)) - 1,
  }));

  const win = useMemo(() => timelineWindow(start.year, start.month0, SPAN_MONTHS), [start]);
  const lanes = useMemo(() => buildLanes(events, win, CALENDAR_KINDS), [events, win]);
  const up = useMemo(() => summarizeUpcoming(events, todayKey), [events, todayKey]);
  const nowPct = todayPct(win, todayKey);
  const cols = win.months.map((m) => `${m.days}fr`).join(' ');

  const short = (key: string) => formatDate(`${key}T12:00:00`, { day: 'numeric', month: 'short' });
  const rangeText = (startNum: number, endNum: number) =>
    startNum === endNum ? short(keyOfDay(startNum)) : `${short(keyOfDay(startNum))} – ${short(keyOfDay(endNum))}`;
  const monthLabel = (year: number, month0: number, withYear: boolean) =>
    formatDate(new Date(Date.UTC(year, month0, 15, 12)), withYear ? { month: 'short', year: 'numeric' } : { month: 'short' });

  const whenLabel = (u: UpcomingItem): string => {
    if (u.ongoing) {
      return u.endsInDays === 0
        ? t('admin.icerik.tl.when.endsToday')
        : t('admin.icerik.tl.when.endsIn', { n: formatNumber(u.endsInDays) });
    }
    if (u.inDays === 0) return t('admin.icerik.tl.when.today');
    if (u.inDays === 1) return t('admin.icerik.tl.when.tomorrow');
    return t('admin.icerik.tl.when.inDays', { n: formatNumber(u.inDays) });
  };

  const lead = up.ongoing[0] ?? up.next[0];
  const insight =
    !lead
      ? t('admin.icerik.tl.insight.none')
      : up.ongoing.length > 0
        ? t('admin.icerik.tl.insight.ongoing', {
            n: formatNumber(up.ongoing.length),
            title: lead.ev.title,
            when: whenLabel(lead),
            days: formatNumber(up.horizon),
            total: formatNumber(up.withinHorizon),
          })
        : t('admin.icerik.tl.insight.next', {
            title: lead.ev.title,
            when: whenLabel(lead),
            days: formatNumber(up.horizon),
            n: formatNumber(up.withinHorizon),
          });

  const first = win.months[0];
  const last = win.months[win.months.length - 1];
  const rangeTitle = t('admin.icerik.tl.range', {
    from: monthLabel(first.year, first.month0, true),
    to: monthLabel(last.year, last.month0, true),
  });

  const upcomingList = [...up.ongoing, ...up.next];

  const bar = (p: PlacedEvent, rowIdx: number) => {
    const box = layoutBox(p.leftPct, p.widthPct);
    const draft = !p.ev.published;
    const range = rangeText(p.startNum, p.endNum);
    const extra = [
      draft ? t('admin.icerik.tl.draftTag') : '',
      p.clippedStart ? t('admin.icerik.tl.continuesBefore') : '',
      p.clippedEnd ? t('admin.icerik.tl.continuesAfter') : '',
    ]
      .filter(Boolean)
      .join(', ');
    return (
      <button
        key={p.ev.id}
        type="button"
        className={`${styles[`k_${p.ev.kind}`] ?? ''} ${tl.hit} ${box.alignEnd ? tl.hitEnd : ''}`}
        style={{
          insetInlineStart: `${box.boxLeft}%`,
          inlineSize: `${box.occ}%`,
          insetBlockStart: `calc(${rowIdx} * var(--tl-rowh) + 0.35rem)`,
        }}
        title={`${kindLabel(p.ev.kind)}: ${p.ev.title} (${range})`}
        aria-label={t('admin.icerik.tl.openEvent', {
          title: p.ev.title,
          kind: kindLabel(p.ev.kind),
          when: range,
          extra: extra ? `, ${extra}` : '',
        })}
        onClick={() => onOpen(p.ev)}
      >
        <span
          className={`${tl.band} ${draft ? tl.bandDraft : ''} ${p.clippedStart ? tl.cutStart : ''} ${p.clippedEnd ? tl.cutEnd : ''}`}
          style={{ marginInlineStart: `${box.bandOffset}%`, inlineSize: `${box.bandWidth}%` }}
          aria-hidden="true"
        />
        <span className={tl.text} dir="auto">
          <span className={tl.textTitle}>{p.ev.title}</span>
          <span className={tl.textDate}>
            {range}
            {draft ? ` · ${t('admin.icerik.tl.draftTag')}` : ''}
          </span>
        </span>
      </button>
    );
  };

  return (
    <div className={tl.wrap} data-search-anchor="cal-timeline" data-testid="cal-timeline">
      <Insight tone={lead ? 'info' : 'warn'} parts={insight} />
      {up.draftSoon > 0 && <Insight tone="warn" parts={t('admin.icerik.tl.insight.draft', { n: formatNumber(up.draftSoon) })} />}

      <section className={tl.upcoming} aria-labelledby="tl-upcoming-h" data-search-anchor="cal-upcoming">
        <h3 id="tl-upcoming-h" className={tl.h}>
          {t('admin.icerik.tl.upcoming.title')}
        </h3>
        {upcomingList.length === 0 ? (
          <p className={styles.muted}>{t('admin.icerik.tl.upcoming.empty')}</p>
        ) : (
          <ol className={tl.upList}>
            {upcomingList.map((u) => (
              <li key={u.ev.id}>
                <button
                  type="button"
                  className={`${styles[`k_${u.ev.kind}`] ?? ''} ${tl.upItem}`}
                  onClick={() => onOpen(u.ev)}
                >
                  <span className={tl.upKind}>
                    {kindLabel(u.ev.kind)}
                    {u.ev.published ? '' : ` · ${t('admin.icerik.tl.draftTag')}`}
                  </span>
                  <span className={tl.upTitle} dir="auto">
                    {u.ev.title}
                  </span>
                  <span className={tl.upDate}>{rangeText(...spanOf(u.ev))}</span>
                  <span className={`${tl.upWhen} ${u.ongoing ? tl.upNow : ''}`}>
                    {u.ongoing ? `${t('admin.icerik.tl.upcoming.ongoing')} · ` : ''}
                    {whenLabel(u)}
                  </span>
                </button>
              </li>
            ))}
          </ol>
        )}
      </section>

      <div className={tl.nav} data-search-anchor="cal-timeline-nav">
        <Button size="sm" variant="secondary" onClick={() => setStart((s) => shiftWindowStart(s.year, s.month0, -STEP_MONTHS))}>
          {t('admin.icerik.tl.prev')}
        </Button>
        <h3 className={tl.range} aria-live="polite">
          {rangeTitle}
        </h3>
        <Button size="sm" variant="secondary" onClick={() => setStart((s) => shiftWindowStart(s.year, s.month0, STEP_MONTHS))}>
          {t('admin.icerik.tl.next')}
        </Button>
        <Button
          size="sm"
          variant="ghost"
          onClick={() =>
            setStart({ year: Number(todayKey.slice(0, 4)), month0: Number(todayKey.slice(5, 7)) - 1 })
          }
        >
          {t('admin.icerik.tl.goToday')}
        </Button>
      </div>

      {loading ? (
        <Skeleton height="14rem" width="100%" />
      ) : lanes.length === 0 ? (
        <EmptyState icon="calendar" title={t('admin.icerik.tl.emptyTitle')} description={t('admin.icerik.tl.emptyHint')} />
      ) : (
        <ScrollShadow ariaLabel={t('admin.icerik.tl.scrollLabel')}>
          <div className={tl.board} role="group" aria-label={t('admin.icerik.tl.chartLabel')}>
            <div className={tl.row}>
              <div className={tl.corner} />
              <div className={tl.months} style={{ gridTemplateColumns: cols }}>
                {win.months.map((m, i) => (
                  <span key={`${m.year}-${m.month0}`} className={tl.monthCell}>
                    {monthLabel(m.year, m.month0, i === 0 || m.month0 === 0)}
                  </span>
                ))}
                {nowPct !== null && (
                  <span
                    className={tl.todayFlag}
                    style={{ insetInlineStart: `${nowPct}%` }}
                    title={t('admin.icerik.tl.todayLine', { date: formatDate(`${todayKey}T12:00:00`) })}
                  >
                    {t('admin.icerik.tl.todayMark')}
                  </span>
                )}
              </div>
            </div>
            {lanes.map((lane) => (
              <div key={lane.kind} className={`${tl.row} ${styles[`k_${lane.kind}`] ?? ''}`}>
                <div className={tl.laneLabel}>
                  <span className={tl.laneName}>{kindLabel(lane.kind)}</span>
                  <span className={tl.laneCount}>{t('admin.icerik.tl.laneCount', { n: formatNumber(lane.count) })}</span>
                </div>
                <div
                  className={tl.track}
                  style={{ ['--tl-rows' as string]: lane.rows.length }}
                >
                  <div className={tl.cols} style={{ gridTemplateColumns: cols }} aria-hidden="true">
                    {win.months.map((m) => (
                      <span key={`${m.year}-${m.month0}`} />
                    ))}
                  </div>
                  {nowPct !== null && (
                    <span className={tl.todayLine} style={{ insetInlineStart: `${nowPct}%` }} aria-hidden="true" />
                  )}
                  {lane.rows.map((row, r) => row.map((p) => bar(p, r)))}
                </div>
              </div>
            ))}
          </div>
        </ScrollShadow>
      )}
    </div>
  );
}


/** Yaklaşan listesi için olayın [başlangıç, bitiş] gün numaraları. */
function spanOf(ev: AcademicEvent): [number, number] {
  const s = eventSpan(ev);
  return s ? [s.start, s.end] : [0, 0];
}
