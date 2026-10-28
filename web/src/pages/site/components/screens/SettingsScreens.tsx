import { Ico } from './Ico';
import { AppNav, ScreenHeader, Toggle } from './Parts';
import { useScreenKit } from './text';
import styles from './screens.module.css';

/** Bildirim tercihleri: tür başına açma/kapama anahtarları. */
export function NotificationsScreen() {
  const { s } = useScreenKit();
  const on = [true, true, true, false, true];
  return (
    <>
      <ScreenHeader title={s.notifTitle} />
      <div className={`${styles.card} ${styles.group}`}>
        {s.notif.map((label, i) => (
          <div key={label} className={styles.setRow}>
            <span className={styles.grow}>{label}</span>
            <Toggle on={on[i]} />
          </div>
        ))}
      </div>
      <AppNav active="profile" />
    </>
  );
}

/** Dil seçimi: üç dil, geçerli site dili seçili görünür. */
export function LanguagesScreen() {
  const { s, lang } = useScreenKit();
  const langs = [
    { code: 'tr', label: 'Türkçe' },
    { code: 'en', label: 'English' },
    { code: 'ar', label: 'العربية' },
  ];
  return (
    <>
      <ScreenHeader title={s.langTitle} />
      <div className={`${styles.card} ${styles.group}`}>
        {langs.map((l) => (
          <div key={l.code} className={styles.setRow}>
            <span className={styles.grow} lang={l.code}>
              {l.label}
            </span>
            <span className={`${styles.radio} ${l.code === lang ? styles.radioOn : ''}`} />
          </div>
        ))}
      </div>
      <AppNav active="profile" />
    </>
  );
}

/** Gizlilik: profil görünürlüğü anahtarları, veri indirme ve hesap silme satırları. */
export function PrivacyScreen() {
  const { s } = useScreenKit();
  return (
    <>
      <ScreenHeader title={s.privacyTitle} />
      <div className={`${styles.card} ${styles.group}`}>
        <div className={styles.setRow}>
          <span className={styles.grow}>{s.showEmail}</span>
          <Toggle on={false} />
        </div>
        <div className={styles.setRow}>
          <span className={styles.grow}>{s.showOnline}</span>
          <Toggle on />
        </div>
        <div className={styles.setRow}>
          <span className={styles.grow}>{s.downloadData}</span>
          <Ico name="chev" className={styles.mut} />
        </div>
        <div className={styles.setRow}>
          <span className={`${styles.grow} ${styles.danger}`}>{s.deleteAccount}</span>
          <Ico name="chev" className={styles.danger} />
        </div>
      </div>
      <AppNav active="profile" />
    </>
  );
}
