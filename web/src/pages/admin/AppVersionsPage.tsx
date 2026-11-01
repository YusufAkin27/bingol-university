// SAYFA: Uygulama güncelleme (/admin/app-versions)  [UPDATEGATE]
// API: GET /api/admin/app-versions (sürüm dağılımı), POST /api/admin/app-versions/enforce (api/appVersions.ts);
//      mağaza alanları için GET /api/admin/settings. Okuma: settings.read; yazma: settings.write (sebep + "ZORLA" onayı).
// Cihaz sayıları `user_device_log` kaynaklıdır (giriş yapmış kullanıcıların son 30 günü); kaynak notu sayfada gösterilir.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import {
  APP_PLATFORMS,
  appVersionKeys,
  getAppVersions,
  type AppPlatform,
  type PlatformSummary,
  type VersionDistribution,
  type VersionRow,
} from '../../api/appVersions';
import { qk } from '../../api/queryKeys';
import { getSettings } from '../../api/settings';
import {
  Badge,
  Button,
  Card,
  ErrorState,
  PageHeader,
  PermissionButton,
  Skeleton,
  Table,
  type Column,
  type Tone,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import { SearchAnchor } from '../../search/anchor';
import { adminErrorMessage, Callout } from './campaigns/shared';
import { isInverted, rowStatus, type RowStatus, type StoreInfo } from './appVersions/lib';
import { PreviewDialog } from './appVersions/PreviewDialog';
import { PublishWizard } from './appVersions/PublishWizard';
import styles from './appVersions/appVersions.module.css';

const STATE_TONE: Record<PlatformSummary['state'], Tone> = { FORCE: 'danger', SOFT: 'info', OFF: 'neutral' };
const ROW_TONE: Record<RowStatus, Tone> = { FORCED: 'danger', SUGGESTED: 'warning', CURRENT: 'success', UNKNOWN: 'neutral' };

function storeInfo(settings: Record<string, string>, p: AppPlatform): StoreInfo {
  return {
    storeUrl: settings[`store_url_${p}`] ?? '',
    androidPackage: settings.store_package_android ?? '',
    appleAppId: settings.apple_app_id_ios ?? '',
  };
}

export default function AppVersionsPage() {
  const i18n = useI18n();
  const { t } = i18n;
  usePageTitle(t('admin.uv.title'));
  const qc = useQueryClient();
  const [wizard, setWizard] = useState<AppPlatform | null>(null);
  const [preview, setPreview] = useState<AppPlatform | null>(null);

  const q = useQuery({ queryKey: appVersionKeys.list, queryFn: getAppVersions });
  const settingsQ = useQuery({ queryKey: qk.settings.list(), queryFn: getSettings });
  const settings = settingsQ.data ?? {};
  const data = q.data;

  const refresh = () => {
    void qc.invalidateQueries({ queryKey: appVersionKeys.all });
    void qc.invalidateQueries({ queryKey: qk.settings.all });
  };

  return (
    <>
      <PageHeader
        title={t('admin.uv.title')}
        description={t('admin.uv.desc')}
        actions={
          <Button variant="secondary" onClick={refresh} loading={q.isFetching} data-search-anchor="refresh">
            {t('admin.uv.refresh')}
          </Button>
        }
      />
      {q.isError ? (
        <ErrorState description={adminErrorMessage(i18n, q.error)} onRetry={() => void q.refetch()} />
      ) : !data ? (
        <div className={styles.page} aria-busy="true">
          <Skeleton width="100%" height="12rem" />
          <Skeleton width="100%" height="12rem" />
        </div>
      ) : (
        <div className={styles.page}>
          <SearchAnchor id="source-note">
            <Callout tone="info" title={t('admin.uv.sourceTitle')}>
              {data.sourceNote} ({t('admin.uv.sourceWindow', { n: data.windowDays })})
            </Callout>
          </SearchAnchor>
          <div className={styles.cards}>
            {APP_PLATFORMS.map((p) => {
              const summary = data.platforms.find((s) => s.platform === p);
              return summary ? (
                <PlatformCard
                  key={p}
                  platform={p}
                  summary={summary}
                  data={data}
                  onPublish={() => setWizard(p)}
                  onPreview={() => setPreview(p)}
                />
              ) : null;
            })}
          </div>
        </div>
      )}
      {wizard && data && (
        <PublishWizard
          platform={wizard}
          summary={data.platforms.find((s) => s.platform === wizard)!}
          rows={data.distribution}
          store={storeInfo(settings, wizard)}
          onClose={() => setWizard(null)}
          onDone={() => {
            setWizard(null);
            refresh();
          }}
        />
      )}
      {preview && (
        <PreviewDialog
          platform={preview}
          settings={settings}
          store={storeInfo(settings, preview)}
          onClose={() => setPreview(null)}
        />
      )}
    </>
  );
}

function PlatformCard({
  platform,
  summary,
  data,
  onPublish,
  onPreview,
}: {
  platform: AppPlatform;
  summary: PlatformSummary;
  data: VersionDistribution;
  onPublish: () => void;
  onPreview: () => void;
}) {
  const { t, formatNumber } = useI18n();
  const name = t(`admin.uv.platform.${platform}`);
  const rows = data.distribution.filter((r) => r.platform === platform);
  const columns: Column<VersionRow>[] = [
    {
      key: 'version',
      header: t('admin.uv.table.version'),
      render: (r) =>
        r.version ? <span className={styles.ltr}>{r.version}</span> : t('admin.uv.table.unknownVersion'),
    },
    { key: 'devices', header: t('admin.uv.table.devices'), align: 'end', render: (r) => formatNumber(r.devices) },
    {
      key: 'status',
      header: t('admin.uv.table.status'),
      render: (r) => {
        const s = rowStatus(r, summary);
        return <Badge tone={ROW_TONE[s]}>{t(`admin.uv.row.${s}`)}</Badge>;
      },
    },
  ];
  return (
    <Card as="section" aria-label={name} data-search-anchor={`platform-${platform}`}>
      <div className={styles.head}>
        <h2 style={{ margin: 0 }}>{name}</h2>
        <Badge tone={STATE_TONE[summary.state]}>{t(`admin.uv.state.${summary.state}`)}</Badge>
      </div>
      <div className={styles.stats}>
        <Stat label={t('admin.uv.stat.latest')} value={summary.latestVersion} ltr />
        <Stat label={t('admin.uv.stat.min')} value={summary.minVersion} ltr />
        <Stat label={t('admin.uv.stat.devices')} value={formatNumber(summary.total)} />
        <Stat label={t('admin.uv.stat.belowLatest')} value={formatNumber(summary.belowLatest)} />
      </div>
      <p className={`${styles.below} ${summary.belowMin > 0 ? styles.belowWarn : styles.muted}`} data-testid={`uv-below-${platform}`}>
        {summary.belowMin > 0
          ? t('admin.uv.belowMin', { n: formatNumber(summary.belowMin) })
          : t('admin.uv.belowMinNone')}
        {summary.unknownVersion > 0 && (
          <span className={styles.muted}>
            {' '}
            · {t('admin.uv.stat.unknown')}: {formatNumber(summary.unknownVersion)}
          </span>
        )}
      </p>
      {isInverted(summary.minVersion, summary.latestVersion) && (
        <Callout tone="warning">{t('admin.uv.inverted')}</Callout>
      )}
      <div className={styles.tableWrap}>
        <Table
          columns={columns}
          rows={rows}
          rowKey={(r) => `${r.platform}-${r.version ?? 'x'}`}
          caption={t('admin.uv.table.caption', { platform: name })}
          empty={<p>{t('admin.uv.table.empty', { n: data.windowDays })}</p>}
        />
      </div>
      <div className={styles.actions}>
        <PermissionButton
          permission="settings.write"
          onClick={onPublish}
          data-testid={`uv-publish-${platform}`}
          data-search-anchor={`publish-${platform}`}
        >
          {t('admin.uv.publish')}
        </PermissionButton>
        <Button
          variant="secondary"
          onClick={onPreview}
          data-testid={`uv-preview-${platform}`}
          data-search-anchor={`preview-${platform}`}
        >
          {t('admin.uv.preview')}
        </Button>
      </div>
    </Card>
  );
}

function Stat({ label, value, ltr }: { label: string; value: string; ltr?: boolean }) {
  return (
    <div className={styles.stat}>
      <span className={styles.statLabel}>{label}</span>
      <span className={`${styles.statValue} ${ltr ? styles.ltr : ''}`}>{value}</span>
    </div>
  );
}
