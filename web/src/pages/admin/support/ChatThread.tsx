import { useEffect, useMemo, useRef, useState } from 'react';
import type { AttachmentView, TicketMessage } from '../../../api/types';
import { useI18n } from '../../../i18n/I18nProvider';
import { flattenAttachments } from './attachmentLogic';
import { AttachmentGrid, AttachmentLightbox } from './AttachmentViews';
import styles from './ChatThread.module.css';

const dayKey = (iso: string) => {
  const d = new Date(iso);
  return Number.isNaN(d.getTime()) ? iso : `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`;
};

/**
 * Sohbet akışı: kullanıcı (başta) ve personel (sonda) balonları, gün ayracı, ekler.
 * Akış kendi içinde kaydırılır (uzun yazışma sayfayı uzatmaz) ve yeni mesaj gelince en alta iner.
 */
export function ChatThread({ messages }: { messages: (TicketMessage & { attachments?: AttachmentView[] })[] }) {
  const { t, formatDateTime, formatDate } = useI18n();
  const scroller = useRef<HTMLDivElement>(null);
  const [lb, setLb] = useState<number | null>(null);
  const count = messages.length;
  // Büyük görüntüleyicide yalnız görseller gezilir (video satır içi oynar).
  const images = useMemo(() => flattenAttachments(messages).filter((a) => a.kind === 'IMAGE'), [messages]);

  useEffect(() => {
    const el = scroller.current;
    if (el) el.scrollTop = el.scrollHeight;
  }, [count]);

  return (
    <div ref={scroller} className={styles.scroller} data-testid="chat-scroller">
      <ol className={styles.thread} aria-label={t('admin.tickets.chat.label')}>
        {messages.map((m, i) => {
          const newDay = i === 0 || dayKey(messages[i - 1].createdAt) !== dayKey(m.createdAt);
          return (
            <li key={m.id} className={styles.item}>
              {newDay && (
                <div className={styles.day} role="separator">
                  <span>{formatDate(m.createdAt, { day: 'numeric', month: 'long', year: 'numeric' })}</span>
                </div>
              )}
              <div className={`${styles.row} ${m.fromStaff ? styles.staff : styles.user}`}>
                <div className={styles.bubble}>
                  <span className={styles.who}>{m.fromStaff ? t('admin.tickets.chat.staff') : t('admin.tickets.chat.user')}</span>
                  {m.text && (
                    <p className={styles.text} dir="auto">
                      {m.text}
                    </p>
                  )}
                  <AttachmentGrid
                    attachments={m.attachments ?? []}
                    onOpenImage={(id) => setLb(Math.max(0, images.findIndex((a) => a.id === id)))}
                  />
                  <time className={styles.time} dateTime={m.createdAt}>
                    {formatDateTime(m.createdAt)}
                  </time>
                </div>
              </div>
            </li>
          );
        })}
      </ol>
      {lb !== null && <AttachmentLightbox items={images} index={lb} onIndex={setLb} onClose={() => setLb(null)} />}
    </div>
  );
}
