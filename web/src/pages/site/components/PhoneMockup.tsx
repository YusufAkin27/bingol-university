import { useEffect, useState, type CSSProperties } from 'react';
import { useI18n } from '../../../i18n/I18nProvider';
import { useDomTheme } from '../../../lib/useDomTheme';
import { SHOTS, shotSrc, type ShotId } from './screenshots';
import styles from './PhoneMockup.module.css';

/** Ekranın tam boy yüksekliği / telefon genişliği (1179x2556 ekran, kenar payları dahil): `crop` oranı buna göre. */
const FULL_SCREEN_H = 2.08;

interface Props {
  /** `screenshots.ts` içindeki ekran kimliği. */
  shot: ShotId;
  /**
   * LCP görseli (sayfanın ilk ekranındaki telefon): `fetchpriority=high`, `loading=eager`.
   * Diğer telefonlar `loading=lazy` ile gelir. Sayfada en çok bir tane `priority` olmalı.
   */
  priority?: boolean;
  /** Alttan solarak kaybolan (kırpılmış) görünüm. `crop` verilince otomatik açılır. */
  peek?: boolean;
  /**
   * Telefonun yalnız üst kısmını göster (tam boy bir ekranın 0-1 arası oranı, örn. 0.6): kartlarda kısa ama gerçek telefon görünümü.
   * Verilince `peek` otomatik açılır (alt kenar solar, ana gösterge çizilmez).
   */
  crop?: number;
  /** Hafif eğim (derece, +/-). Sabit duruş. */
  tilt?: number;
  /** Telefon genişliği (CSS uzunluğu, örn. "260px" ya da "min(70vw, 280px)"); varsayılan 260px. */
  width?: string;
  className?: string;
  style?: CSSProperties;
}

/** iOS durum çubuğu simgeleri (süs, `currentColor`): hücresel sinyal, Wi-Fi, pil. */
function StatusIcons() {
  return (
    <span className={styles.icons} aria-hidden="true">
      <svg viewBox="0 0 18 12" className={styles.signal} fill="currentColor">
        <rect x="0" y="8" width="3" height="4" rx="0.8" />
        <rect x="5" y="5.5" width="3" height="6.5" rx="0.8" />
        <rect x="10" y="3" width="3" height="9" rx="0.8" />
        <rect x="15" y="0" width="3" height="12" rx="0.8" />
      </svg>
      <svg viewBox="0 0 17 12" className={styles.wifi} fill="currentColor">
        <path d="M8.5 2.3c2.3 0 4.4.9 6 2.4.1.1.3.1.4 0l.9-.9c.1-.1.1-.3 0-.4A11.3 11.3 0 0 0 8.5.1C5.6.1 3 1.2 1.2 3.4c-.1.1-.1.3 0 .4l.9.9c.1.1.3.1.4 0a8.6 8.6 0 0 1 6-2.4z" />
        <path d="M8.5 6c1.3 0 2.5.5 3.4 1.3.1.1.3.1.4 0l.9-.9c.1-.1.1-.3 0-.4A7.6 7.6 0 0 0 8.5 3.8c-1.9 0-3.7.7-5.1 2.2-.1.1-.1.3 0 .4l.9.9c.1.1.3.1.4 0A5 5 0 0 1 8.5 6z" />
        <path d="M8.5 9.6c.6 0 1.2.2 1.6.6.1.1.1.3 0 .4l-1.4 1.3a.3.3 0 0 1-.4 0L6.9 10.6c-.1-.1-.1-.3 0-.4.4-.4 1-.6 1.6-.6z" />
      </svg>
      <svg viewBox="0 0 27 12" className={styles.battery} fill="none">
        <rect x="0.5" y="0.5" width="22" height="11" rx="3.2" stroke="currentColor" opacity="0.4" />
        <rect x="2" y="2" width="19" height="8" rx="2" fill="currentColor" />
        <path d="M24.2 4v4c.8-.3 1.5-1.1 1.5-2s-.7-1.7-1.5-2z" fill="currentColor" opacity="0.45" />
      </svg>
    </span>
  );
}

/**
 * iPhone 15 Pro görünümlü cihaz çerçevesi (saf CSS + SVG): ince siyah çerçeve, ölçeğe orantılı köşe, Dynamic Island, iOS durum çubuğu
 * (9:41, sinyal/Wi-Fi/pil; yazı rengi ekran temasına uyar), alt ana gösterge çubuğu ve çok ince yan tuşlar. Ağır gölge yok.
 *
 * Ekran görüntüsü sayfanın temasına göre seçilir (`screenshots.ts`: `<ad>-light.png` / `<ad>-dark.png`, 1179x2556). Dosya yoksa
 * .png yedeği, o da yoksa boş zemin çizilir; bileşen eksik dosyada çökmez. `<img width height>` sabit (CLS yok),
 * `object-fit: cover; object-position: top`, alt metni çevrilir (site.shot.*.alt). RTL'de fiziksel yerleşim korunur.
 * Boyut: `width` desteği ya da bağlamda `--phone-w` değişkeni.
 */
export function PhoneMockup({ shot, priority, peek, crop, tilt = 0, width, className, style }: Props) {
  const { t } = useI18n();
  const theme = useDomTheme();
  const s = SHOTS[shot];
  // webp: <ad>-<tema>.webp | png: aynı adla yedek | none: boş zemin (dosya yoksa bileşen çökmez)
  const [stage, setStage] = useState<'webp' | 'png' | 'none'>('webp');
  useEffect(() => setStage('webp'), [theme, shot]);
  const isPeek = crop !== undefined || !!peek;
  // React 18, fetchPriority özelliğini tanımaz: küçük harfli öznitelik olarak geçirilir
  const hint = priority ? ({ fetchpriority: 'high' } as Record<string, string>) : {};
  const vars: CSSProperties & Record<string, string | number> = { ...style, '--tilt': `${tilt}deg` };
  if (width) vars['--phone-w'] = width;
  if (crop !== undefined) vars['--crop-h'] = String(Math.round(crop * FULL_SCREEN_H * 1000) / 1000);

  const onError = () => setStage((cur) => (cur === 'webp' ? 'png' : 'none'));
  const src = stage === 'none' ? undefined : shotSrc(s, theme, stage);
  const alt = t(s.alt);

  return (
    <div
      className={`${styles.phone} ${isPeek ? styles.peek : ''} ${className ?? ''}`}
      style={vars}
      data-theme-shot={theme}
    >
      <div className={styles.body}>
        <div className={styles.screen} role={stage === 'none' ? 'img' : undefined} aria-label={stage === 'none' ? alt : undefined}>
          {stage !== 'none' && src && (
            <img
              key={`${stage}-${theme}`}
              src={src}
              width={s.width}
              height={s.height}
              alt={alt}
              loading={priority ? 'eager' : 'lazy'}
              decoding="async"
              draggable={false}
              onError={onError}
              {...hint}
            />
          )}
          {stage === 'none' && <span className={styles.blank} aria-hidden="true" />}
          <div className={styles.bar} aria-hidden="true">
            <span className={styles.time}>9:41</span>
            <StatusIcons />
          </div>
          {!isPeek && <span className={styles.home} aria-hidden="true" />}
        </div>
        <span className={styles.island} aria-hidden="true" />
      </div>
    </div>
  );
}
