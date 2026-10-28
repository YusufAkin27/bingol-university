import { Ico } from './Ico';
import { AppNav } from './Parts';
import { useScreenKit } from './text';
import styles from './screens.module.css';

/** Ana Sayfa: selamlama, arama, sıradaki etkinlik kartı, hızlı erişim, yemek ve kulüpler. */
export function HomeScreen() {
  const { s, num, date, time } = useScreenKit();
  return (
    <>
      <div className={styles.homeTop}>
        <div className={styles.avatarMark}>BÜ</div>
        <div className={styles.grow}>
          <div className={styles.mut13}>{s.hello}</div>
          <div className={styles.who}>{s.who}</div>
        </div>
        <div className={`${styles.ib} ${styles.ibRel}`}>
          <Ico name="bell" />
          <span className={styles.dot} />
        </div>
      </div>

      <div className={styles.searchBar}>
        <Ico name="search" />
        <span>{s.searchAll}</span>
      </div>

      <div className={styles.heroCard}>
        <span className={`${styles.blob} ${styles.blobA}`} />
        <span className={`${styles.blob} ${styles.blobB}`} />
        <div className={styles.heroPill}>
          <Ico name="calendar" />
          {s.nextEvent}
        </div>
        <div className={styles.heroTitle}>{s.career}</div>
        <div className={styles.heroMeta}>
          <span>
            {date(28, { day: 'numeric', month: 'long' })} · {time(14)}
          </span>
          <span>{s.hall}</span>
        </div>
        <div className={styles.heroFoot}>
          <span className={styles.grow}>{s.goingCount(num(86))}</span>
          <span className={styles.heroBtn}>{s.joinBtn}</span>
        </div>
      </div>

      <div className={styles.quick}>
        {(
          [
            ['chat', s.quick.chat, true],
            ['users', s.quick.clubs, false],
            ['calendar', s.quick.events, false],
            ['utensils', s.quick.menu, false],
            ['lifebuoy', s.quick.support, false],
          ] as const
        ).map(([icon, label, badge]) => (
          <div key={icon}>
            <div className={styles.tile}>
              <Ico name={icon} />
              {badge && <span className={styles.tileBadge}>{num(3)}</span>}
            </div>
            <div className={styles.tileLabel}>{label}</div>
          </div>
        ))}
      </div>

      <div className={styles.homeGrid}>
        <div className={styles.mealCard}>
          <div className={styles.mealHead}>
            <Ico name="utensils" />
            {s.mealToday}
          </div>
          <div className={styles.mealLines}>{s.mealShort}</div>
        </div>
        <div className={styles.statCol}>
          <div className={`${styles.stat} ${styles.statDark}`}>
            <div className={styles.grow}>
              <div className={styles.statNum}>{num(3)}</div>
              <div className={styles.statLabel}>{s.newMessages}</div>
            </div>
            <Ico name="arrow" />
          </div>
          <div className={styles.stat}>
            <div className={styles.grow}>
              <div className={styles.statNum}>{num(4)}</div>
              <div className={`${styles.statLabel} ${styles.mut}`}>{s.clubMemberships}</div>
            </div>
            <Ico name="arrow" className={styles.prText} />
          </div>
        </div>
      </div>

      <div className={styles.sectionHead}>
        <div className={styles.grow}>{s.myClubs}</div>
        <div className={styles.prLink}>{s.all}</div>
      </div>
      <div className={styles.rail}>
        {(
          [
            ['FK', s.photoClub, 128, 2, false],
            ['YK', s.softwareClub, 212, 1, true],
          ] as const
        ).map(([ini, name, members, posts, dark]) => (
          <div key={ini} className={styles.clubCard}>
            <div className={`${styles.clubMark} ${dark ? styles.clubMarkDark : ''}`}>{ini}</div>
            <div className={styles.clubName}>{name}</div>
            <div className={styles.clubMeta}>
              {s.members(num(members))} · {s.newPosts(num(posts))}
            </div>
          </div>
        ))}
      </div>

      <AppNav active="home" />
    </>
  );
}
