/**
 * Sözlük cephesi (hafif). Yalnız TÜR ve çalışma zamanı kayıt defteri işlevleri buradadır; sözlük içeriği buraya
 * ASLA içe aktarılmaz (ana paket şişer). İçerik: `bundles/*` (dil ve kapsam başına lazy parça), tam eşzamanlı küme: `all.ts`
 * (yalnız testler ve önrender). Yeni ad alanı: üç dilde dosya aç, ilgili `bundles/*` dosyalarına (ve `all.ts` tür bütünlüğüne) ekle.
 * Türkçe (tr) kaynak sözlüktür: `TranslationKey` ondan türer; en/ar `all.ts` içinde `Dictionary` olarak türlenir, eksik anahtar derleme hatasıdır.
 */
import type siteTr from './bundles/site.tr';
import type adminTr from './bundles/admin.tr';

export type { TParams } from './registry';
export { translate, hasKey } from './registry';

export type TranslationKey = keyof typeof siteTr | keyof typeof adminTr;
export type Dictionary = Record<TranslationKey, string>;
