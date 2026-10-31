import type { IconName } from '../../../components/ui';
import type { TranslationKey } from '../../../i18n';
import type { Point } from './PointList';

/** `site.trust.<page>.pt1..` metinlerinden "Kısaca" madde listesi üretir (simge sırası maddelerle eşleşir). */
export function trustPoints(t: (key: TranslationKey) => string, page: string, icons: IconName[]): Point[] {
  return icons.map((icon, i) => ({ icon, text: t(`site.trust.${page}.pt${i + 1}` as TranslationKey) }));
}
