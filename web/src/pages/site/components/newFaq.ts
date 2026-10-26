import type { FaqEntry } from '../../../api/types';
import type { TranslationKey } from '../../../i18n';

/** Yeni özelliklere ait statik SSS (sunucudaki SSS'den bağımsızdır; metinler çeviri anahtarlarından gelir). */
export const NEW_FAQ_IDS = ['apply', 'clubRoles', 'images', 'privacy', 'encryption', 'adminAccess'] as const;

export function buildNewFaq(t: (key: TranslationKey) => string): FaqEntry[] {
  return NEW_FAQ_IDS.map((id, i) => ({
    // Sunucudaki gerçek kimliklerle çakışmasın diye negatif kimlik
    id: -(i + 1),
    question: t(`site.faq.new.${id}.q` as TranslationKey),
    answer: t(`site.faq.new.${id}.a` as TranslationKey),
  }));
}
