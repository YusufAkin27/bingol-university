// OTOMATIK URETILDI: brand/build.js (elle duzenlemeyin)
import mark from './mark.svg';
import horizontal_light from './horizontal-light.svg';
import horizontal_dark from './horizontal-dark.svg';
import horizontal_tagline_light from './horizontal-tagline-light.svg';
import horizontal_tagline_dark from './horizontal-tagline-dark.svg';
import vertical_light from './vertical-light.svg';
import vertical_dark from './vertical-dark.svg';
import vertical_tagline_light from './vertical-tagline-light.svg';
import vertical_tagline_dark from './vertical-tagline-dark.svg';

export const markAsset = { src: mark, width: 256, height: 256 };

export const lockupAssets: Record<string, { src: string; width: number; height: number }> = {
  'horizontal-light': { src: horizontal_light, width: 1965, height: 512 },
  'horizontal-dark': { src: horizontal_dark, width: 1965, height: 512 },
  'horizontal-tagline-light': { src: horizontal_tagline_light, width: 1752, height: 512 },
  'horizontal-tagline-dark': { src: horizontal_tagline_dark, width: 1752, height: 512 },
  'vertical-light': { src: vertical_light, width: 958, height: 776 },
  'vertical-dark': { src: vertical_dark, width: 958, height: 776 },
  'vertical-tagline-light': { src: vertical_tagline_light, width: 798, height: 823 },
  'vertical-tagline-dark': { src: vertical_tagline_dark, width: 798, height: 823 },
};
