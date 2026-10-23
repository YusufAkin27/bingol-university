import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { cancelCampaign, getCampaign } from '../../../api/campaigns';
import { qk } from '../../../api/queryKeys';
import type { CampaignView, Lang } from '../../../api/types';
import { Badge, ConfirmDialog, Drawer, Button, Skeleton, StatusPill, toneFor, useToast } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { DetailList } from '../community/ReviewParts';
import listStyles from '../community/review.module.css';
import { useAdminNames, useAudienceSummary, useTargetSummary } from './format';
import { isLive, LANGS } from './lib';
import { adminErrorMessage, Callout } from './shared';
import styles from './campaigns.module.css';

export function CampaignDrawer({ id, seed, onClose }: { id: number | null; seed?: CampaignView; onClose: () => void }) {
  const i18n = useI18n();
  const { t, formatDateTime, formatNumber } = i18n;
  const toast = useToast();
  const qc = useQueryClient();
  const audienceSummary = useAudienceSummary();
  const targetSummary = useTargetSummary();
  const [confirmCancel, setConfirmCancel] = useState(false);

  const q = useQuery({
    queryKey: qk.campaigns.detail(id ?? 0),
    queryFn: () => getCampaign(id ?? 0),
    enabled: id !== null,
    initialData: seed,
    refetchInterval: (query) => (query.state.data && isLive(query.state.data.status) ? 5000 : false),
  });
  const c = q.data;
  const names = useAdminNames(c ? [c.createdBy] : []);

  const cancel = useMutation({
    mutationFn: () => cancelCampaign(id ?? 0),
    onSuccess: () => {
      toast.success(t('admin.campaigns.toast.cancelled'));
      setConfirmCancel(false);
      void qc.invalidateQueries({ queryKey: qk.campaigns.all });
    },
    onError: (e) => {
      toast.error(adminErrorMessage(i18n, e));
      setConfirmCancel(false);
      void qc.invalidateQueries({ queryKey: qk.campaigns.all });
    },
  });

  const contents: [Lang, { title: string; body: string } | null][] = c
    ? LANGS.map((l) => [l, c[l]] as [Lang, { title: string; body: string } | null])
    : [];

  return (
    <>
      <Drawer
        open={id !== null}
        onClose={onClose}
        size="lg"
        title={c ? t('admin.campaigns.detail.title', { id: c.id }) : t('common.loading')}
        footer={
          c?.status === 'SCHEDULED' ? (
            <Button variant="danger" onClick={() => setConfirmCancel(true)}>
              {t('admin.campaigns.cancel')}
            </Button>
          ) : undefined
        }
      >
        {!c ? (
          <Skeleton width="100%" height="8em" />
        ) : (
          <div className={styles.drawerBody}>
            <div className={listStyles.titleRow}>
              <StatusPill tone={toneFor(c.status)}>{t(`admin.campaigns.status.${c.status}`)}</StatusPill>
              <Badge tone={c.type === 'SYSTEM' ? 'danger' : 'neutral'}>{t(`admin.campaigns.type.${c.type}`)}</Badge>
            </div>
            {c.error && (
              <Callout tone="danger" role="alert" title={t('admin.campaigns.detail.error')}>
                <span className="ltr">{c.error}</span>
              </Callout>
            )}
            <DetailList
              items={[
                { label: t('admin.campaigns.col.audience'), value: audienceSummary(c.audience) },
                {
                  label: t('admin.campaigns.col.recipients'),
                  value: c.recipientCount === null ? '—' : formatNumber(c.recipientCount),
                },
                { label: t('admin.campaigns.detail.target'), value: <span className="ltr">{targetSummary(c.target)}</span> },
                { label: t('admin.campaigns.detail.scheduledAt'), value: formatDateTime(c.scheduledAt) },
                { label: t('admin.campaigns.detail.startedAt'), value: formatDateTime(c.startedAt) },
                { label: t('admin.campaigns.detail.finishedAt'), value: formatDateTime(c.finishedAt) },
                { label: t('admin.campaigns.col.createdBy'), value: names[c.createdBy] ?? `#${c.createdBy}` },
                { label: t('admin.campaigns.detail.createdAt'), value: formatDateTime(c.createdAt) },
              ]}
            />
            <h3 className={styles.h3}>{t('admin.campaigns.detail.content')}</h3>
            <div className={styles.contentGrid}>
              {contents.map(([l, v]) => (
                <section key={l} className={styles.contentBox} lang={v ? l : undefined} dir={v ? (l === 'ar' ? 'rtl' : 'ltr') : undefined}>
                  <p className={styles.contentLang}>{t(`admin.campaigns.lang.${l}`)}</p>
                  {v ? (
                    <>
                      <p className={styles.contentTitle}>{v.title}</p>
                      <p className={styles.contentBody}>{v.body}</p>
                    </>
                  ) : (
                    <p className={styles.contentEmpty}>{t('admin.campaigns.detail.fallsBackToTr')}</p>
                  )}
                </section>
              ))}
            </div>
          </div>
        )}
      </Drawer>
      <ConfirmDialog
        open={confirmCancel}
        onClose={() => setConfirmCancel(false)}
        onConfirm={() => cancel.mutate()}
        loading={cancel.isPending}
        danger
        title={t('admin.campaigns.cancel.title')}
        message={t('admin.campaigns.cancel.message')}
        confirmLabel={t('admin.campaigns.cancel')}
        cancelLabel={t('admin.campaigns.cancel.keep')}
      />
    </>
  );
}
