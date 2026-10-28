import { Ico } from './Ico';
import { AppNav, Chips, IconButton, ScreenHeader } from './Parts';
import { useScreenKit } from './text';
import styles from './screens.module.css';

/** Keşfet: haber/duyuru akışı, öne çıkan haber kartı ve kaydedilen içerik işareti. */
export function DiscoverScreen() {
  const { s, date } = useScreenKit();
  const d = (day: number) => date(day, { day: 'numeric', month: 'long', year: 'numeric' });
  return (
    <>
      <ScreenHeader title={s.nav.discover} action={<IconButton name="search" />} />
      <Chips items={[s.chips.news, s.chips.announcements, s.chips.events, s.chips.saved]} />

      <div className={`${styles.card} ${styles.featured}`}>
        <div className={styles.featuredArt}>
          <span className={`${styles.blob} ${styles.blobC}`} />
          <span className={`${styles.badge} ${styles.badgeLight}`}>{s.news}</span>
        </div>
        <div className={styles.featuredBody}>
          <div className={styles.grow}>
            <div className={styles.featuredTitle}>{s.headline}</div>
            <div className={styles.date12}>{d(26)}</div>
          </div>
          <Ico name="bookmark" className={styles.mut} />
        </div>
      </div>

      <div className={styles.newsList}>
        {(
          [
            [s.announcement, s.announce1, 25, true, true],
            [s.news, s.news2, 24, false, false],
          ] as const
        ).map(([tag, title, day, soft, saved]) => (
          <div key={title} className={`${styles.card} ${styles.newsRow}`}>
            <div className={styles.thumb} />
            <div className={styles.grow}>
              <span className={`${styles.badge} ${soft ? styles.badgeSoft : ''}`}>{tag}</span>
              <div className={styles.newsTitle}>{title}</div>
              <div className={styles.date12}>{d(day)}</div>
            </div>
            <Ico name="bookmark" className={saved ? styles.saved : styles.mut} />
          </div>
        ))}
      </div>

      <AppNav active="discover" />
    </>
  );
}
