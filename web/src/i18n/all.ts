/**
 * Tüm sözlüklerin EŞZAMANLI kümesi: yalnızca testler (`test/setup.ts`), önrender (`seo/prerender.ts`) ve
 * betikler içindir. Çalışma zamanı kodu bunu içe aktarmaz (aksi halde tüm diller ana pakete girer); orada
 * `registry.ts` ile dil başına lazy yükleme yapılır. İçe aktarıldığında sözlükleri kayıt defterine de yazar.
 */
import type { Lang } from './lang';
import { registerDictionary } from './registry';
import type { Dictionary } from './index';

import siteTr from './bundles/site.tr';
import siteEn from './bundles/site.en';
import siteAr from './bundles/site.ar';
import adminTr from './bundles/admin.tr';
import adminEn from './bundles/admin.en';
import adminAr from './bundles/admin.ar';
import adminTrOnly from './bundles/admin-tr-only';

const tr: Dictionary = { ...siteTr, ...adminTr };
// en/ar'da yalnız-Türkçe yönetim ad alanları tr metniyle katılır (panel tr'ye sabit)
const en: Dictionary = { ...siteEn, ...adminEn, ...adminTrOnly };
const ar: Dictionary = { ...siteAr, ...adminAr, ...adminTrOnly };

export const dictionaries: Record<Lang, Dictionary> = { tr, en, ar };

registerDictionary('site', 'tr', siteTr);
registerDictionary('admin', 'tr', adminTr);
registerDictionary('site', 'en', siteEn);
registerDictionary('admin', 'en', { ...adminEn, ...adminTrOnly });
registerDictionary('site', 'ar', siteAr);
registerDictionary('admin', 'ar', { ...adminAr, ...adminTrOnly });
