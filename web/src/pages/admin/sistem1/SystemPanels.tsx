// Sistem durumu sayfasının görsel panelleri: dört ana gösterge (depolama halkası, yedek tazeliği, gönderim sıraları,
// otomatik görevler), oturum sağlık çizelgesi ve görev şeridi. Hepsi /api/admin/system/overview verisinden türer.
import { useEffect, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import { levelOf, type SystemIndicator, type SystemLevel } from '../../../api/system';
import { Card, Icon, Insight, ProgressRing, StatusDot, type RingTone, type StatusTone } from '../../../components/ui';
import type { I18n } from '../../../i18n/I18nProvider';
import { paths } from '../../../paths';
import { nameOf, valueText } from '../systemstatus/indicators';
import { s1 } from './dict';
import {
  HISTORY_MAX,
  jobLanes,
  pushSample,
  readHistory,
  summarizeHistory,
  verdictOf,
  worstLevel,
  writeHistory,
  zoneScale,
  type HistorySample,
} from './logic';
import { ZoneGauge } from './Visuals';
import styles from './sistem1.module.css';

type Entry = [string, SystemIndicator];

const RING: Record<SystemLevel, RingTone> = { OK: 'success', WARN: 'warning', CRIT: 'danger', UNKNOWN: 'neutral' };
const DOT: Record<SystemLevel, StatusTone> = { OK: 'success', WARN: 'warning', CRIT: 'danger', UNKNOWN: 'neutral' };

function find(entries: Entry[], ...ids: string[]): Entry | undefined {
  for (const id of ids) {
    const e = entries.find(([k]) => k === id);
    if (e) return e;
  }
  return undefined;
}

// ---------- Dört ana gösterge ----------
function Tile({
  title,
  level,
  children,
  ...rest
}: {
  title: string;
  level: SystemLevel;
  children: React.ReactNode;
  /** Arama bağlantısı: çağıran yerde SABİT yazılır (kapsam testi kaynakta arar). */
  'data-search-anchor': string;
}) {
  return (
    <article className={styles.tile} data-status={level} data-search-anchor={rest['data-search-anchor']} aria-label={title}>
      <h3 className={styles.tileTitle}>{title}</h3>
      {children}
    </article>
  );
}

export function KeyGauges({ i18n, entries }: { i18n: I18n; entries: Entry[] }) {
  const t = s1(i18n);
  const storage = find(entries, 'storage', 'disk.storage');
  const backup = find(entries, 'backup.age');
  const drive = find(entries, 'backup.remote');
  const queues = (['mail.dead', 'push.dead', 'mail.oldestPendingAge', 'push.oldestPendingAge'] as const)
    .map((id) => find(entries, id))
    .filter((e): e is Entry => !!e);
  const jobs = entries.filter(([k]) => k.startsWith('jobs.'));

  const tiles: React.ReactNode[] = [];

  if (storage && typeof storage[1].value === 'number') {
    const [id, ind] = storage;
    const level = levelOf(ind.status);
    tiles.push(
      <Tile key="storage" title={t('admin.s1.gauge.storage')} level={level} data-search-anchor="gauge-storage">
        <ProgressRing
          value={ind.value as number}
          label={t('admin.s1.gauge.storage.ring')}
          center={i18n.t('admin.system.unit.percent', { n: i18n.formatNumber(Math.round(ind.value as number)) })}
          tone={RING[level]}
          size={96}
          thickness={10}
        />
        <p className={styles.tileSentence}>
          {level === 'OK' ? t('admin.s1.gauge.storage.ok') : t('admin.s1.gauge.storage.bad', { value: valueText(i18n, id, ind) })}
        </p>
        <Link className={styles.tileLink} to={paths.admin.dataRetention}>
          {t('admin.s1.gauge.storage.go')}
        </Link>
      </Tile>,
    );
  }

  if (backup && typeof backup[1].value === 'number') {
    const [id, ind] = backup;
    const level = levelOf(ind.status);
    const hours = ind.value as number;
    const scale = zoneScale(hours, ind.threshold?.warn, ind.threshold?.crit);
    tiles.push(
      <Tile key="backup" title={t('admin.s1.gauge.backup')} level={level} data-search-anchor="gauge-backup">
        <p className={styles.tileBig}>{valueText(i18n, id, ind)}</p>
        <ZoneGauge scale={scale} level={level} label={t('admin.s1.gauge.backup.aria', { value: valueText(i18n, id, ind) })} />
        <p className={styles.tileSentence}>
          {level === 'OK' ? t('admin.s1.gauge.backup.ok') : t('admin.s1.gauge.backup.bad')}
          {drive && typeof drive[1].value === 'number' && (
            <>
              {' '}
              {t('admin.s1.gauge.backup.drive', { value: valueText(i18n, drive[0], drive[1]) })}
            </>
          )}
        </p>
        <Link className={styles.tileLink} to={paths.admin.backup}>
          {t('admin.s1.gauge.backup.go')}
        </Link>
      </Tile>,
    );
  } else if (backup) {
    const level = levelOf(backup[1].status);
    tiles.push(
      <Tile key="backup" title={t('admin.s1.gauge.backup')} level={level} data-search-anchor="gauge-backup">
        <p className={styles.tileBig}>—</p>
        <p className={styles.tileSentence}>{backup[1].message ?? t('admin.s1.gauge.backup.unknown')}</p>
        <Link className={styles.tileLink} to={paths.admin.backup}>
          {t('admin.s1.gauge.backup.go')}
        </Link>
      </Tile>,
    );
  }

  if (queues.length > 0) {
    const level = worstLevel(queues.map(([, v]) => levelOf(v.status)));
    tiles.push(
      <Tile key="queues" title={t('admin.s1.gauge.queues')} level={level} data-search-anchor="gauge-queues">
        <ul className={styles.tileList}>
          {queues
            .filter(([k, v]) => k.endsWith('.dead') || levelOf(v.status) !== 'OK')
            .map(([k, v]) => (
              <li key={k}>
                <StatusDot tone={DOT[levelOf(v.status)]}>
                  {nameOf(i18n, k)}: {valueText(i18n, k, v)}
                </StatusDot>
              </li>
            ))}
        </ul>
        <p className={styles.tileSentence}>{level === 'OK' ? t('admin.s1.gauge.queues.ok') : t('admin.s1.gauge.queues.bad')}</p>
      </Tile>,
    );
  }

  if (jobs.length > 0) {
    const total = jobs.length;
    const okCount = jobs.filter(([, v]) => levelOf(v.status) === 'OK').length;
    const level = worstLevel(jobs.map(([, v]) => levelOf(v.status)));
    tiles.push(
      <Tile key="jobs" title={t('admin.s1.gauge.jobs')} level={level} data-search-anchor="gauge-jobs">
        <ProgressRing
          value={okCount}
          max={total}
          label={t('admin.s1.gauge.jobs.ring')}
          center={`${i18n.formatNumber(okCount)}/${i18n.formatNumber(total)}`}
          tone={RING[level]}
          size={96}
          thickness={10}
        />
        <p className={styles.tileSentence}>
          {okCount === total
            ? t('admin.s1.gauge.jobs.ok', { n: i18n.formatNumber(total) })
            : t('admin.s1.gauge.jobs.bad', { bad: i18n.formatNumber(total - okCount), n: i18n.formatNumber(total) })}
        </p>
      </Tile>,
    );
  }

  if (tiles.length === 0) return null;
  return (
    <section className={styles.tiles} aria-label={t('admin.s1.gauge.title')} data-testid="key-gauges">
      {tiles}
    </section>
  );
}

// ---------- Oturum sağlık çizelgesi ----------
const HISTORY_KEY = 'bu-admin-sys-health-history';

/** Her yenilemede genel durumu kaydeder (bu tarayıcı oturumu). Sunucu geçmişi sunmadığından çizelge buradan gelir. */
export function useHealthHistory(sampleAt: number, level: SystemLevel | null): HistorySample[] {
  const [history, setHistory] = useState<HistorySample[]>(() => readHistory(HISTORY_KEY));
  const last = useRef(0);
  useEffect(() => {
    if (!sampleAt || !level || last.current === sampleAt) return;
    last.current = sampleAt;
    setHistory((prev) => pushSample(prev, { at: sampleAt, level }, HISTORY_MAX));
  }, [sampleAt, level]);
  useEffect(() => {
    if (history.length > 0) writeHistory(HISTORY_KEY, history);
  }, [history]);
  return history;
}

export function HealthTimeline({ i18n, history }: { i18n: I18n; history: HistorySample[] }) {
  const t = s1(i18n);
  const sum = summarizeHistory(history);
  const timeOf = (at: number) => i18n.formatDate(at, { hour: '2-digit', minute: '2-digit' });
  let sentence: string;
  let tone: 'good' | 'warn' | 'bad' | 'info' = 'info';
  if (sum.total < 2) sentence = t('admin.s1.timeline.few');
  else if (sum.good === sum.total) {
    sentence = t('admin.s1.timeline.allGood', { n: i18n.formatNumber(sum.total) });
    tone = 'good';
  } else {
    sentence = t('admin.s1.timeline.someBad', {
      n: i18n.formatNumber(sum.total),
      bad: i18n.formatNumber(sum.attention + sum.urgent),
      time: sum.lastBadAt ? timeOf(sum.lastBadAt) : '—',
    });
    tone = sum.urgent > 0 ? 'bad' : 'warn';
  }
  return (
    <Card title={t('admin.s1.timeline.title')} data-search-anchor="health-timeline">
      <div className={styles.stack}>
        <Insight tone={tone} parts={sentence} />
        {history.length > 0 && (
          <>
            <ol className={styles.timeline} aria-label={t('admin.s1.timeline.aria')} data-testid="health-timeline">
              {history.map((h) => {
                const v = verdictOf(h.level);
                return (
                  <li key={h.at} className={styles.timeBar} data-verdict={v} title={`${timeOf(h.at)}: ${t(`admin.s1.light.${v}`)}`}>
                    <span className="sr-only">
                      {timeOf(h.at)}: {t(`admin.s1.light.${v}`)}
                    </span>
                  </li>
                );
              })}
            </ol>
            <div className={styles.timeAxis} aria-hidden="true">
              <span>{timeOf(history[0].at)}</span>
              <span>{timeOf(history[history.length - 1].at)}</span>
            </div>
          </>
        )}
        <p className={styles.note}>{t('admin.s1.timeline.note')}</p>
      </div>
    </Card>
  );
}

// ---------- Otomatik görev şeridi ----------
export function JobLanes({ i18n, entries }: { i18n: I18n; entries: Entry[] }) {
  const t = s1(i18n);
  const lanes = jobLanes(entries);
  if (lanes.length === 0) return null;
  const bad = lanes.filter((l) => l.level !== 'OK').length;
  return (
    <Card title={t('admin.s1.jobs.title')} data-search-anchor="job-lanes">
      <div className={styles.stack}>
        <Insight
          tone={bad > 0 ? 'warn' : 'good'}
          parts={bad > 0 ? t('admin.s1.jobs.bad', { bad: i18n.formatNumber(bad), n: i18n.formatNumber(lanes.length) }) : t('admin.s1.jobs.ok', { n: i18n.formatNumber(lanes.length) })}
        />
        <ul className={styles.lanes} data-testid="job-lanes">
          {lanes.map((l) => {
            const ind = entries.find(([k]) => k === l.id)?.[1];
            const when = ind ? valueText(i18n, l.id, ind) : '—';
            return (
              <li key={l.id} className={styles.lane} data-status={l.level}>
                <span className={styles.laneHead}>
                  <Icon name={l.level === 'OK' ? 'check' : l.level === 'WARN' ? 'alert' : l.level === 'CRIT' ? 'x' : 'help'} size={14} aria-hidden="true" />
                  <span className="sr-only">{i18n.t(`admin.system.status.${l.level}` as 'admin.system.status.OK')}: </span>
                  <span className={styles.laneName}>{nameOf(i18n, l.id)}</span>
                  <span className={styles.laneWhen}>{when}</span>
                </span>
                <ZoneGauge
                  scale={l.scale}
                  level={l.level}
                  label={t('admin.s1.jobs.aria', { name: nameOf(i18n, l.id), when })}
                />
              </li>
            );
          })}
        </ul>
        <p className={styles.note}>{t('admin.s1.jobs.note')}</p>
      </div>
    </Card>
  );
}

