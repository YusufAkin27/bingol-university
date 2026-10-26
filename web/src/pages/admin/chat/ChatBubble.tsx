// Tek sohbet balonu. Yön: açılan kullanıcının mesajı bir yanda, karşı taraflar diğer yanda (Arapçada ayna, mantıksal CSS).
// Silinmiş mesaj da çözülmüş metinle "silindi" rozetiyle gösterilir; düzenleme geçmişi <details> içindedir.
import type { AdminChatMessage } from '../../../api/types';
import { Badge } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { AttachmentThumb } from './AttachmentThumb';
import { bubbleSide } from './chatLogic';
import styles from './chat.module.css';

export function ChatBubble({ m }: { m: AdminChatMessage }) {
  const { t, formatDateTime } = useI18n();
  const side = bubbleSide(m);
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

  return (
    <li
      className={`${styles.row} ${side === 'self' ? styles.rowSelf : styles.rowPeer}`}
      data-testid="chat-bubble"
      data-side={side}
      data-deleted={m.deleted ? 'true' : 'false'}
    >
      <div className={`${styles.bubble} ${side === 'self' ? styles.bubbleSelf : styles.bubblePeer} ${m.deleted ? styles.bubbleDeleted : ''}`}>
        <div className={styles.meta}>
          <strong dir="auto">{m.senderName ?? t('admin.chat.sender', { id: m.senderId })}</strong>
          <time dateTime={m.createdAt}>{formatDateTime(m.createdAt)}</time>
          <span className="ltr">#{m.id}</span>
        </div>

        {m.replyTo && (
          <blockquote className={styles.reply} dir="auto">
            {m.replyTo.text !== null
              ? m.replyTo.text
              : t('admin.chat.replyMissing')}
            {m.replyTo.deleted && ` (${t('admin.chat.badge.deleted')})`}
          </blockquote>
        )}

        {body}

        {m.attachments.length > 0 && (
          <div className={styles.attachments}>
            {m.attachments.map((a) => (
              <AttachmentThumb key={a.id} a={a} />
            ))}
          </div>
        )}

        <div className={styles.badges}>
          {m.deleted && (
            <Badge tone="danger">
              <span data-testid="deleted-badge">{t('admin.chat.badge.deleted')}</span>
            </Badge>
          )}
          {m.hidden && <Badge tone="warning">{t('admin.chat.badge.hidden')}</Badge>}
          {m.edited && <Badge tone="info">{t('admin.chat.badge.edited')}</Badge>}
          {m.replyTo && <Badge tone="neutral">{t('admin.chat.badge.reply')}</Badge>}
          {m.attachments.length > 0 && <Badge tone="neutral">{t('admin.chat.badge.attachment')}</Badge>}
          {[...reactions.entries()].map(([emoji, n]) => (
            <Badge key={emoji} tone="neutral">
              {emoji} {n}
            </Badge>
          ))}
        </div>

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
