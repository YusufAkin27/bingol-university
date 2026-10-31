import type { CSSProperties } from 'react';
import { useI18n } from '../../../i18n/I18nProvider';
import { SHOTS, type ShotId } from './screenshots';
import styles from './PhoneMockup.module.css';

const FULL_W = 600;
const FULL_H = 1298;

interface Props {
  /** `screenshots.ts` içindeki ekran kimliği. */
  shot: ShotId;
  /**
   * LCP görseli (sayfanın ilk ekranındaki telefon): `fetchpriority=high`, `loading=eager`.
   * Diğer telefonlar `loading=lazy` ile gelir. Sayfada en çok bir tane `priority` olmalı.
   */
  priority?: boolean;
  /** Alttan solarak kaybolan (kırpılmış) görünüm; verilmezse ekranın kendi ayarı (altı boş ekranlar peek'tir). */
  peek?: boolean;
  /**
   * Telefonun yalnız üst kısmını göster (tam boy bir ekranın 0-1 arası oranı, örn. 0.6): kartlarda kısa ama gerçek telefon görünümü.
   * Verilince `peek` otomatik açılır (alt kenar solar).
   */
  crop?: number;
  /** Hafif eğim (derece, +/-). `prefers-reduced-motion` ile ilgisi yok: sabit duruş. */
  tilt?: number;
  /** Telefon genişliği (CSS uzunluğu, örn. "260px" ya da "min(70vw, 280px)"); varsayılan 260px. */
  width?: string;
  className?: string;
  style?: CSSProperties;
}

/**
 * iPhone görünümlü cihaz çerçevesi (saf CSS): ince titanyum kenar, siyah çerçeve, dinamik ada, yuvarlak köşe, gölge.
 * Ekran içi `<img>`'dir (en-boy oranı width/height ile sabit: CLS yok); alt metni çevrilir (site.shot.*.alt).
 * Açık/koyu tema ve RTL'de bozulmaz (çerçeve nötr koyudur, yön bağımsız fiziksel yerleşim).
 * Boyut: `width` desteği ya da bağlamda `--phone-w` değişkeni.
 */
export function PhoneMockup({ shot, priority, peek, crop, tilt = 0, width, className, style }: Props) {
  const { t } = useI18n();
  const s = SHOTS[shot];
  const isPeek = crop !== undefined || (peek ?? s.peek);
  // React 18, fetchPriority özelliğini tanımaz: küçük harfli öznitelik olarak geçirilir
  const hint = priority ? ({ fetchpriority: 'high' } as Record<string, string>) : {};
  const vars: CSSProperties & Record<string, string | number> = { ...style, '--tilt': `${tilt}deg` };
  if (width) vars['--phone-w'] = width;
  // ekran alanı telefon genişliğinin ~%92'si; oran, TAM boy bir ekrana (600x1298) göre: kısa görseller de aynı yüksekliğe kırpılır
  if (crop !== undefined) vars['--crop-h'] = String(Math.round(crop * (FULL_H / FULL_W) * 0.92 * 1000) / 1000);
  return (
    <div className={`${styles.phone} ${isPeek ? styles.peek : ''} ${className ?? ''}`} style={vars}>
      <div className={styles.body}>
        <div className={styles.bezel}>
          <div className={styles.screen}>
            <img
              src={s.src}
              width={s.width}
              height={s.height}
              alt={t(s.alt)}
              loading={priority ? 'eager' : 'lazy'}
              decoding="async"
              draggable={false}
              {...hint}
            />
          </div>
        </div>
        <span className={styles.island} aria-hidden="true" />
      </div>
    </div>
  );
}
