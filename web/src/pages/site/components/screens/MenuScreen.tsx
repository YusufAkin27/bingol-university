import { Ico } from './Ico';
import { AppNav, DayStrip, ScreenHeader } from './Parts';
import { useScreenKit } from './text';
import styles from './screens.module.css';

/** Yemek listesi: ay gezgini, gün şeridi, bugünün menüsü ve sonraki günler. */
export function MenuScreen() {
  const { s, date, upper } = useScreenKit();
  const todayDate = date(26, { day: 'numeric', month: 'long' });
  const list = (items: string[]) =>
    items.map((x) => (
      <div key={x} className={styles.li}>
        {x}
      </div>
    ));
  return (
    <>
      <ScreenHeader title={s.menuTitle} />
      <div className={styles.menuMonth}>
        <div className={`${styles.ib} ${styles.ibSmall}`}>
          <Ico name="chev" className={styles.mirror} />
        </div>
        <div className={`${styles.grow} ${styles.monthName}`}>{date(26, { month: 'long', year: 'numeric' })}</div>
        <div className={`${styles.ib} ${styles.ibSmall}`}>
          <Ico name="chev" />
        </div>
      </div>
      <DayStrip days={[24, 25, 26, 27, 28]} on={26} />

      <div className={styles.todayCard}>
        <span className={`${styles.blob} ${styles.blobC}`} />
        <div className={styles.todayHead}>
          <Ico name="utensils" />
          {s.today} · {upper(todayDate)}
        </div>
        <div className={styles.todayLines}>
          {[s.soup1, s.main1, s.rice1, s.side1].map((x) => (
            <div key={x}>{x}</div>
          ))}
        </div>
      </div>

      <div className={styles.menuDays}>
        <div className={`${styles.card} ${styles.menuCard}`}>
          <div className={styles.menuDate}>{date(27, { day: 'numeric', month: 'long', weekday: 'long' })}</div>
          {list([s.soup2, s.main2, s.side2])}
        </div>
        <div className={`${styles.card} ${styles.menuCard}`}>
          <div className={styles.menuDate}>{date(28, { day: 'numeric', month: 'long', weekday: 'long' })}</div>
          {list([s.soup3, s.main3, s.rice3])}
        </div>
      </div>
      <AppNav active={null} />
    </>
  );
}
