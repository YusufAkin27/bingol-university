// Sohbet yönetimi araç çubuğu (P08): sohbeti kapat/aç, üyeyi gruptan çıkar, yasal dışa aktarma.
// Üst veri `GET /api/admin/conversations/{id}` (İÇERİK YOK; e-posta maskeli) ile gelir; içerik yalnız sebepli görüntüleme uçlarındadır.
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { adminChatApi, qk } from '../../../api';
import { Badge, GuardedAction, Select } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminError } from '../../../lib/errors';
import { ConversationExportButton } from './ConversationExport';
import styles from './chatAction.module.css';

const INVALIDATE = [['adminChat']];

/** viewReason: açık sohbet görüntüleme sebebi; üst veri okuması da aynı sebeple denetim kaydına bağlanır (işlem sebebinden ayrı). */
export function ConversationTools({ conversationId, viewReason }: { conversationId: number; viewReason?: string }) {
  const i18n = useI18n();
  const { t, formatNumber } = i18n;
  const [memberId, setMemberId] = useState('');
  const meta = useQuery({
    queryKey: qk.adminChat.meta(conversationId),
    queryFn: () => adminChatApi.getConversationMeta(conversationId, viewReason),
    staleTime: 15_000,
  });
  const err = (e: unknown) => adminError(i18n, e);

  if (meta.isLoading) return <p className={styles.toolsHint}>{t('admin.p08.conv.loading')}</p>;
  if (meta.isError || !meta.data) {
    return (
      <p className={styles.toolsHint} role="alert">
        {t('admin.p08.conv.loadFailed')}: {adminError(i18n, meta.error)}
      </p>
    );
  }
  const c = meta.data;
  const active = (c.members ?? []).filter((m) => m.active);
  const picked = active.find((m) => String(m.userId) === memberId) ?? null;
  const pickedName = picked ? (picked.displayName ?? `#${picked.userId}`) : '';
  const canRemove = c.type === 'GROUP' && !c.membersManaged;

  return (
    <section className={styles.tools} aria-label={t('admin.p08.conv.tools')} data-testid="conv-tools">
      <div className={styles.toolsRow}>
        <Badge tone="primary">{t(`admin.p08.conv.kind.${c.kind}`)}</Badge>
        <span className={styles.toolsHint}>
          {t('admin.p08.conv.stats', { messages: formatNumber(c.messageCount), members: formatNumber(c.activeMemberCount) })}
        </span>
        {c.closed && (
          <Badge tone="danger">
            <span data-testid="closed-badge">{t('admin.p08.conv.closedBadge')}</span>
          </Badge>
        )}
        {c.openReportCount > 0 && <Badge tone="warning">{t('admin.p08.conv.reports', { n: c.openReportCount })}</Badge>}
      </div>
      {c.closed && c.closedReason && (
        <p className={styles.toolsHint} dir="auto">
          {t('admin.p08.conv.closedInfo', { reason: c.closedReason })}
        </p>
      )}
      <div className={styles.toolsRow}>
        {c.closed ? (
          <GuardedAction
            variant="secondary"
            size="sm"
            title={t('admin.p08.reopen.title')}
            message={t('admin.p08.reopen.message')}
            irreversible={false}
            requireReason
            successMessage={t('admin.p08.reopen.done')}
            errorMessage={err}
            invalidateKeys={INVALIDATE}
            onConfirm={({ reason, idempotencyKey }) => adminChatApi.reopenConversation(c.id, reason, idempotencyKey)}
          >
            {t('admin.p08.reopen.btn')}
          </GuardedAction>
        ) : (
          <GuardedAction
            danger
            size="sm"
            title={t('admin.p08.close.title')}
            message={t('admin.p08.close.message')}
            consequence={t('admin.p08.close.consequence')}
            irreversible={false}
            requireReason
            successMessage={t('admin.p08.close.done')}
            errorMessage={err}
            invalidateKeys={INVALIDATE}
            onConfirm={({ reason, idempotencyKey }) => adminChatApi.closeConversation(c.id, reason, idempotencyKey)}
          >
            {t('admin.p08.close.btn')}
          </GuardedAction>
        )}
        <ConversationExportButton conversationId={c.id} />
      </div>
      {canRemove ? (
        <div className={styles.memberRow}>
          <Select
            className={styles.memberSelect}
            aria-label={t('admin.p08.member.label')}
            value={memberId}
            onChange={(e) => setMemberId(e.target.value)}
          >
            <option value="">{t('admin.p08.member.pick')}</option>
            {active.map((m) => (
              <option key={m.userId} value={m.userId}>
                {m.displayName ?? `#${m.userId}`} {m.email ? `(${m.email})` : ''}
              </option>
            ))}
          </Select>
          <GuardedAction
            danger
            size="sm"
            disabled={!picked}
            title={t('admin.p08.member.title')}
            message={t('admin.p08.member.message', { name: pickedName })}
            consequence={t('admin.p08.member.consequence')}
            irreversible={false}
            requireReason
            successMessage={t('admin.p08.member.done')}
            errorMessage={err}
            invalidateKeys={INVALIDATE}
            onSuccess={() => setMemberId('')}
            onConfirm={({ reason, idempotencyKey }) =>
              adminChatApi.removeConversationMember(c.id, picked?.userId ?? 0, reason, idempotencyKey)
            }
          >
            {t('admin.p08.member.btn')}
          </GuardedAction>
          {c.membersTruncated && <span className={styles.toolsHint}>{t('admin.p08.member.truncated')}</span>}
        </div>
      ) : (
        <p className={styles.toolsHint}>{c.type === 'DIRECT' ? t('admin.p08.member.direct') : t('admin.p08.member.managed')}</p>
      )}
    </section>
  );
}
