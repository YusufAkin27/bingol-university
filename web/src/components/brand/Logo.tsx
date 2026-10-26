import { Link } from 'react-router-dom';
import { lockupAssets, markAsset } from '../../assets/brand';
import { useI18n } from '../../i18n/I18nProvider';
import styles from './Logo.module.css';

export type LogoVariant = 'mark' | 'horizontal' | 'vertical';
/** Zemin tonu: `light` = açık zemin (lacivert yazı), `dark` = koyu zemin (beyaz yazı), `auto` = temaya göre */
export type LogoTone = 'auto' | 'light' | 'dark';

interface LogoProps {
  variant?: LogoVariant;
  tone?: LogoTone;
  /** "BİNGÖL ÜNİVERSİTESİ" alt satırlı sürüm (yalnızca yatay/dikey) */
  tagline?: boolean;
  /** Görüntülenen yükseklik (px); genişlik oranından hesaplanır */
  height?: number;
  /** Verilirse logo bir bağlantıdır */
  to?: string;
  /** Süs amaçlı kullanım (yanında ad yazıyorsa): alt metin boş, ekran okuyuculardan gizli */
  decorative?: boolean;
  className?: string;
}

const DEFAULT_HEIGHT: Record<LogoVariant, number> = { mark: 36, horizontal: 36, vertical: 96 };

function Img({
  src,
  width,
  height,
  alt,
  className,
}: {
  src: string;
  width: number;
  height: number;
  alt: string;
  className?: string;
}) {
  return (
    <img
      src={src}
      width={width}
      height={height}
      alt={alt}
      aria-hidden={alt === '' ? true : undefined}
      className={className}
      draggable={false}
      decoding="async"
    />
  );
}

/**
 * Marka: işaret (kırmızı BÜ karesi), yatay ve dikey kilitler. Görsel dosyaları `src/assets/brand`
 * (brand/build.js üretir). `tone="auto"` iki görseli de basar ve CSS ile temaya göre birini gösterir.
 */
export function Logo({
  variant = 'horizontal',
  tone = 'auto',
  tagline = false,
  height,
  to,
  decorative = false,
  className,
}: LogoProps) {
  const { t } = useI18n();
  const h = height ?? DEFAULT_HEIGHT[variant];
  const alt = decorative ? '' : t('common.logoAlt');
  const cls = [styles.logo, className].filter(Boolean).join(' ');

  let content: JSX.Element;
  if (variant === 'mark') {
    content = <Img src={markAsset.src} width={h} height={h} alt={alt} className={styles.img} />;
  } else {
    const key = (tn: 'light' | 'dark') => `${variant}${tagline ? '-tagline' : ''}-${tn}`;
    const dims = (tn: 'light' | 'dark') => {
      const a = lockupAssets[key(tn)];
      return { a, w: Math.round((h * a.width) / a.height) };
    };
    if (tone === 'auto') {
      const l = dims('light');
      const d = dims('dark');
      content = (
        <>
          <Img src={l.a.src} width={l.w} height={h} alt={alt} className={`${styles.img} ${styles.forLight}`} />
          <Img src={d.a.src} width={d.w} height={h} alt="" className={`${styles.img} ${styles.forDark}`} />
        </>
      );
    } else {
      const x = dims(tone);
      content = <Img src={x.a.src} width={x.w} height={h} alt={alt} className={styles.img} />;
    }
  }

  if (to) {
    return (
      <Link to={to} className={cls} data-variant={variant}>
        {content}
      </Link>
    );
  }
  return (
    <span className={cls} data-variant={variant}>
      {content}
    </span>
  );
}
