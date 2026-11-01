import { useMutation, useQuery, useQueryClient, type UseQueryResult } from '@tanstack/react-query';
import { useState } from 'react';
import { adminUnitNewsApi, qk } from '../../../api';
import { useCan } from '../../../auth/permissions';
import type { UnitSource } from '../../../api/adminUnitNews';
import {
  Badge,
  Button,
  Card,
  ConfirmDialog,
  EmptyState,
  ErrorState,
  Icon,
  StatusPill,
  ResponsiveTable,
  Switch,
  useToast,
  type Column,
} from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { errorMessage } from '../../../lib/errors';
import { DepartmentsDrawer } from './DepartmentsDrawer';
import { MappingModal } from './MappingModal';
import { gt } from './dict';
import styles from './unitNews.module.css';

export function useUnitSources(): UseQueryResult<UnitSource[]> {
  return useQuery({ queryKey: qk.unitNews.sources(), queryFn: adminUnitNewsApi.listSources });
}

export function SourcesSection({ query }: { query: UseQueryResult<UnitSource[]> }) {
  const i18n = useI18n();
  const t = gt(i18n);
  const { formatDateTime } = i18n;
  const toast = useToast();
  const qc = useQueryClient();
  const canWrite = useCan('content.write');
  const noPerm = canWrite ? undefined : t('admin.unitNews.noPermission');

  const [mapping, setMapping] = useState<UnitSource | null>(null);
  const [deps, setDeps] = useState<UnitSource | null>(null);
  const [confirmAll, setConfirmAll] = useState(false);

  const update = useMutation({
    mutationFn: (v: { source: UnitSource; enabled: boolean; facultyKeys: string[]; kind: 'toggle' | 'mapping' }) =>
      adminUnitNewsApi.updateSource(v.source.code, { enabled: v.enabled, facultyKeys: v.facultyKeys }),
    onSuccess: (_d, v) => {
      if (v.kind === 'mapping') {
        toast.success(t('admin.unitNews.mapping.saved'));
        setMapping(null);
      } else {
        toast.success(t(v.enabled ? 'admin.unitNews.toggledOn' : 'admin.unitNews.toggledOff'));
      }
      void qc.invalidateQueries({ queryKey: qk.unitNews.sources() });
    },
    onError: (e) => toast.error(errorMessage(i18n, e)),
  });

  const syncOne = useMutation({
    mutationFn: (s: UnitSource) => adminUnitNewsApi.syncSource(s.code),
    onSuccess: (_d, s) => {
      toast.success(t('admin.unitNews.syncOneDone', { name: s.name }));
      void qc.invalidateQueries({ queryKey: qk.unitNews.sources() });
    },
    onError: (e) => toast.error(errorMessage(i18n, e)),
  });

  const syncAll = useMutation({
    mutationFn: adminUnitNewsApi.syncAll,
    onSuccess: () => {
      toast.success(t('admin.unitNews.syncAllDone'));
      setConfirmAll(false);
      void qc.invalidateQueries({ queryKey: qk.unitNews.sources() });
    },
    onError: (e) => {
      toast.error(errorMessage(i18n, e));
      setConfirmAll(false);
    },
  });

  const columns: Column<UnitSource>[] = [
    {
      key: 'name',
      header: t('admin.unitNews.col.source'),
      card: { priority: 1 },
      render: (s) => (
        <span className={styles.name}>
          <span className={styles.nameRow}>
            <a href={s.baseUrl} target="_blank" rel="noopener noreferrer" dir="auto">
              {s.name}
            </a>
            <Badge tone="info">{t(`admin.unitNews.kind.${s.kind}`)}</Badge>
            {s.graduate && <Badge>{t('admin.unitNews.graduate')}</Badge>}
          </span>
          <code dir="ltr" className={styles.muted}>
            {s.code}
          </code>
        </span>
      ),
    },
    {
      key: 'lastSuccess',
      header: t('admin.unitNews.col.lastSuccess'),
      render: (s) => (s.lastSuccessAt ? formatDateTime(s.lastSuccessAt) : t('admin.unitNews.never')),
    },
    {
      key: 'status',
      header: t('admin.unitNews.col.status'),
      card: { priority: 2 },
      render: (s) => (
        <span className={styles.name}>
          {!s.enabled ? (
            <StatusPill tone="neutral">{t('admin.unitNews.status.disabled')}</StatusPill>
          ) : s.maintenance ? (
            <StatusPill tone="danger">{t('admin.unitNews.status.maintenance')}</StatusPill>
          ) : (
            <StatusPill tone="success">{t('admin.unitNews.status.ok')}</StatusPill>
          )}
          {s.lastMessage && <span className={`${styles.muted} ${styles.statusMsg}`}>{s.lastMessage}</span>}
          {s.lastAttemptAt && (
            <span className={styles.muted}>
              {t('admin.unitNews.status.attempt', { date: formatDateTime(s.lastAttemptAt) })}
            </span>
          )}
        </span>
      ),
    },
    {
      key: 'departments',
      header: t('admin.unitNews.col.departments'),
      align: 'end',
      render: (s) => <span className={styles.num}>{s.departmentCount}</span>,
    },
    {
      key: 'announcements',
      header: t('admin.unitNews.col.announcements'),
      align: 'end',
      render: (s) => <span className={styles.num}>{s.announcementCount}</span>,
    },
    {
      key: 'enabled',
      header: t('admin.unitNews.col.enabled'),
      card: { priority: 3 },
      render: (s) => (
        <span title={noPerm}>
          <Switch
            checked={s.enabled}
            label={<span className="sr-only">{t('admin.unitNews.toggle', { name: s.name })}</span>}
            disabled={!canWrite || (update.isPending && update.variables?.source.code === s.code)}
            onChange={(enabled) =>
              update.mutate({ source: s, enabled, facultyKeys: s.facultyKeys, kind: 'toggle' })
            }
          />
        </span>
      ),
    },
    {
      key: 'actions',
      header: <span className="sr-only">{t('admin.unitNews.col.actions')}</span>,
      headerLabel: t('admin.unitNews.col.actions'),
      card: { actions: true },
      align: 'end',
      render: (s) => (
        <span className={styles.rowActions}>
          <Button
            size="sm"
            variant="secondary"
            aria-label={t('admin.unitNews.mapping.buttonLabel', { name: s.name })}
            disabled={!canWrite}
            title={noPerm}
            onClick={() => setMapping(s)}
          >
            {t('admin.unitNews.mapping.button')}
          </Button>
          <Button
            size="sm"
            variant="secondary"
            aria-label={t('admin.unitNews.departments.buttonLabel', { name: s.name })}
            onClick={() => setDeps(s)}
          >
            {t('admin.unitNews.departments.button')}
          </Button>
          <Button
            size="sm"
            variant="secondary"
            leftIcon={<Icon name="download" size={16} />}
            aria-label={t('admin.unitNews.syncOneLabel', { name: s.name })}
            disabled={!canWrite}
            title={noPerm}
            loading={syncOne.isPending && syncOne.variables?.code === s.code}
            onClick={() => syncOne.mutate(s)}
          >
            {t('admin.unitNews.syncOne')}
          </Button>
        </span>
      ),
    },
  ];

  return (
    <Card
      data-search-anchor="unitnews-sources"
      title={t('admin.unitNews.sources.title')}
      padded={false}
      actions={
        <Button
          size="sm"
          data-search-anchor="unitnews-sync-all"
          leftIcon={<Icon name="download" size={16} />}
          disabled={!canWrite || !query.data?.length}
          title={noPerm}
          onClick={() => setConfirmAll(true)}
        >
          {t('admin.unitNews.syncAll')}
        </Button>
      }
    >
      {query.isError ? (
        <ErrorState onRetry={() => void query.refetch()} description={errorMessage(i18n, query.error)} />
      ) : (
        <ResponsiveTable
          caption={t('admin.unitNews.sources.title')}
          columns={columns}
          rows={query.data}
          rowKey={(s) => s.code}
          loading={query.isLoading}
          skeletonRows={8}
          empty={<EmptyState compact icon="community" title={t('admin.unitNews.sources.empty')} />}
        />
      )}

      <MappingModal
        source={mapping}
        saving={update.isPending && update.variables?.kind === 'mapping'}
        onClose={() => setMapping(null)}
        onSave={(keys) =>
          mapping && update.mutate({ source: mapping, enabled: mapping.enabled, facultyKeys: keys, kind: 'mapping' })
        }
      />
      <DepartmentsDrawer source={deps} onClose={() => setDeps(null)} />
      <ConfirmDialog
        open={confirmAll}
        onClose={() => setConfirmAll(false)}
        onConfirm={() => syncAll.mutate()}
        loading={syncAll.isPending}
        title={t('admin.unitNews.syncAllTitle')}
        message={t('admin.unitNews.syncAllBody')}
        confirmLabel={t('admin.unitNews.syncAllRun')}
      />
    </Card>
  );
}
