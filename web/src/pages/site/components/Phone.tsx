import type { CSSProperties, ReactNode } from 'react';
import { Icon, type IconName } from '../../../components/ui';
import { LogoMark } from '../../../components/Logo';
import { useI18n } from '../../../i18n/I18nProvider';
import styles from './Phone.module.css';

export type ScreenKind =
  | 'home'
  | 'news'
  | 'menu'
  | 'chat'
  | 'communities'
  | 'events'
  | 'support'
  | 'notifications'
  | 'languages'
  | 'privacy';

const line = (w: number, extra?: string) => (
  <i className={`${styles.line} ${extra ?? ''}`} style={{ width: `${w}%` }} />
);

function Row({ w = 80, tag }: { w?: number; tag?: boolean }) {
  return (
    <div className={styles.row}>
      <span className={styles.thumb} />
      <span className={styles.rowText}>
        {line(w)}
        {line(55, styles.faint)}
      </span>
      {tag && <span className={styles.tag} />}
    </div>
  );
}

function Screen({ kind }: { kind: ScreenKind }): ReactNode {
  switch (kind) {
    case 'home':
      return (
        <>
          <div className={styles.hero}>
            {line(60, styles.onDark)}
            {line(35, styles.onDarkFaint)}
          </div>
          <Row w={85} />
          <Row w={70} />
          <Row w={78} />
        </>
      );
    case 'news':
      return (
        <>
          <div className={styles.chips}>
            <b className={styles.chipOn} />
            <b />
            <b />
          </div>
          <Row w={90} />
          <Row w={72} />
          <Row w={84} />
          <Row w={66} />
        </>
      );
    case 'menu':
      return (
        <>
          <div className={styles.days}>
            {[0, 1, 2, 3, 4, 5, 6].map((d) => (
              <b key={d} className={d === 2 ? styles.dayOn : ''} />
            ))}
          </div>
          {[0, 1, 2, 3].map((d) => (
            <div key={d} className={styles.dish}>
              <span className={styles.plate} />
              <span className={styles.rowText}>{line(70 - d * 6)}</span>
              <span className={styles.kcal} />
            </div>
          ))}
        </>
      );
    case 'chat':
      return (
        <>
          <div className={`${styles.bubble} ${styles.them}`}>{line(80)}</div>
          <div className={`${styles.bubble} ${styles.me}`}>
            {line(90, styles.onDark)}
            {line(50, styles.onDarkFaint)}
          </div>
          <div className={`${styles.bubble} ${styles.them}`}>
            {line(60)}
            {line(40, styles.faint)}
          </div>
          <div className={`${styles.bubble} ${styles.me}`}>{line(55, styles.onDark)}</div>
          <div className={styles.composer}>
            <span />
            <b />
          </div>
        </>
      );
    case 'communities':
      return (
        <div className={styles.tiles}>
          {[0, 1, 2, 3, 4, 5].map((k) => (
            <div key={k} className={styles.tile}>
              <span className={`${styles.avatar} ${styles[`a${k % 3}` as 'a0']}`} />
              {line(70)}
              {line(40, styles.faint)}
            </div>
          ))}
        </div>
      );
    case 'events':
      return (
        <>
          <div className={styles.eventCard}>
            <span className={styles.date}>
              <i />
              <i />
            </span>
            <span className={styles.rowText}>
              {line(80)}
              {line(50, styles.faint)}
            </span>
          </div>
          <div className={styles.scan}>
            <span className={styles.corner} data-c="a" />
            <span className={styles.corner} data-c="b" />
            <span className={styles.corner} data-c="c" />
            <span className={styles.corner} data-c="d" />
            <span className={styles.beam} />
            <span className={styles.qrDots}>
              {Array.from({ length: 25 }, (_, i) => (
                <b key={i} className={[0, 2, 4, 6, 10, 12, 14, 18, 20, 22, 24].includes(i) ? styles.dotOn : ''} />
              ))}
            </span>
          </div>
        </>
      );
    case 'support':
      return (
        <>
          {[
            ['open', 78],
            ['wait', 64],
            ['done', 72],
          ].map(([s, w]) => (
            <div key={s} className={styles.ticket}>
              <span className={styles.rowText}>
                {line(Number(w))}
                {line(45, styles.faint)}
              </span>
              <span className={`${styles.pill} ${styles[s as 'open']}`} />
            </div>
          ))}
          <div className={styles.fab}>
            <Icon name="plus" size={14} />
          </div>
        </>
      );
    case 'notifications':
      return (
        <>
          {[true, true, false, true, false].map((on, i) => (
            <div key={i} className={styles.toggleRow}>
              <span className={styles.rowText}>{line(60 - i * 4)}</span>
              <span className={`${styles.switch} ${on ? styles.switchOn : ''}`}>
                <b />
              </span>
            </div>
          ))}
        </>
      );
    case 'languages':
      return (
        <div className={styles.langs}>
          {['Türkçe', 'English', 'العربية'].map((l, i) => (
            <div key={l} className={`${styles.lang} ${i === 0 ? styles.langOn : ''}`}>
              <span lang={i === 1 ? 'en' : i === 2 ? 'ar' : 'tr'}>{l}</span>
              <span className={styles.radio} />
            </div>
          ))}
        </div>
      );
    case 'privacy':
      return (
        <div className={styles.shield}>
          <Icon name="shield" size={64} />
          {line(70)}
          {line(50, styles.faint)}
          <div className={styles.pillBtn} />
        </div>
      );
  }
}

const TABS: IconName[] = ['home', 'news', 'message', 'bell'];

interface Props {
  screen: ScreenKind;
  /** Üstten kırpılmış görünüm (sıradağın ardından yükselen telefon). */
  peek?: boolean;
  tilt?: number;
  /** Telefon genişliği (em, yazı boyutu 10px tabanlıdır). */
  className?: string;
  style?: CSSProperties;
}

/**
 * Salt CSS telefon maketi. Gerçek ekran görüntüsü DEĞİLDİR; içerik soyut satırlardan oluşur.
 * Erişilebilirlikte tek bir görsel olarak okunur.
 */
export function Phone({ screen, peek, tilt = 0, className, style }: Props) {
  const { t } = useI18n();
  return (
    <div
      role="img"
      aria-label={t('site.mock.alt')}
      className={`${styles.phone} ${peek ? styles.peek : ''} ${className ?? ''}`}
      style={{ ...style, ['--tilt' as string]: `${tilt}deg` }}
    >
      <div className={styles.frame} aria-hidden="true">
        <span className={styles.notch} />
        <div className={styles.appbar}>
          <LogoMark size={18} />
          <span className={styles.title}>{line(34, styles.onDark)}</span>
        </div>
        <div className={styles.body}>
          <Screen kind={screen} />
        </div>
        <div className={styles.tabs}>
          {TABS.map((n, i) => (
            <span key={n} className={i === 0 ? styles.tabOn : ''}>
              <Icon name={n} size={14} />
            </span>
          ))}
        </div>
      </div>
    </div>
  );
}
