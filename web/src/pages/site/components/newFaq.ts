import type { TranslationKey } from '../../../i18n';
import type { FaqItem } from './FaqAccordion';

/** Yeni özelliklere ait statik SSS (sunucudaki SSS'den bağımsızdır; metinler çeviri anahtarlarından gelir). */
export const NEW_FAQ_IDS = ['apply', 'clubRoles', 'images', 'privacy', 'encryption', 'adminAccess'] as const;

/**
 * Uygulama hakkında genel SSS (arama kalıpları: docs/SEO.md P4). Anahtarlar `site.faq.gen.<id>.(q|a)`.
 * Yanıtlarda `[metin](/yol)` biçiminde site içi bağlantı olabilir; FAQPage JSON-LD'de düz metne çevrilir.
 */
export const GENERAL_FAQ_IDS = [
  'independent',
  'who',
  'noCode',
  'free',
  'platforms',
  'menuSource',
  'calorie',
  'newsSource',
  'academic',
  'qr',
  'polls',
  'dataSold',
  'export',
  'delete',
  'support',
] as const;

type T = (key: TranslationKey) => string;

/** Genel sorular: kimlikler -1..-N, her birinin bağlanabilir kancası `faq-<id>`. */
export function buildGeneralFaq(t: T): FaqItem[] {
  return GENERAL_FAQ_IDS.map((id, i) => ({
    id: -(i + 1),
    anchor: `faq-${id}`,
    question: t(`site.faq.gen.${id}.q` as TranslationKey),
    answer: t(`site.faq.gen.${id}.a` as TranslationKey),
  }));
}

/** Yeni özellik soruları (kimlikler genel soruların devamıdır: çakışma yok). */
export function buildFeatureFaq(t: T): FaqItem[] {
  return NEW_FAQ_IDS.map((id, i) => ({
    // Sunucudaki gerçek kimliklerle çakışmasın diye negatif kimlik
    id: -(GENERAL_FAQ_IDS.length + i + 1),
    question: t(`site.faq.new.${id}.q` as TranslationKey),
    answer: t(`site.faq.new.${id}.a` as TranslationKey),
  }));
}

/** Sayfada her zaman görünen tüm statik sorular (JSON-LD bu listeden üretilir; sıra sayfadakiyle aynıdır). */
export function buildNewFaq(t: T): FaqItem[] {
  return [...buildGeneralFaq(t), ...buildFeatureFaq(t)];
}
