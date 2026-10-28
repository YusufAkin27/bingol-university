import type { CSSProperties } from 'react';
import { SCREENS, type ScreenKind } from './screens';
import screenStyles from './screens/screens.module.css';
import styles from './Phone.module.css';

export type { ScreenKind };

interface Props {
  screen: ScreenKind;
  /** Alttan kırpılmış, solarak kaybolan görünüm (bölüm içi kullanım). */
  peek?: boolean;
  /** Eğim (derece). */
  tilt?: number;
  /** Boyut `--phone-s` (ekran ölçeği; 390 px tasarım genişliği çarpanı, varsayılan 0,56) ile verilir. */
  className?: string;
  style?: CSSProperties;
}

/**
 * Telefon çerçevesi. İçindeki ekran, mobil uygulamanın ilgili ekranının HTML/CSS ile yeniden çizimidir
 * (görsel dosya yok; bkz. ./screens). Süstür: tamamı ekran okuyuculardan gizlenir, sayfanın anlamı metinde kalır.
 */
export function Phone({ screen, peek, tilt = 0, className, style }: Props) {
  const Screen = SCREENS[screen];
  return (
    <div
      aria-hidden="true"
      className={`${styles.phone} ${peek ? styles.peek : ''} ${className ?? ''}`}
      style={{ ...style, ['--tilt' as string]: `${tilt}deg` }}
    >
      <div className={styles.frame}>
        <div className={styles.viewport}>
          <div className={styles.stage}>
            <div className={screenStyles.screen}>
              <Screen />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
