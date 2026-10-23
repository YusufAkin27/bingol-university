import type { FaqGroup } from '../../../api/types';

/** Büyük/küçük harf, aksan ve Türkçe i/ı farkını yok sayan arama biçimi. */
export function normalize(s: string): string {
  return s
    .toLocaleLowerCase('tr')
    .replace(/ı/g, 'i')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '');
}

/** Sorgudaki her sözcüğü (soru + yanıt + kategori içinde) arar; boş sorgu her şeyi döndürür. */
export function filterFaq(groups: FaqGroup[], query: string): FaqGroup[] {
  const words = normalize(query).split(/\s+/).filter(Boolean);
  if (!words.length) return groups;
  return groups
    .map((g) => ({
      ...g,
      items: g.items.filter((it) => {
        const hay = normalize(`${it.question} ${it.answer} ${g.category}`);
        return words.every((w) => hay.includes(w));
      }),
    }))
    .filter((g) => g.items.length > 0);
}

export function countFaq(groups: FaqGroup[]): number {
  return groups.reduce((n, g) => n + g.items.length, 0);
}
