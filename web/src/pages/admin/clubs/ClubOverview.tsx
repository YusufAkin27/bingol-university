// Kulüp listesi üstündeki özet: durum dağılımı TÜM sayfaları kapsar (her durum için 1 kayıtlık sorgu, `total` okunur);
// önceki sürüm yalnız açık sayfadaki 20 kaydı sayıyordu. Süzgeçler (kategori, görünürlük...) korunur, durum süzgeci yok sayılır.
import { useQueries } from '@tanstack/react-query';
import { useState } from 'react';
import { listClubs, type ClubFilters, type ClubRow, type ClubStatus } from '../../../api/adminCommunities';
import { Button, Insight, RankedBars } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { StackedBar, type StackPart } from '../community/Summary';
import { tp } from '../community/tp';
import styles from './clubs.module.css';

const DIST: ClubStatus[] = ['ACTIVE', 'PENDING_REVIEW', 'HIDDEN', 'REJECTED'];
const TONE: Record<string, StackPart['tone']> = {
  ACTIVE: 'success',
  PENDING_REVIEW: 'warning',
  HIDDEN: 'neutral',
  REJECTED: 'danger',
};

export function ClubOverview({
  filters,
  pageItems,
  ready,
  onOpenQueue,
}: {
  /** Durum dışındaki süzgeçler. */
  filters: ClubFilters;
  /** Açık sayfadaki kulüpler (en kalabalıklar sıralaması için). */
  pageItems: ClubRow[];
  /** Liste yüklendikten sonra çalışır: ana liste isteği dağılım sorgularının önüne geçer. */
  ready: boolean;
  onOpenQueue?: () => void;
}) {
  const i18n = useI18n();
  const { t, formatNumber } = i18n;
  const x = tp(i18n);
  const [topOpen, setTopOpen] = useState(false);
  const base = { ...filters, status: '' as const, sort: 'createdAt' as const, dir: 'desc' as const };
  const results = useQueries({
    queries: DIST.map((status) => ({
      queryKey: ['communities', 'admin', 'totals', status, base.q, base.category, base.visibility, base.joinPolicy, base.reportedOnly],
      queryFn: () => listClubs({ ...base, status }, 0, 1),
      staleTime: 30_000,
      retry: false,
      enabled: ready,
    })),
  });
  const loading = results.some((r) => r.isPending);
  const failed = results.some((r) => r.isError);
  if (!ready) return null; // liste yüklenemezse dağılım da çizilmez
  if (loading) return <div className={styles.summary} aria-busy="true" style={{ minBlockSize: '5.5rem' }} />;
  if (failed) return null; // liste çalışmaya devam eder; dağılım yardımcı bilgidir

  const counts = Object.fromEntries(DIST.map((s, i) => [s, results[i]?.data?.total ?? 0])) as Record<ClubStatus, number>;
  const total = DIST.reduce((sum, s) => sum + counts[s], 0);
  const top = [...pageItems]
    .sort((a, b) => b.memberCount - a.memberCount)
    .slice(0, 5)
    .map((c) => ({
      key: String(c.id),
      label: c.name,
      value: c.memberCount,
      hint: x('admin.tp.club.membersHint', { n: formatNumber(c.memberCount) }),
    }));

  return (
    <section className={styles.summary} aria-label={x('admin.tp.club.distTitle')} data-search-anchor="club-dist">
      <Insight
        tone={counts.PENDING_REVIEW > 0 ? 'warn' : 'info'}
        parts={
          total === 0
            ? x('admin.tp.club.insightNone')
            : x('admin.tp.club.insight', {
                total: formatNumber(total),
                active: formatNumber(counts.ACTIVE),
                pending: formatNumber(counts.PENDING_REVIEW),
              })
        }
      />
      <StackedBar
        ariaLabel={x('admin.tp.club.distAria')}
        parts={DIST.map((s) => ({
          key: s,
          label: t(`admin.p06.status.${s}`),
          value: counts[s],
          tone: TONE[s] ?? 'neutral',
        }))}
      />
      {counts.PENDING_REVIEW > 0 && onOpenQueue && (
        <div>
          <Button variant="secondary" onClick={onOpenQueue}>
            {x('admin.tp.club.goQueue', { n: formatNumber(counts.PENDING_REVIEW) })}
          </Button>
        </div>
      )}
      {top.length > 1 && (
        <details className={styles.topMembers} onToggle={(e) => setTopOpen(e.currentTarget.open)}>
          <summary>{x('admin.tp.club.topMembers')}</summary>
          {topOpen && <RankedBars items={top} ariaLabel={x('admin.tp.club.topMembersAria')} limit={5} />}
        </details>
      )}
    </section>
  );
}
