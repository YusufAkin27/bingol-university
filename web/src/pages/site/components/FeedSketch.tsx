import { Icon } from '../../../components/ui';
import styles from './FeedSketch.module.css';

/** İnce çizgili kalp (süs). */
function Heart() {
  return (
    <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" focusable="false">
      <path d="M12 20s-7-4.4-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.6-7 10-7 10z" />
    </svg>
  );
}

/** Soyut manzara (güneş + iki tepe): kişi/fotoğraf içermeyen yer tutucu görsel. */
function Scene() {
  return (
    <svg viewBox="0 0 120 80" className={styles.scene} fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" focusable="false" preserveAspectRatio="xMidYMid slice">
      <circle cx="68" cy="22" r="8" />
      <path d="M0 68l30-32 22 22 14-14 54 24" />
      <path d="M0 80h120" />
    </svg>
  );
}

/**
 * Gönderi akışının SOYUT çizimi (süs; ekran okuyucudan gizli): fotoğraf gönderisi, Reels kartı ve forum konusu.
 * Gerçek kullanıcı içeriği/fotoğrafı/adı YOK: avatarlar boş daire, metinler gri çizgi, görseller çizgisel manzara.
 * Renk yok; yalnız belirteçler (yüzey + ince kenarlık).
 */
export function FeedSketch() {
  return (
    <div className={styles.wrap} aria-hidden="true">
      <div className={`${styles.card} ${styles.post}`}>
        <div className={styles.head}>
          <span className={styles.avatar} />
          <span className={styles.lines}>
            <span className={styles.line} style={{ width: '46%' }} />
            <span className={`${styles.line} ${styles.faint}`} style={{ width: '30%' }} />
          </span>
        </div>
        <div className={styles.media}>
          <Scene />
        </div>
        <div className={styles.actions}>
          <Heart />
          <Icon name="message" size={18} />
          <span className={`${styles.line} ${styles.faint}`} style={{ width: '24%', marginInlineStart: 'auto' }} />
        </div>
      </div>

      <div className={`${styles.card} ${styles.reel}`}>
        <div className={styles.reelFrame}>
          <Scene />
          <span className={styles.play}>
            <svg viewBox="0 0 24 24" width="22" height="22" fill="currentColor" aria-hidden="true" focusable="false">
              <path d="M8 5.5v13l11-6.5z" />
            </svg>
          </span>
          <span className={styles.progress}>
            <span className={styles.progressBar} />
          </span>
        </div>
        <div className={styles.actions}>
          <Heart />
          <span className={`${styles.line} ${styles.faint}`} style={{ width: '40%' }} />
        </div>
      </div>

      <div className={`${styles.card} ${styles.thread}`}>
        <div className={styles.head}>
          <span className={`${styles.avatar} ${styles.small}`} />
          <span className={`${styles.line}`} style={{ width: '34%' }} />
        </div>
        <span className={styles.line} style={{ width: '92%' }} />
        <span className={`${styles.line} ${styles.faint}`} style={{ width: '78%' }} />
        <span className={`${styles.line} ${styles.faint}`} style={{ width: '56%' }} />
      </div>
    </div>
  );
}
