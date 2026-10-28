import { Ico } from './Ico';
import { AppNav, Chips, IconButton, ScreenHeader } from './Parts';
import { useScreenKit } from './text';
import styles from './screens.module.css';

/** Sohbet: kulüp/etkinlik odaları ve grup, okunmamış sayaçları, oda etiketleri. */
export function ChatScreen() {
  const { s, num, time, date } = useScreenKit();
  const rows = [
    { ini: 'YK', name: s.softwareClub, tag: s.clubTag, msg: s.msg1, when: time(9, 41), unread: 2, tone: 'dark' },
    { ini: 'KG', name: s.career, tag: s.eventTag, msg: s.msg2, when: time(8, 15), unread: 1, tone: 'red' },
    { ini: 'FK', name: s.photoClub, tag: s.clubTag, msg: s.msg3, when: s.yesterday, unread: 0, tone: 'dark' },
    { ini: 'ST', name: s.chessTournament, tag: s.eventTag, msg: s.msg4, when: s.yesterday, unread: 0, tone: 'red' },
    { ini: 'KÇ', name: s.libraryGroup, tag: '', msg: s.msg5, when: date(26, { weekday: 'short' }), unread: 0, tone: 'soft' },
  ];
  return (
    <>
      <ScreenHeader title={s.chatTitle} action={<IconButton name="plus" />} />
      <div className={`${styles.searchBar} ${styles.searchBarTight}`}>
        <Ico name="search" />
        <span>{s.chatSearch}</span>
      </div>
      <Chips items={[s.chatChips.all, s.chatChips.people, s.chatChips.clubs, s.chatChips.events]} />
      <div className={styles.chatList}>
        {rows.map((r) => (
          <div key={r.name} className={styles.chatRow}>
            <div
              className={`${styles.av} ${r.tone === 'dark' ? styles.avDark : ''} ${r.tone === 'red' ? styles.avRed : ''}`}
            >
              {r.ini}
            </div>
            <div className={styles.chatMid}>
              <div className={styles.chatName}>
                {r.name}
                {r.tag && <span className={styles.tg}>{r.tag}</span>}
              </div>
              <div className={styles.chatLast}>{r.msg}</div>
            </div>
            <div className={styles.chatEnd}>
              <div className={styles.chatTime}>{r.when}</div>
              {r.unread > 0 && <div className={styles.unread}>{num(r.unread)}</div>}
            </div>
          </div>
        ))}
      </div>
      <AppNav active="chat" />
    </>
  );
}
