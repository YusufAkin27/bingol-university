import { Link } from '../LocalizedLink';
import { markAssets, type MarkAsset } from '../../assets/brand';
import { useI18n } from '../../i18n/I18nProvider';
import styles from './Logo.module.css';

/** `mark`: yalnız BÜ glifi; `horizontal`: glif + yanında "Kampüs"; `vertical`: glif üstte, "Kampüs" altta */
export type LogoVariant = 'mark' | 'horizontal' | 'vertical';
/** Zemin tonu: `light` = açık zemin (siyah glif), `dark` = koyu zemin (beyaz glif), `auto` = temaya göre */
export type LogoTone = 'auto' | 'light' | 'dark';

interface LogoProps {
  variant?: LogoVariant;
  tone?: LogoTone;
  /** Görüntülenen yükseklik (px); glif genişliği orandan hesaplanır */
  height?: number;
  /** Verilirse logo bir bağlantıdır */
  to?: string;
  /** Süs amaçlı kullanım (yanında ad yazıyorsa): alt metin boş, ekran okuyuculardan gizli */
  decorative?: boolean;
  /** Sayfa üstü (LCP) logo: açık ton hemen yüklenir; öncelik yoksa tembel yüklenir. */
  priority?: boolean;
  className?: string;
}

const DEFAULT_HEIGHT: Record<LogoVariant, number> = { mark: 36, horizontal: 36, vertical: 96 };

function Glyph({
  asset,
  glyphH,
  alt,
  cls,
  lazy,
}: {
  asset: MarkAsset;
  glyphH: number;
  alt: string;
  cls: string;
  /** Gizli (CSS ile display:none) tema varyantı: tarayıcı lazy görseli düzen kutusu yokken indirmez. */
  lazy?: boolean;
}) {
  const w = Math.round((glyphH * asset.width) / asset.height);
  return (
    <img
      src={asset.src}
      srcSet={asset.srcSet}
      sizes={`${w}px`}
      width={w}
      height={glyphH}
      alt={alt}
      aria-hidden={alt === '' ? true : undefined}
      className={cls}
      draggable={false}
      decoding="async"
      loading={lazy ? 'lazy' : undefined}
    />
  );
}

/**
 * Marka: siyah-beyaz BÜ glifi (dark_logo / light_logo; görseller `src/assets/brand`, `web/scripts/build-brand.py` üretir).
 * `tone="auto"` iki görseli de basar ve CSS ile temaya göre birini gösterir: koyu temada beyaz, açık temada siyah glif.
 */
export function Logo({
  variant = 'horizontal',
  tone = 'auto',
  height,
  to,
  decorative = false,
  priority = false,
  className,
}: LogoProps) {
  const { t } = useI18n();
  const h = height ?? DEFAULT_HEIGHT[variant];
  const alt = decorative ? '' : t('common.logoAlt');
  const hasWord = variant !== 'mark';
  // Yatay: glif yüksekliğin tamamı değil, yazı ile dengeli olsun; dikey: yükseklik glif + yazıyı kapsar
  const glyphH = variant === 'vertical' ? Math.round(h * 0.62) : variant === 'horizontal' ? Math.round(h * 0.78) : h;
  const wordPx = variant === 'vertical' ? Math.round(h * 0.2) : Math.round(h * 0.56);
  const cls = [styles.logo, className].filter(Boolean).join(' ');

  const glyphs =
    tone === 'auto' ? (
      <>
        <Glyph asset={markAssets.light} glyphH={glyphH} alt={alt} lazy={!priority} cls={`${styles.img} ${styles.forLight}`} />
        <Glyph asset={markAssets.dark} glyphH={glyphH} alt={alt} lazy cls={`${styles.img} ${styles.forDark}`} />
      </>
    ) : (
      <Glyph asset={markAssets[tone]} glyphH={glyphH} alt={alt} lazy={!priority} cls={styles.img} />
    );

  const content = (
    <>
      {glyphs}
      {hasWord && (
        <span className={styles.word} style={{ fontSize: wordPx }} aria-hidden="true">
          Kampüs
        </span>
      )}
    </>
  );

  const toneCls = tone === 'light' ? styles.onLight : tone === 'dark' ? styles.onDark : '';
  const all = `${cls} ${toneCls}`.trim();
  if (to) {
    return (
      // tone="auto": koyu temada açık görsel gizlenir, görünen görselin alt'ı boştur; bağlantı adı buradan gelir
      <Link to={to} className={all} data-variant={variant} aria-label={decorative ? undefined : alt}>
        {content}
      </Link>
    );
  }
  return (
    <span className={all} data-variant={variant}>
      {content}
    </span>
  );
}
