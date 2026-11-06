// Marka görselleri: web/scripts/build-brand.py üretir (kaynak: brand/source/*_logo.png).
// Şeffaf zeminli glif: `light` = siyah glif (açık zemin), `dark` = beyaz glif (koyu zemin).
// srcset: 96 (public/brand) / 192 / 384 px genişlik; 96 px dosya ana pakete gömülmesin diye public'te; tarayıcı ekran yoğunluğuna göre seçer (aşırı küçültme bulanıklığı olmaz).
import markLight from './mark-light.png';
import markLight384 from './mark-light-384.png';
import markDark from './mark-dark.png';
import markDark384 from './mark-dark-384.png';

export interface MarkAsset {
  src: string;
  srcSet: string;
  width: number;
  height: number;
}

export const markAssets: Record<'light' | 'dark', MarkAsset> = {
  light: { src: markLight, srcSet: `/brand/mark-light-96.png 96w, ${markLight} 192w, ${markLight384} 384w`, width: 192, height: 127 },
  dark: { src: markDark, srcSet: `/brand/mark-dark-96.png 96w, ${markDark} 192w, ${markDark384} 384w`, width: 192, height: 127 },
};
