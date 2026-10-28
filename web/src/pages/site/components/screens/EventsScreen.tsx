import { Ico } from './Ico';
import { AppNav, DayStrip, ScreenHeader } from './Parts';
import { useScreenKit } from './text';
import styles from './screens.module.css';

/** Etkinlikler: gün şeridi, katılım durumu, QR yoklama kodu düğmesi ve RSVP eylemleri. */
export function EventsScreen() {
  const { s, num, date, time } = useScreenKit();
  const block = (day: number) => (
    <div className={styles.dt}>
      {date(day, { month: 'short' })}
      <b>{num(day)}</b>
    </div>
  );
  return (
    <>
      <ScreenHeader
        title={s.eventsTitle}
        action={
          <div className={`${styles.ib} ${styles.ibWide}`}>
            <Ico name="qr" className={styles.small} />
            {s.attendance}
          </div>
        }
      />
      <div className={styles.monthLabel}>{date(28, { month: 'long', year: 'numeric' })}</div>
      <DayStrip days={[26, 27, 28, 29, 30]} on={28} tall />

      <div className={styles.eventList}>
        <div className={`${styles.card} ${styles.eventCard}`}>
          {block(28)}
          <div className={styles.grow}>
            <span className={styles.tag}>
              <Ico name="check" className={styles.tiny} />
              {s.going}
            </span>
            <div className={styles.eventTitle}>{s.career}</div>
            <div className={styles.meta}>
              <Ico name="clock" />
              {time(14)} – {time(17)}
            </div>
            <div className={styles.meta}>
              <Ico name="pin" />
              {s.hall}
            </div>
            <div className={styles.eventActions}>
              <div className={styles.btn}>
                <Ico name="qr" />
                {s.attendCode}
              </div>
              <span className={styles.mut12}>{s.goingShort(num(86))}</span>
            </div>
          </div>
        </div>
        <div className={`${styles.card} ${styles.eventCard}`}>
          {block(28)}
          <div className={styles.grow}>
            <div className={styles.eventTitle}>{s.photoWalk}</div>
            <div className={styles.mut12}>{s.photoClub}</div>
            <div className={styles.meta}>
              <Ico name="clock" />
              {time(18, 30)}
            </div>
            <div className={styles.meta}>
              <Ico name="pin" />
              {s.campusGate}
            </div>
            <div className={styles.eventActions}>
              <div className={styles.btn}>{s.joinBtn}</div>
              <div className={`${styles.btn} ${styles.btnOutline}`}>{s.interested}</div>
            </div>
          </div>
        </div>
        <div className={`${styles.card} ${styles.eventCard}`}>
          {block(30)}
          <div className={styles.grow}>
            <div className={styles.eventTitle}>{s.chessTournament}</div>
            <div className={styles.meta}>
              <Ico name="clock" />
              {time(10)}
            </div>
            <div className={styles.meta}>
              <Ico name="pin" />
              {s.studentCenter}
            </div>
          </div>
        </div>
      </div>
      <AppNav active={null} />
    </>
  );
}
