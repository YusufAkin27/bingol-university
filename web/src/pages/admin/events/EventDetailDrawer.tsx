import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import {
  cancelEvent,
  deleteEvent,
  getAdminEvent,
  hideEvent,
  patchAdminEvent,
  unhideEvent,
  type AdminEventDetail,
  type AdminEventPatch,
} from '../../../api/adminEvents';
import { approveEvent, rejectEvent } from '../../../api/approvals';
import { AuditTrail } from '../../../components/admin/guard';
import { Badge, Button, Drawer, ErrorState, Icon, Skeleton, StatusPill, toneFor, useToast } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { Callout } from '../campaigns/shared';
import { DetailList, RejectDialog } from '../community/ReviewParts';
import { EventEditForm } from './EventEditForm';
import { ReasonDialog } from './ReasonDialog';
import { eventErrorMessage } from './errors';
import { allowed, type ReasonAction } from './lib';
import styles from './events.module.css';

const detailKey = (id: number) => ['events', 'detail', id] as const;

type Dialog = null | ReasonAction | 'reject';

/** Etkinlik ayrıntı çekmecesi: bilgi, istek sayıları, durum geçmişi ve `allowedActions`'a göre işlemler. */
export function EventDetailDrawer({ id, onClose }: { id: number | null; onClose: () => void }) {
  const i18n = useI18n();
  const { t, td, formatDateTime, formatNumber } = i18n;
  const toast = useToast();
  const qc = useQueryClient();
  const [dialog, setDialog] = useState<Dialog>(null);
  const [editing, setEditing] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);
  const [dialogError, setDialogError] = useState<string | null>(null);

  const q = useQuery({
    queryKey: detailKey(id ?? 0),
    queryFn: () => getAdminEvent(id ?? 0),
    enabled: id !== null,
  });
  const d = q.data;
  const ev = d?.event;

  function refreshList() {
    void qc.invalidateQueries({ queryKey: ['events', 'list'] });
  }
  function accept(next: AdminEventDetail, toastKey: Parameters<typeof t>[0]) {
    qc.setQueryData(detailKey(next.event.id), next);
    refreshList();
    toast.success(t(toastKey, { name: next.event.title }));
    setDialog(null);
    setEditing(false);
  }
  const fail = (e: unknown) => {
    const msg = eventErrorMessage(i18n, e);
    setDialogError(msg);
    setFormError(msg);
    toast.error(msg);
    // başka yönetici işlem yapmış olabilir: ayrıntıyı ve listeyi tazele
    void qc.invalidateQueries({ queryKey: detailKey(id ?? 0) });
    refreshList();
  };

  const reasoned = useMutation({
    mutationFn: (v: { action: Exclude<ReasonAction, 'delete'>; reason: string }) =>
      (v.action === 'hide' ? hideEvent : v.action === 'unhide' ? unhideEvent : cancelEvent)(id ?? 0, v.reason),
    onSuccess: (next, v) =>
      accept(next, v.action === 'hide' ? 'admin.events.toast.hide' : v.action === 'unhide' ? 'admin.events.toast.unhide' : 'admin.events.toast.cancel'),
    onError: fail,
  });
  const remove = useMutation({
    mutationFn: (reason: string) => deleteEvent(id ?? 0, reason),
    onSuccess: () => {
      toast.success(t('admin.events.toast.delete', { name: ev?.title ?? '' }));
      refreshList();
      setDialog(null);
      onClose();
    },
    onError: fail,
  });
  const edit = useMutation({
    mutationFn: (patch: AdminEventPatch) => patchAdminEvent(id ?? 0, patch),
    onSuccess: (next) => accept(next, 'admin.events.toast.edit'),
    onError: fail,
  });
  const approve = useMutation({
    mutationFn: () => approveEvent(id ?? 0),
    onSuccess: () => {
      toast.success(t('admin.review.toast.approved', { name: ev?.title ?? '' }));
      void qc.invalidateQueries({ queryKey: detailKey(id ?? 0) });
      refreshList();
    },
    onError: fail,
  });
  const reject = useMutation({
    mutationFn: (reason: string) => rejectEvent(id ?? 0, reason || undefined),
    onSuccess: () => {
      toast.success(t('admin.review.toast.rejected', { name: ev?.title ?? '' }));
      setDialog(null);
      void qc.invalidateQueries({ queryKey: detailKey(id ?? 0) });
      refreshList();
    },
    onError: fail,
  });

  function open(next: Dialog) {
    setDialogError(null);
    setDialog(next);
  }
  function close() {
    setDialog(null);
    setEditing(false);
    setFormError(null);
    setDialogError(null);
    onClose();
  }

  const actions = d?.allowedActions;
  const busy = approve.isPending || reject.isPending || reasoned.isPending || remove.isPending;
  const history = [...(d?.history ?? [])].sort((a, b) => b.createdAt.localeCompare(a.createdAt));

  const footer =
    d && !editing ? (
      <div className={styles.footer}>
        {allowed(actions, 'approve') && (
          <Button loading={approve.isPending} disabled={busy} leftIcon={<Icon name="check" size={16} />} onClick={() => approve.mutate()}>
            {t('admin.review.approve')}
          </Button>
        )}
        {allowed(actions, 'reject') && (
          <Button variant="secondary" disabled={busy} onClick={() => open('reject')}>
            {t('admin.review.reject')}
          </Button>
        )}
        {allowed(actions, 'edit') && (
          <Button
            variant="secondary"
            disabled={busy}
            onClick={() => {
              setFormError(null);
              setEditing(true);
            }}
          >
            {t('admin.events.action.edit')}
          </Button>
        )}
        {allowed(actions, 'hide') && (
          <Button variant="secondary" disabled={busy} onClick={() => open('hide')}>
            {t('admin.events.action.hide')}
          </Button>
        )}
        {allowed(actions, 'unhide') && (
          <Button variant="secondary" disabled={busy} onClick={() => open('unhide')}>
            {t('admin.events.action.unhide')}
          </Button>
        )}
        {allowed(actions, 'cancel') && (
          <Button variant="danger" disabled={busy} onClick={() => open('cancel')}>
            {t('admin.events.action.cancel')}
          </Button>
        )}
        {allowed(actions, 'delete') && (
          <Button variant="danger" disabled={busy} onClick={() => open('delete')}>
            {t('admin.events.action.delete')}
          </Button>
        )}
      </div>
    ) : undefined;

  const organizer = ev ? ev.organizerName || ev.organizer?.displayName || `#${ev.createdBy}` : '';

  return (
    <>
      <Drawer open={id !== null} onClose={close} size="lg" title={ev?.title ?? t('common.loading')} footer={footer}>
        {q.isError ? (
          <ErrorState description={eventErrorMessage(i18n, q.error)} onRetry={() => void q.refetch()} />
        ) : !d || !ev ? (
          <Skeleton width="100%" height="10em" />
        ) : editing ? (
          <EventEditForm
            event={ev}
            saving={edit.isPending}
            error={formError}
            onCancel={() => {
              setEditing(false);
              setFormError(null);
            }}
            onSave={(patch) => {
              setFormError(null);
              edit.mutate(patch);
            }}
          />
        ) : (
          <div className={styles.body}>
            <div className={styles.badges}>
              <StatusPill tone={toneFor(ev.status)}>{t(`admin.events.status.${ev.status}`)}</StatusPill>
              {ev.communityName ? <Badge tone="info">{ev.communityName}</Badge> : <Badge>{t('admin.events.standalone')}</Badge>}
            </div>
            {ev.communityId == null && <Callout tone="info">{t('admin.events.standaloneNote')}</Callout>}
            {ev.status === 'HIDDEN' && <Callout tone="warning">{t('admin.events.hiddenNote')}</Callout>}
            <p className={styles.desc}>{ev.description || t('admin.events.noDescription')}</p>
            <DetailList
              items={[
                { label: t('admin.events.starts'), value: formatDateTime(ev.startsAt) },
                { label: t('admin.events.ends'), value: formatDateTime(ev.endsAt) },
                { label: t('admin.events.location'), value: ev.location || '—' },
                { label: t('admin.events.capacity'), value: ev.capacity == null ? t('admin.events.unlimited') : formatNumber(ev.capacity) },
                { label: t('admin.events.organizer'), value: organizer },
                {
                  label: t('admin.events.organizerEmail'),
                  value: d.organizerEmail ? <span className="ltr">{d.organizerEmail}</span> : '—',
                },
                { label: t('admin.events.community'), value: ev.communityName || t('admin.events.standalone') },
                { label: t('admin.events.joinPolicy'), value: t(`admin.events.join.${ev.joinPolicy ?? 'OPEN'}`) },
                { label: t('admin.events.going'), value: formatNumber(ev.goingCount) },
                { label: t('admin.events.attended'), value: formatNumber(d.attendedCount) },
                { label: t('admin.events.created'), value: formatDateTime(ev.createdAt) },
                ...(d.reviewNote ? [{ label: t('admin.events.reviewNote'), value: d.reviewNote }] : []),
                ...(d.moderationReason
                  ? [
                      { label: t('admin.events.moderationReason'), value: d.moderationReason },
                      { label: t('admin.events.moderatedAt'), value: formatDateTime(d.moderatedAt) },
                    ]
                  : []),
              ]}
            />

            <h3 className={styles.h3}>{t('admin.events.requests.title')}</h3>
            <dl className={styles.counts} data-testid="request-counts">
              {(['pending', 'waitlisted', 'accepted', 'rejected', 'cancelled'] as const).map((k) => (
                <div key={k} className={styles.count}>
                  <dt>{t(`admin.events.requests.${k}`)}</dt>
                  <dd>{formatNumber(d.requests[k])}</dd>
                </div>
              ))}
            </dl>

            <h3 className={styles.h3}>{t('admin.events.history.title')}</h3>
            {history.length === 0 ? (
              <p className={styles.muted}>{t('admin.events.history.empty')}</p>
            ) : (
              <ol className={styles.timeline} data-testid="history">
                {history.map((h) => (
                  <li key={h.id} className={styles.step}>
                    <div className={styles.stepHead}>
                      <strong>{td(`admin.events.history.action.${h.action}`, h.action)}</strong>
                      <span className={styles.muted}>{formatDateTime(h.createdAt)}</span>
                    </div>
                    <div className={styles.muted}>
                      {h.adminName || t('admin.events.history.auto')}
                      {h.fromStatus && h.toStatus && h.fromStatus !== h.toStatus
                        ? ` · ${t(`admin.events.status.${h.fromStatus}`)} → ${t(`admin.events.status.${h.toStatus}`)}`
                        : ''}
                    </div>
                    {h.reason && <p className={styles.reason}>{h.reason}</p>}
                  </li>
                ))}
              </ol>
            )}
          </div>
        )}
        {ev && !editing && <AuditTrail targetType="EVENT" targetId={ev.id} />}
      </Drawer>

      {ev && (dialog === 'hide' || dialog === 'unhide' || dialog === 'cancel') && (
        <ReasonDialog
          action={dialog}
          name={ev.title}
          loading={reasoned.isPending}
          error={dialogError}
          onClose={() => setDialog(null)}
          onConfirm={(reason) => reasoned.mutate({ action: dialog, reason })}
        />
      )}
      {ev && dialog === 'delete' && (
        <ReasonDialog
          action="delete"
          name={ev.title}
          loading={remove.isPending}
          error={dialogError}
          onClose={() => setDialog(null)}
          onConfirm={(reason) => remove.mutate(reason)}
        />
      )}
      {ev && dialog === 'reject' && (
        <RejectDialog open name={ev.title} loading={reject.isPending} onClose={() => setDialog(null)} onConfirm={(r) => reject.mutate(r)} />
      )}
    </>
  );
}
