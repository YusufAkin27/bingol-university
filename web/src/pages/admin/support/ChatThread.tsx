import { useEffect, useRef } from 'react';
import type { TicketMessage } from '../../../api/types';
import { useI18n } from '../../../i18n/I18nProvider';
import styles from './ChatThread.module.css';

/** Kullanıcı (başta) ve personel (sonda) balonları; yeni mesaj gelince en alta kayar. */
export function ChatThread({ messages }: { messages: TicketMessage[] }) {
  const { t, formatDateTime } = useI18n();
  const endRef = useRef<HTMLLIElement>(null);
  const count = messages.length;

  useEffect(() => {
    endRef.current?.scrollIntoView?.({ block: 'nearest' });
  }, [count]);

  return (
    <ol className={styles.thread} aria-label={t('admin.tickets.chat.label')}>
      {messages.map((m) => (
        <li key={m.id} className={`${styles.row} ${m.fromStaff ? styles.staff : styles.user}`}>
          <div className={styles.bubble}>
            <span className={styles.who}>
              {m.fromStaff ? t('admin.tickets.chat.staff') : t('admin.tickets.chat.user')}
            </span>
            <p className={styles.text} dir="auto">
              {m.text}
            </p>
            <time className={styles.time} dateTime={m.createdAt}>
              {formatDateTime(m.createdAt)}
            </time>
          </div>
        </li>
      ))}
      <li ref={endRef} aria-hidden="true" />
    </ol>
  );
}
