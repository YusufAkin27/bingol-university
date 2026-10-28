import { AppNav, Chips, IconButton, ScreenHeader } from './Parts';
import { useScreenKit } from './text';
import styles from './screens.module.css';

/** Kulüpler: kategori çipleri ve iki sütunlu kulüp kartları. */
export function ClubsScreen() {
  const { s, num } = useScreenKit();
  const clubs = [
    { ini: 'FK', name: s.photoClub, n: 128, tone: 'soft' },
    { ini: 'YK', name: s.softwareClub, n: 212, tone: 'dark' },
    { ini: 'SK', name: s.chessClub, n: 64, tone: 'red' },
    { ini: 'TT', name: s.theatre, n: 97, tone: 'soft' },
    { ini: 'DK', name: s.mountaineering, n: 143, tone: 'dark' },
    { ini: 'MT', name: s.music, n: 81, tone: 'red' },
  ];
  return (
    <>
      <ScreenHeader title={s.clubsTitle} action={<IconButton name="search" />} />
      <Chips items={[s.cats.all, s.cats.arts, s.cats.tech, s.cats.sport]} />
      <div className={styles.clubGrid}>
        {clubs.map((c) => (
          <div key={c.ini} className={`${styles.card} ${styles.clubTile}`}>
            <div
              className={`${styles.clubMark} ${c.tone === 'dark' ? styles.clubMarkDark : ''} ${c.tone === 'red' ? styles.clubMarkRed : ''}`}
            >
              {c.ini}
            </div>
            <div className={styles.clubName}>{c.name}</div>
            <div className={styles.clubMeta}>{s.members(num(c.n))}</div>
            <div className={`${styles.btn} ${styles.btnOutline} ${styles.btnTile}`}>{s.join}</div>
          </div>
        ))}
      </div>
      <AppNav active="clubs" />
    </>
  );
}
