import { useQuery } from '@tanstack/react-query';
import { adminUnitNewsApi, qk } from '../../../api';
import type { UnitDepartment, UnitSource } from '../../../api/adminUnitNews';
import { Badge, Drawer, EmptyState, ErrorState, Table, type Column } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { errorMessage } from '../../../lib/errors';
import { gt } from './dict';
import styles from './unitNews.module.css';

/** Kaynağın bölümleri (GET /sources/{code}/departments), salt okunur. */
export function DepartmentsDrawer({ source, onClose }: { source: UnitSource | null; onClose: () => void }) {
  const i18n = useI18n();
  const t = gt(i18n);
  const code = source?.code ?? '';
  const q = useQuery({
    queryKey: qk.unitNews.departments(code),
    queryFn: () => adminUnitNewsApi.listDepartments(code),
    enabled: !!source,
  });

  const columns: Column<UnitDepartment>[] = [
    { key: 'name', header: t('admin.unitNews.departments.col.name'), render: (d) => <span dir="auto">{d.name}</span> },
    { key: 'slug', header: t('admin.unitNews.departments.col.slug'), render: (d) => <code dir="ltr">{d.slug}</code> },
    {
      key: 'feed',
      header: t('admin.unitNews.departments.col.feed'),
      render: (d) =>
        d.hasOwnFeed ? (
          <Badge tone="success">{t('admin.unitNews.departments.yes')}</Badge>
        ) : (
          <Badge>{t('admin.unitNews.departments.no')}</Badge>
        ),
    },
  ];

  return (
    <Drawer
      open={!!source}
      onClose={onClose}
      size="lg"
      title={t('admin.unitNews.departments.title', { name: source?.name ?? '' })}
    >
      <p className={styles.muted}>{t('admin.unitNews.departments.readonly')}</p>
      {q.isError ? (
        <ErrorState onRetry={() => void q.refetch()} description={errorMessage(i18n, q.error)} />
      ) : (
        <Table
          caption={t('admin.unitNews.departments.title', { name: source?.name ?? '' })}
          columns={columns}
          rows={q.data}
          rowKey={(d) => d.slug}
          loading={q.isLoading}
          empty={<EmptyState compact icon="list" title={t('admin.unitNews.departments.empty')} />}
        />
      )}
    </Drawer>
  );
}
