// Kuyruk yaşı paneli: bekleyen (ya da listedeki) kayıtların ne kadar süredir beklediğini 4 çubukla gösterir,
// altında TEK cümlelik düz Türkçe yorum verir. Sayılar yalnız çubuğun yanında; "acil" renk + rozet metniyle söylenir.
import { useMemo } from 'react';
import { ErrorState, Insight, Skeleton, type InsightPart, type InsightTone } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { useGt } from './dict';
import { PriorityBadge } from './PriorityBadge';
import { ageHistogram, oldestAgeMs, type AgeBucketId, type Urgency } from './queueLogic';
import { waitText } from './waitText';
import styles from './yaptirim.module.css';

export interface QueueAgePanelProps {
  title: string;
  /** Sayılan şeyin adı, cümlede kullanılır: "itiraz", "öneri", "kayıt". */
  noun: string;
  dates: ReadonlyArray<string | null | undefined>;
  now: number;
  /** Liste sınıra takıldı: sayılar "en az" anlamındadır. */
  truncated?: boolean;
  /** `queue`: eski = kötü (renkli, rozetli); `plain`: yalnız dağılım (renk uyarı vermez). */
  variant?: 'queue' | 'plain';
  anchor: string;
  /** Kayıt yokken yazılacak cümle (varsayılan: "Şu an bekleyen ... yok; kuyruk temiz."). */
  emptyText?: string;
  loading?: boolean;
  error?: boolean;
  onRetry?: () => void;
}

const QUEUE_TONE: Record<AgeBucketId, 'info' | 'warning' | 'danger'> = {
  fresh: 'info',
  recent: 'info',
  aging: 'warning',
  stale: 'danger',
};
const BUCKET_URGENCY: Record<AgeBucketId, Urgency> = { fresh: 'normal', recent: 'normal', aging: 'attention', stale: 'urgent' };

export function QueueAgePanel({
  title,
  noun,
  dates,
  now,
  truncated,
  variant = 'queue',
  anchor,
  emptyText,
  loading,
  error,
  onRetry,
}: QueueAgePanelProps) {
  const i18n = useI18n();
  const gt = useGt();
  const { formatNumber } = i18n;
  const hist = useMemo(() => ageHistogram(dates, now), [dates, now]);
  const total = hist.reduce((n, b) => n + b.count, 0);
  const max = Math.max(1, ...hist.map((b) => b.count));
  const oldest = oldestAgeMs(dates, now);
  const aging = hist.find((b) => b.id === 'aging')?.count ?? 0;
  const stale = hist.find((b) => b.id === 'stale')?.count ?? 0;
  const n = formatNumber(total);
  const nTxt = truncated ? gt('admin.mod1.age.atLeast', { n }) : n;

  let tone: InsightTone = 'good';
  let parts: InsightPart[];
  if (total === 0) {
    tone = 'good';
    parts = [emptyText ?? gt('admin.mod1.age.empty', { noun })];
  } else if (variant === 'plain') {
    tone = 'info';
    parts = [gt('admin.mod1.age.plain', { n: nTxt, noun, oldest: waitText(oldest, gt, formatNumber) })];
  } else if (stale > 0) {
    tone = 'bad';
    parts = [
      gt('admin.mod1.age.urgent', {
        n: nTxt,
        noun,
        k: formatNumber(stale),
        oldest: waitText(oldest, gt, formatNumber),
      }),
    ];
  } else if (aging > 0) {
    tone = 'warn';
    parts = [
      gt('admin.mod1.age.attention', { n: nTxt, noun, k: formatNumber(aging), oldest: waitText(oldest, gt, formatNumber) }),
    ];
  } else {
    parts = [gt('admin.mod1.age.ok', { n: nTxt, noun })];
  }
  if (truncated && total > 0) parts = [...parts, ' ', gt('admin.mod1.age.truncated', { max: formatNumber(total) })];

  return (
    <section className={styles.panel} data-search-anchor={anchor} aria-label={title}>
      <h2 className={styles.panelTitle}>{title}</h2>
      {error ? (
        <ErrorState compact description={gt('admin.mod1.age.error')} onRetry={onRetry} />
      ) : loading ? (
        <Skeleton height="9rem" width="100%" />
      ) : (
        <>
          <Insight tone={tone} parts={parts} />
          <ul className={styles.ageList} aria-label={title}>
            {hist.map((b) => {
              const pct = (b.count / max) * 100;
              const urgency = BUCKET_URGENCY[b.id];
              const toneClass = variant === 'plain' ? styles.toneplain : styles[`tone${QUEUE_TONE[b.id]}`];
              return (
                <li key={b.id} className={styles.ageRow}>
                  <span className={styles.ageLabel}>{gt(`admin.mod1.age.b.${b.id}`)}</span>
                  <span className={styles.ageTrack} aria-hidden="true">
                    <span
                      className={`${styles.ageFill} ${toneClass} ${b.count === 0 ? styles.ageFillEmpty : ''}`}
                      style={{ inlineSize: `${pct}%` }}
                    />
                  </span>
                  <span className={styles.ageCount}>
                    {formatNumber(b.count)}
                    {variant === 'queue' && b.count > 0 && urgency !== 'normal' && <PriorityBadge urgency={urgency} />}
                  </span>
                </li>
              );
            })}
          </ul>
        </>
      )}
    </section>
  );
}
