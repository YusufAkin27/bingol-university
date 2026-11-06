// Marka görselleri: web/scripts/build-brand.py üretir (kaynak: repo kökündeki dark_logo.png / light_logo.png).
// Şeffaf zeminli glif: `light` = siyah glif (açık zemin), `dark` = beyaz glif (koyu zemin).
import markLight from './mark-light.png';
import markDark from './mark-dark.png';

export interface MarkAsset {
  src: string;
  width: number;
  height: number;
}

export const markAssets: Record<'light' | 'dark', MarkAsset> = {
  light: { src: markLight, width: 192, height: 139 },
  dark: { src: markDark, width: 192, height: 136 },
};
