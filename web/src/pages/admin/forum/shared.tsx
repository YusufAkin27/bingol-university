// FORUM yönetimi ortak parçalar: izin kapısı, yazar etiketi, durum rozetleri ve gerekçeli moderasyon diyaloğu.
// Moderasyon eylemleri (sabitle/kilitle/kaldır/geri al/yoksay) HEP gerekçe ister: GuardedDialog sebebi `X-Admin-Reason` ile yollar.
import { useState, type ReactNode } from 'react';
import {
  forumKeys,
  moderateComment,
  moderateTopic,
  resolveReport,
  type ForumCommentAction,
  type ForumTargetType,
  type ForumTopicAction,
} from '../../../api/adminForum';
import { usePermissions } from '../../../auth/permissions';
import { GuardedDialog } from '../../../components/admin/GuardedDialog';
import { ADMIN_REASON_MIN } from '../../../components/admin/guard/match';
import { Badge } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { forumError, tf } from './tf';

/** İzin YÜKLENİRKEN false (eylem düğmeleri titremez); alınamadıysa sunucu denetler (true). */
export function useForumCan(perm: string): boolean {
  const { status, can } = usePermissions(true);
  return status !== 'loading' && can(perm);
}

/** Anonim yazar adı hiç gösterilmez: "Anonim". */
export function authorLabel(name: string | null, anonymous: boolean, anon: string): string {
  return anonymous || !name ? (anonymous ? anon : '—') : name;
}

export function excerpt(text: string | null | undefined, max = 280): string {
  const s = (text ?? '').replace(/\s+/g, ' ').trim();
  return s.length > max ? `${s.slice(0, max)}…` : s;
}

export function ContentBadges({
  removed,
  gone,
  pinned,
  locked,
  anonymous,
}: {
  removed?: boolean;
  /** Sahibi sildi ya da kayıt yok (DELETED / MISSING): içerik eylemi yoktur. */
  gone?: 'DELETED' | 'MISSING' | null;
  pinned?: boolean;
  locked?: boolean;
  anonymous?: boolean;
}): ReactNode {
  const { td } = useI18n();
  return (
    <>
      {removed && <Badge tone="danger">{td('admin.forum.badge.removed', 'Kaldırıldı')}</Badge>}
      {gone && <Badge tone="neutral">{td(`admin.forum.badge.${gone}`, gone)}</Badge>}
      {pinned && <Badge tone="info">{td('admin.forum.badge.pinned', 'Sabit')}</Badge>}
      {locked && <Badge tone="warning">{td('admin.forum.badge.locked', 'Kilitli')}</Badge>}
      {anonymous && <Badge tone="neutral">{td('admin.forum.badge.anonymous', 'Anonim')}</Badge>}
    </>
  );
}

/** Eylem anahtarı -> düz Türkçe ad ("PIN" -> "Sabitle"). */
export const ACTION_KEYS: Record<string, string> = {
  PIN: 'admin.forum.action.PIN',
  UNPIN: 'admin.forum.action.UNPIN',
  LOCK: 'admin.forum.action.LOCK',
  UNLOCK: 'admin.forum.action.UNLOCK',
  REMOVE: 'admin.forum.action.REMOVE',
  RESTORE: 'admin.forum.action.RESTORE',
  DISMISS: 'admin.forum.action.DISMISS',
};

export type ModAction = ForumTopicAction | ForumCommentAction | 'DISMISS';

export interface ModTarget {
  /** Şikâyet kimliği (yalnız DISMISS için). */
  reportId?: number;
  type: ForumTargetType;
  id: number;
  title?: string | null;
}

/**
 * Gerekçeli moderasyon diyaloğu: `ask(hedef, eylem)` ile açılır, `dialogs` sayfaya basılır.
 * Başarıda tüm forum sorguları (kuyruk, konular, kayıtlar) tazelenir.
 */
export function useForumModeration() {
  const i18n = useI18n();
  const f = tf(i18n);
  const [pending, setPending] = useState<{ target: ModTarget; action: ModAction } | null>(null);
  const action = pending?.action;
  const target = pending?.target;
  const label = action ? f(ACTION_KEYS[action]) : '';
  const destructive = action === 'REMOVE';
  const subject = target?.title ? `“${excerpt(target.title, 80)}”` : `#${target?.id ?? ''}`;

  const dialogs = (
    <GuardedDialog
      open={pending !== null}
      onClose={() => setPending(null)}
      title={label}
      message={action ? f(`admin.forum.confirm.${action}`, { subject }) : undefined}
      irreversible={false}
      danger={destructive}
      confirmLabel={label}
      requireReason
      reasonMinLength={ADMIN_REASON_MIN}
      reasonLabel={f('admin.forum.reason')}
      successMessage={f('admin.forum.done')}
      errorMessage={(e) => forumError(i18n, e)}
      invalidateKeys={[forumKeys.all]}
      onConfirm={({ reason, idempotencyKey }) => {
        if (!pending) return Promise.resolve();
        const { target: tg, action: act } = pending;
        if (act === 'DISMISS') return resolveReport(tg.reportId ?? tg.id, reason, { idempotencyKey });
        if (tg.type === 'FORUM_COMMENT') return moderateComment(tg.id, act as ForumCommentAction, reason, { idempotencyKey });
        return moderateTopic(tg.id, act as ForumTopicAction, reason, { idempotencyKey });
      }}
    />
  );

  return { dialogs, ask: (tg: ModTarget, act: ModAction) => setPending({ target: tg, action: act }) };
}
