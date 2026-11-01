// Sistem durumu: gönderilemeyen (vazgeçilen) e-posta/bildirim kayıtları. Telefonda kart yığını; uzun hata metni 2 satıra kırpılır.
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { qk, systemApi } from '../../../api';
import type { DeadKind } from '../../../api/system';
import {
  ActionBar,
  Button,
  Card,
  ConfirmDialog,
  EmptyState,
  ErrorState,
  ResponsiveTable,
  Skeleton,
  Tabs,
  useToast,
  type Column,
} from '../../../components/ui';
import type { I18n } from '../../../i18n/I18nProvider';
import { useUrlTab } from '../../../search/useUrlTab';
import { adminErrorMessage } from '../campaigns/shared';
import styles from './systemstatus.module.css';

const DEAD_KINDS: DeadKind[] = ['mail', 'push'];

interface DeadRow {
  id: number;
  /** Başlık: e-postada şablon, bildirimde kullanıcı. */
  title: string;
  /** E-postada alıcı; bildirimde boş. */
  to: string | null;
  attempts: number;
  created: string;
  error: string | null;
}

/** Uzun hata metni: 2 satır + "Tamamını göster". */
function ErrorText({ i18n, text }: { i18n: I18n; text: string | null }) {
  const [open, setOpen] = useState(false);
  if (!text) return <span className={styles.muted}>—</span>;
  const long = text.length > 90;
  return (
    <span className={styles.errWrap}>
      <span className={open || !long ? styles.errFull : styles.errClamp}>{text}</span>
      {long && (
        <button type="button" className={styles.errToggle} aria-expanded={open} onClick={() => setOpen((v) => !v)}>
          {i18n.t(open ? 'admin.v2n.sys.dead.less' : 'admin.v2n.sys.dead.more')}
        </button>
      )}
    </span>
  );
}

export function DeadLetters({ i18n }: { i18n: I18n }) {
  const { t } = i18n;
  const qc = useQueryClient();
  const toast = useToast();
  const [kind, setKind] = useUrlTab<DeadKind>(DEAD_KINDS, 'mail'); // ?tab=push
  const [selected, setSelected] = useState<Set<string | number>>(new Set());
  const [confirm, setConfirm] = useState(false);

  const q = useQuery({
    queryKey: qk.system.dead(kind),
    queryFn: async (): Promise<DeadRow[]> => {
      if (kind === 'mail') {
        const rows = await systemApi.getDeadMail();
        return rows.map((r) => ({
          id: r.id,
          title: r.template,
          to: r.to,
          attempts: r.attempts,
          created: r.createdAt ? i18n.formatDateTime(r.createdAt) : '—',
          error: r.lastError,
        }));
      }
      const rows = await systemApi.getDeadPush();
      return rows.map((r) => ({
        id: r.id,
        title: r.userId === null ? '—' : t('admin.v2n.sys.dead.userN', { id: String(r.userId) }),
        to: null,
        attempts: r.attempts,
        created: r.createdAt ? i18n.formatDateTime(r.createdAt) : '—',
        error: r.lastError,
      }));
    },
  });

  const done = () => {
    setSelected(new Set());
    void qc.invalidateQueries({ queryKey: qk.system.all });
  };
  const retry = useMutation({
    mutationFn: (ids: number[]) => systemApi.retryDead(kind, ids),
    onSuccess: (r) => {
      toast.success(t('admin.system.dead.retried', { n: String(r?.requeued ?? 0) }));
      done();
    },
    onError: (e) => toast.error(adminErrorMessage(i18n, e)),
  });
  const del = useMutation({
    mutationFn: (ids: number[]) => systemApi.deleteDead(kind, ids),
    onSuccess: (r) => {
      toast.success(t('admin.system.dead.deleted', { n: String(r?.deleted ?? 0) }));
      setConfirm(false);
      done();
    },
    onError: (e) => {
      setConfirm(false);
      toast.error(adminErrorMessage(i18n, e));
    },
  });

  const rows = q.data ?? [];
  const ids = [...selected].map(Number);
  const columns: Column<DeadRow>[] = [
    {
      key: 'title',
      header: t(kind === 'mail' ? 'admin.system.dead.col.template' : 'admin.system.dead.col.user'),
      card: { priority: 1 },
      render: (r) => <strong>{r.title}</strong>,
    },
    ...(kind === 'mail'
      ? [{ key: 'to', header: t('admin.system.dead.col.to'), card: { priority: 2 as const }, render: (r: DeadRow) => r.to ?? '—' }]
      : []),
    {
      key: 'error',
      header: t('admin.system.dead.col.error'),
      card: { priority: 3 },
      render: (r) => <ErrorText i18n={i18n} text={r.error} />,
    },
    { key: 'attempts', header: t('admin.system.dead.col.attempts'), align: 'end', render: (r) => i18n.formatNumber(r.attempts) },
    { key: 'created', header: t('admin.system.dead.col.created'), render: (r) => r.created },
    { key: 'id', header: t('admin.system.dead.col.id'), render: (r) => r.id },
  ];

  return (
    <Card title={t('admin.v2n.sys.dead.title')} data-search-anchor="dead-letters">
      <p className={styles.muted}>{t('admin.v2n.sys.dead.intro')}</p>
      <Tabs
        tabs={[
          { id: 'mail', label: t('admin.v2n.sys.dead.mail') },
          { id: 'push', label: t('admin.v2n.sys.dead.push') },
        ]}
        value={kind}
        onChange={(id) => {
          setKind(id as DeadKind);
          setSelected(new Set());
        }}
        label={t('admin.system.dead.tabs')}
      >
        {q.isError ? (
          <ErrorState compact description={adminErrorMessage(i18n, q.error)} onRetry={() => void q.refetch()} />
        ) : q.isLoading ? (
          <Skeleton height="4rem" width="100%" />
        ) : rows.length === 0 ? (
          <EmptyState compact icon="check" title={t('admin.v2n.sys.dead.empty')} />
        ) : (
          <>
            <ActionBar>
              <Button
                variant="secondary"
                size="sm"
                disabled={ids.length === 0}
                loading={retry.isPending}
                onClick={() => retry.mutate(ids)}
              >
                {t('admin.system.dead.retrySelected')}
              </Button>
              <Button variant="secondary" size="sm" loading={retry.isPending} onClick={() => retry.mutate([])}>
                {t('admin.system.dead.retryAll')}
              </Button>
              <Button variant="danger" size="sm" disabled={ids.length === 0} onClick={() => setConfirm(true)}>
                {t('admin.system.dead.deleteSelected')}
              </Button>
            </ActionBar>
            <ResponsiveTable
              columns={columns}
              rows={rows}
              rowKey={(r) => r.id}
              caption={t('admin.v2n.sys.dead.title')}
              selectedKeys={selected}
              onSelectionChange={setSelected}
              selectLabel={(r) => t('admin.system.dead.selectRow', { id: String(r.id) })}
            />
          </>
        )}
      </Tabs>
      <ConfirmDialog
        open={confirm}
        onClose={() => setConfirm(false)}
        onConfirm={() => del.mutate(ids)}
        title={t('admin.v2n.sys.dead.confirmTitle')}
        message={t('admin.system.dead.confirmMessage', { n: String(ids.length) })}
        confirmLabel={t('admin.system.dead.deleteSelected')}
        danger
        loading={del.isPending}
      />
    </Card>
  );
}
