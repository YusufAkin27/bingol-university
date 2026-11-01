// Geri bildirim özeti: tüm geri bildirimlerin durum ve tür dağılımı (liste sayfasındaki 20 kayda bağlı değil).
// API: GET /api/admin/analytics/support (feedbackByStatus, feedbackByCategory).
import { useQuery } from '@tanstack/react-query';
import { analyticsApi, qk } from '../../../api';
import type { FeedbackStatus } from '../../../api/types';
import {
  StackedShare,
  type ShareSegment,
  type ShareTone,
} from '../../../components/kit/StackedShareIletisim';
import { Card, Insight, ProgressRing, RankedBars, StatTile } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { useIl } from './il';
import { countsByKey } from './logic';
import styles from './iletisim.module.css';

const STATUSES: FeedbackStatus[] = ['NEW', 'IN_REVIEW', 'PLANNED', 'DONE', 'REJECTED'];
const CATEGORIES = ['BUG', 'SUGGESTION', 'COMPLAINT', 'PRAISE', 'OTHER'] as const;
const TONE: Record<FeedbackStatus, ShareTone> = {
  NEW: 'warning',
  IN_REVIEW: 'info',
  PLANNED: 'primary',
  DONE: 'success',
  REJECTED: 'neutral',
};

export interface FeedbackOverviewProps {
  status: FeedbackStatus | '';
  onStatus: (s: FeedbackStatus | '') => void;
}

export function FeedbackOverview({ status, onStatus }: FeedbackOverviewProps) {
  const { t, formatNumber } = useI18n();
  const il = useIl();
  const q = useQuery({
    queryKey: qk.analytics.support(),
    queryFn: analyticsApi.getSupportAnalytics,
    staleTime: 60_000,
  });
  const st = countsByKey(q.data?.feedbackByStatus, STATUSES);
  const cat = countsByKey(q.data?.feedbackByCategory, CATEGORIES);
  const total = STATUSES.reduce((s, k) => s + st[k], 0);
  const handled = total - st.NEW;
  const handledPct = total > 0 ? Math.round((handled / total) * 100) : null;

  const segments: ShareSegment[] = STATUSES.map((k) => ({
    key: k,
    label: t(`admin.feedback.status.${k}`),
    value: st[k],
    tone: TONE[k],
  }));
  const catItems = CATEGORIES.map((k) => ({
    key: k,
    label: t(`admin.feedback.category.${k}`),
    value: cat[k],
  })).filter((x) => x.value > 0);

  return (
    <section data-search-anchor="fb-summary" aria-label={il('admin.il.fb.summary')}>
      <div className={styles.tiles}>
        <StatTile
          className={styles.tileBox}
          label={il('admin.il.fb.tile.new')}
          value={q.data ? st.NEW : undefined}
          unit={il('admin.il.fb.tile.newUnit')}
          icon="message"
          caption={il('admin.il.fb.tile.newHint')}
          loading={q.isLoading}
          error={q.isError}
          onRetry={() => void q.refetch()}
        />
        <StatTile
          className={styles.tileBox}
          label={il('admin.il.fb.tile.planned')}
          value={q.data ? st.PLANNED : undefined}
          unit={il('admin.il.fb.tile.plannedUnit')}
          icon="clipboard"
          caption={il('admin.il.fb.tile.plannedHint', { done: formatNumber(st.DONE) })}
          loading={q.isLoading}
          error={q.isError}
          onRetry={() => void q.refetch()}
        />
        <div className={styles.ringBox}>
          <ProgressRing
            value={handledPct}
            label={il('admin.il.fb.ring')}
            tone={
              handledPct === null
                ? 'neutral'
                : handledPct >= 80
                  ? 'success'
                  : handledPct >= 50
                    ? 'warning'
                    : 'danger'
            }
            size={104}
            loading={q.isLoading}
          />
        </div>
      </div>
      {q.data && (
        <Insight
          className={styles.sentence}
          tone={st.NEW > 0 ? 'warn' : 'good'}
          parts={[
            st.NEW > 0
              ? {
                  text: il('admin.il.fb.sentence.new', {
                    n: formatNumber(st.NEW),
                    total: formatNumber(total),
                  }),
                  tone: 'warn',
                }
              : { text: il('admin.il.fb.sentence.none', { total: formatNumber(total) }), tone: 'good' },
          ]}
        />
      )}
      <div className={styles.grid2}>
        <Card title={il('admin.il.fb.dist.title')} data-search-anchor="fb-status-dist">
          {q.isError ? (
            <p role="alert">{il('admin.il.err.load')}</p>
          ) : (
            <StackedShare
              segments={segments}
              ariaLabel={il('admin.il.fb.dist.aria')}
              selectedKey={status || null}
              onSelect={(k) => onStatus(k === status ? '' : (k as FeedbackStatus))}
            />
          )}
        </Card>
        <Card title={il('admin.il.fb.cat.title')} data-search-anchor="fb-category-dist">
          <RankedBars
            items={catItems}
            ariaLabel={il('admin.il.fb.cat.title')}
            limit={5}
            showShare
            loading={q.isLoading}
            error={q.isError}
            onRetry={() => void q.refetch()}
            emptyLabel={il('admin.il.fb.cat.empty')}
            formatValue={(n) => il('admin.il.fb.cat.count', { n: formatNumber(n) })}
          />
        </Card>
      </div>
    </section>
  );
}
