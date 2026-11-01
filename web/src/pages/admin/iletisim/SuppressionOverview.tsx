// E-posta engel listesi özeti: kaç adres neden engelli? Her neden için sunucudan yalnız TOPLAM istenir (size=1),
// dört istek paralel gider; böylece dağılım ilk 20 satıra değil tüm listeye dayanır.
// API: GET /api/admin/mail/suppressions?reason=&size=1 (api/adminMailOps.ts).
import { useQueries } from '@tanstack/react-query';
import {
  listSuppressions,
  mailOpsKeys,
  SUPPRESSION_REASONS,
  type SuppressionReason,
} from '../../../api/adminMailOps';
import {
  StackedShare,
  type ShareSegment,
  type ShareTone,
} from '../../../components/kit/StackedShareIletisim';
import { Insight } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { useIl } from './il';
import styles from './iletisim.module.css';

const TONE: Record<SuppressionReason, ShareTone> = {
  UNSUBSCRIBED: 'info',
  BOUNCED: 'warning',
  COMPLAINT: 'danger',
  MANUAL: 'neutral',
};

export interface SuppressionOverviewProps {
  reason: SuppressionReason | '';
  onReason: (r: SuppressionReason | '') => void;
}

export function SuppressionOverview({ reason, onReason }: SuppressionOverviewProps) {
  const { t, formatNumber } = useI18n();
  const il = useIl();
  const results = useQueries({
    queries: SUPPRESSION_REASONS.map((r) => ({
      queryKey: [...mailOpsKeys.suppressions, 'count', r],
      queryFn: () => listSuppressions({ reason: r, size: 1 }),
      staleTime: 60_000,
    })),
  });
  const loading = results.some((r) => r.isLoading);
  const failed = results.some((r) => r.isError);
  const counts = Object.fromEntries(
    SUPPRESSION_REASONS.map((r, i) => [r, results[i].data?.total ?? 0]),
  ) as Record<SuppressionReason, number>;
  const total = SUPPRESSION_REASONS.reduce((s, r) => s + counts[r], 0);

  if (loading)
    return (
      <div
        style={{ minBlockSize: '8.5rem' }}
        aria-busy="true"
        role="status"
        aria-label={il('admin.il.sp.loading')}
      />
    );
  if (failed) {
    return (
      <p role="alert" className={styles.sentence}>
        {il('admin.il.err.load')}{' '}
        <button
          type="button"
          className={styles.clearLink}
          onClick={() => results.forEach((r) => void r.refetch())}
        >
          {t('common.retry')}
        </button>
      </p>
    );
  }
  if (total === 0) return null;

  const segments: ShareSegment[] = SUPPRESSION_REASONS.map((r) => ({
    key: r,
    label: t(`admin.p13.supp.reason.${r}`),
    value: counts[r],
    tone: TONE[r],
    hint: il(`admin.il.sp.hint.${r}`),
  }));
  const optOut = counts.UNSUBSCRIBED + counts.COMPLAINT;

  return (
    <section
      className={styles.spaced}
      data-search-anchor="supp-summary"
      aria-label={il('admin.il.sp.summary')}
    >
      <Insight
        className={styles.sentence}
        tone={counts.COMPLAINT > 0 ? 'warn' : 'info'}
        parts={il(counts.COMPLAINT > 0 ? 'admin.il.sp.sentence.complaint' : 'admin.il.sp.sentence.ok', {
          total: formatNumber(total),
          optOut: formatNumber(optOut),
          complaint: formatNumber(counts.COMPLAINT),
          bounced: formatNumber(counts.BOUNCED),
        })}
      />
      <StackedShare
        segments={segments}
        ariaLabel={il('admin.il.sp.dist.aria', { n: formatNumber(total) })}
        selectedKey={reason || null}
        onSelect={(k) => onReason(k === reason ? '' : (k as SuppressionReason))}
      />
    </section>
  );
}
