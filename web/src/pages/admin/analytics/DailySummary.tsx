// Analitik > Genel: bugünün özeti. "Bugün 120 kişi girdi, dün 98 idi: %22 fazla" + üç büyük kutu (giren, yeni üye, geri dönen).
// API: GET /api/admin/analytics/overview, /active-users, /registrations (son 30 gün; dünün değeri günlük seriden okunur).
// Dünün değeri yoksa karşılaştırma yazılmaz (uydurma yüzde yok). "Geri dönen" = bugün girenlerden bugün kayıt olmayanlar (yaklaşık).
import { useQuery } from '@tanstack/react-query';
import { useMemo } from 'react';
import { getActiveUsers, getOverview, getRegistrations } from '../../../api/analytics';
import { qk } from '../../../api/queryKeys';
import { Insight, StatTile, percentChange, useCompareSentence } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { istanbulYesterday, lastDaysIstanbul } from '../../../lib/date';
import styles from './analytics.module.css';

export function DailySummary() {
  const { t } = useI18n();
  const sentence = useCompareSentence();
  const range = useMemo(() => lastDaysIstanbul(30), []);
  // Dün, panelin iş günü olan Europe/Istanbul gününe göre (tarayıcı saat diliminden bağımsız)
  const yesterday = useMemo(() => istanbulYesterday(), []);
  const overview = useQuery({ queryKey: qk.analytics.overview(), queryFn: getOverview });
  const active = useQuery({
    queryKey: qk.analytics.activeUsers(range),
    queryFn: () => getActiveUsers(range),
  });
  const regs = useQuery({
    queryKey: qk.analytics.registrations(range),
    queryFn: () => getRegistrations(range),
  });

  const o = overview.data;
  if (overview.isError || (!overview.isLoading && !o)) return null; // sayfadaki kartlar kendi hatasını gösterir
  const yDau = active.data?.points.find((p) => p.date === yesterday)?.dau;
  const yNew = regs.data?.points.find((p) => p.date === yesterday)?.count;
  const dau = o?.activeUsers.dau;
  const fresh = o?.newUsers.today;
  const back = dau !== undefined && fresh !== undefined ? Math.max(0, dau - fresh) : undefined;
  const yBack = yDau !== undefined && yNew !== undefined ? Math.max(0, yDau - yNew) : undefined;
  const hero =
    dau !== undefined
      ? sentence({
          nowLabel: t('admin.v2p.dash.today'),
          current: dau,
          thenLabel: t('admin.v2p.dash.yesterday'),
          previous: yDau,
          unit: t('admin.v2p.unit.person'),
          verb: t('admin.v2p.dash.verbEntered'),
          partial: true, // bugün henüz bitmedi: dünün tamamıyla kıyas nötr ve "şu ana kadar" diye yazılır
        })
      : null;

  return (
    <section className={styles.summaryBox} aria-label={t('admin.v2p.dash.heroLabel')} data-search-anchor="anl-today">
      {hero && <Insight parts={hero.parts} tone={hero.tone} />}
      <div className={styles.summaryTiles}>
        <StatTile
          label={t('admin.v2p.dash.tile.entered')}
          value={dau}
          unit={t('admin.v2p.unit.person')}
          icon="users"
          change={dau !== undefined ? percentChange(dau, yDau) : null}
          goodWhen="neutral"
          compareLabel={t('admin.v2p.dash.fromYesterdayWhole')}
          spark={active.data?.points.map((p) => p.dau)}
          loading={overview.isLoading}
        />
        <StatTile
          label={t('admin.v2p.dash.tile.new')}
          value={fresh}
          unit={t('admin.v2p.unit.person')}
          icon="plus"
          change={fresh !== undefined ? percentChange(fresh, yNew) : null}
          goodWhen="neutral"
          compareLabel={t('admin.v2p.dash.fromYesterdayWhole')}
          spark={regs.data?.points.map((p) => p.count)}
          loading={overview.isLoading}
        />
        <StatTile
          label={t('admin.v2p.dash.tile.returning')}
          value={back}
          unit={t('admin.v2p.unit.person')}
          icon="home"
          change={back !== undefined ? percentChange(back, yBack) : null}
          goodWhen="neutral"
          compareLabel={t('admin.v2p.dash.fromYesterdayWhole')}
          caption={t('admin.v2p.dash.tile.returningHint')}
          loading={overview.isLoading}
        />
      </div>
    </section>
  );
}
