// Tek sohbet balonu. Yön: açılan kullanıcının mesajı bir yanda, karşı taraflar diğer yanda (Arapçada ayna, mantıksal CSS).
// Hiçbir mesaj gizlenmez: silinmiş mesaj çözülmüş metinle (soluk + "Silindi" rozeti), gölge engelli mesaj "iletilmedi" rozetiyle,
// düzenleme geçmişi <details> içinde, tek gönderimlik ekler "Açan" bilgisiyle gösterilir.
import type { ReactNode } from 'react';
import type { AdminChatMessage } from '../../../api/types';
import { Avatar, Badge } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { attachmentToItem, bubbleSide, personName, receiptTicks } from './chatLogic';
import { MediaThumb } from './MediaThumb';
import styles from './chat.module.css';

interface Props {
  m: AdminChatMessage;
  /** Ek tıklanınca (ek kimliği). */
  onOpenMedia?: (attachmentId: number) => void;
  highlighted?: boolean;
  /** Şikâyet edilen mesaj işareti. */
  reported?: boolean;
  /** P08: mesaj işlem menüsü (yalnız yönetici ekranlarında verilir). */
  actions?: ReactNode;
  /** P08: toplu seçim kutusu (verilmezse çizilmez). */
  select?: { checked: boolean; onChange: (checked: boolean) => void; label: string } | null;
}

export function ChatBubble({ m, onOpenMedia, highlighted, reported, actions, select }: Props) {
  const { t, formatDateTime } = useI18n();
  const side = bubbleSide(m);
  const name = personName(m.sender, m.senderName) ?? t('admin.chat.sender', { id: m.senderId });
  const body =
    m.text !== null ? (
      m.text === '' ? null : (
        <p className={styles.text} dir="auto">
          {m.text}
        </p>
      )
    ) : (
      <p className={styles.muted}>{t('admin.chat.failed', { reason: m.error ?? '?' })}</p>
    );
  const reactions = new Map<string, number>();
  for (const r of m.reactions) reactions.set(r.emoji, (reactions.get(r.emoji) ?? 0) + 1);
  const ticks = side === 'self' ? receiptTicks(m.status) : '';

  return (
    <li
      id={`msg-${m.id}`}
      className={`${styles.row} ${side === 'self' ? styles.rowSelf : styles.rowPeer} ${highlighted ? styles.highlight : ''} ${
        reported ? styles.reportedRow : ''
      }`}
      data-testid="chat-bubble"
      data-side={side}
      data-deleted={m.deleted ? 'true' : 'false'}
      data-highlighted={highlighted ? 'true' : undefined}
    >
      {side === 'peer' && (
        <span className={styles.rowAvatar}>
          <Avatar name={name} src={m.sender?.avatarUrl} size={28} />
        </span>
      )}
      <div
        className={`${styles.bubble} ${side === 'self' ? styles.bubbleSelf : styles.bubblePeer} ${
          m.deleted ? styles.bubbleDeleted : ''
        } ${m.suppressed ? styles.bubbleSuppressed : ''}`}
      >
        <div className={styles.meta}>
          <strong dir="auto">{name}</strong>
          <time dateTime={m.createdAt}>{formatDateTime(m.createdAt)}</time>
          <span className="ltr">#{m.id}</span>
          {select && (
            <input
              type="checkbox"
              checked={select.checked}
              aria-label={select.label}
              data-testid="bubble-select"
              onChange={(e) => select.onChange(e.target.checked)}
            />
          )}
          {ticks && (
            <span
              className={`${styles.ticks} ${m.status === 'READ' ? styles.ticksRead : ''}`}
              title={t(`admin.chat.receipt.${m.status as 'SENT'}`)}
              aria-label={t(`admin.chat.receipt.${m.status as 'SENT'}`)}
              data-testid="receipt"
            >
              {ticks}
            </span>
          )}
        </div>

        {reported && (
          <Badge tone="danger">
            <span data-testid="reported-badge">{t('admin.reports.ctx.reportedMsg')}</span>
          </Badge>
        )}

        {m.replyTo && (
          <blockquote className={styles.reply} dir="auto">
            {m.replyTo.text !== null ? m.replyTo.text : t('admin.chat.replyMissing')}
            {m.replyTo.deleted && ` (${t('admin.chat.badge.deleted')})`}
          </blockquote>
        )}

        <div className={m.deleted ? styles.dimmed : undefined}>{body}</div>

        {m.attachments.length > 0 && (
          <div className={`${styles.attachments} ${m.deleted ? styles.dimmed : ''}`}>
            {m.attachments.map((a) => (
              <MediaThumb key={a.id} item={attachmentToItem(a, m, null)} onOpen={() => onOpenMedia?.(a.id)} />
            ))}
          </div>
        )}

        <div className={styles.badges}>
          {m.deleted && (
            <Badge tone="danger">
              <span data-testid="deleted-badge">{t('admin.chat.badge.deleted')}</span>
            </Badge>
          )}
          {m.suppressed && (
            <Badge tone="warning">
              <span data-testid="suppressed-badge">{t('admin.chat.badge.suppressed')}</span>
            </Badge>
          )}
          {m.hidden && !m.adminHidden && <Badge tone="warning">{t('admin.chat.badge.hidden')}</Badge>}
          {m.adminHidden && !m.purged && (
            <Badge tone="warning">
              <span data-testid="admin-hidden-badge">{t('admin.p08.badge.adminHidden')}</span>
            </Badge>
          )}
          {m.purged && (
            <Badge tone="danger">
              <span data-testid="purged-badge">{t('admin.p08.badge.purged')}</span>
            </Badge>
          )}
          {m.edited && <Badge tone="info">{t('admin.chat.badge.edited')}</Badge>}
          {m.replyTo && <Badge tone="neutral">{t('admin.chat.badge.reply')}</Badge>}
          {[...reactions.entries()].map(([emoji, n]) => (
            <Badge key={emoji} tone="neutral">
              {emoji} {n}
            </Badge>
          ))}
        </div>

        {actions}

        {m.suppressed && m.blockedBy && (
          <p className={styles.muted}>{t('admin.chat.blockedBy', { name: m.blockedBy.displayName ?? `#${m.blockedBy.id}` })}</p>
        )}

        {m.deleted && (
          <p className={styles.muted} data-testid="deleted-info">
            {t('admin.chat.deletedBy', {
              who: m.deletedByName ?? (m.deletedBy ? `#${m.deletedBy}` : '?'),
              when: m.deletedAt ? formatDateTime(m.deletedAt) : '?',
            })}
          </p>
        )}

        {m.revisions.length > 0 && (
          <details className={styles.revisions}>
            <summary>{t('admin.chat.revisions', { n: m.revisions.length })}</summary>
            <ol>
              {m.revisions.map((r, i) => (
                <li key={i}>
                  <span className={styles.muted}>{formatDateTime(r.revisedAt)}</span>
                  <p className={styles.text} dir="auto">
                    {r.text ?? t('admin.chat.failed', { reason: r.error ?? '?' })}
                  </p>
                </li>
              ))}
            </ol>
          </details>
        )}
      </div>
    </li>
  );
}
