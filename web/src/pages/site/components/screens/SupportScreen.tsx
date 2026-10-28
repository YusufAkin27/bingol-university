import { Ico } from './Ico';
import { AppNav, ScreenHeader } from './Parts';
import { useScreenKit } from './text';
import styles from './screens.module.css';

/** Destek: talep listesi (durum etiketleriyle) ve yeni talep düğmesi. */
export function SupportScreen() {
  const { s, date } = useScreenKit();
  const tickets = [
    { title: s.ticket1, status: s.open, tone: 'open', day: 27 },
    { title: s.ticket2, status: s.waiting, tone: 'wait', day: 25 },
    { title: s.ticket3, status: s.done, tone: 'done', day: 22 },
  ];
  return (
    <>
      <ScreenHeader title={s.supportTitle} />
      <div className={styles.ticketList}>
        {tickets.map((t) => (
          <div key={t.title} className={`${styles.card} ${styles.ticket}`}>
            <div className={styles.grow}>
              <div className={styles.ticketTitle}>{t.title}</div>
              <div className={styles.date12}>{date(t.day, { day: 'numeric', month: 'long' })}</div>
            </div>
            <span
              className={`${styles.pill} ${t.tone === 'open' ? styles.pillOpen : ''} ${t.tone === 'wait' ? styles.pillWait : ''} ${t.tone === 'done' ? styles.pillDone : ''}`}
            >
              {t.status}
            </span>
          </div>
        ))}
      </div>
      <div className={styles.fab}>
        <Ico name="plus" />
        {s.newTicket}
      </div>
      <AppNav active="profile" />
    </>
  );
}
