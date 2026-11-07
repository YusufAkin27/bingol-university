/**
 * Türkçe duyarlı metin sadeleştirme. ÖNEMLİ: çıktı girdiyle AYNI uzunluktadır (karakter karakter eşleme);
 * böylece sadeleşmiş metindeki konumlar özgün metne birebir taşınır (vurgulama için).
 *
 * İ/I/ı/i → i, ç → c, ğ → g, ö → o, ş → s, ü → u, aksanlar silinir, büyük/küçük harf yok sayılır,
 * harf ve rakam dışındaki her şey boşluk olur.
 */
const SPECIAL: Record<string, string> = {
  İ: 'i',
  I: 'i',
  ı: 'i',
  ç: 'c',
  Ç: 'c',
  ğ: 'g',
  Ğ: 'g',
  ö: 'o',
  Ö: 'o',
  ş: 's',
  Ş: 's',
  ü: 'u',
  Ü: 'u',
  â: 'a',
  Â: 'a',
  î: 'i',
  Î: 'i',
  û: 'u',
  Û: 'u',
  ß: 's',
};

const charCache = new Map<string, string>();
const LETTER_OR_DIGIT = /[\p{L}\p{N}]/u;

function foldChar(ch: string): string {
  const hit = charCache.get(ch);
  if (hit !== undefined) return hit;
  let out = SPECIAL[ch];
  if (out === undefined) {
    // birleştirici işaretler (tek başına) silinemez (uzunluk korunur): boşluk
    const base = ch.normalize('NFD')[0] ?? ch;
    const lower = base.toLowerCase()[0] ?? base;
    out = LETTER_OR_DIGIT.test(lower) ? lower : ' ';
  }
  charCache.set(ch, out);
  return out;
}

/** Aynı uzunlukta, küçük harfli, aksansız, harf/rakam dışı = boşluk. */
export function fold(s: string): string {
  let out = '';
  for (let i = 0; i < s.length; i++) out += foldChar(s[i]);
  return out;
}

/** Sadeleşmiş metni sözcüklere böler. */
export function words(folded: string): string[] {
  return folded.split(' ').filter(Boolean);
}

/** Sorguyu sadeleşmiş sözcüklere çevirir. */
export function tokenize(query: string): string[] {
  return words(fold(query));
}

const BUF = 64;
const rowA = new Int32Array(BUF + 1);
const rowB = new Int32Array(BUF + 1);
const rowC = new Int32Array(BUF + 1);

/**
 * Sınırlı Damerau-Levenshtein (bitişik harf yer değiştirme 1 sayılır). `max`'ı aşarsa `max + 1` döner.
 * Önceden ayrılmış satır dizileri kullanır (sıcak yolda bellek ayırmaz); 64 harften uzun sözcük yazım hatası denetimine girmez.
 */
export function editDistance(a: string, b: string, max: number): number {
  if (a === b) return 0;
  const la = a.length;
  const lb = b.length;
  if (Math.abs(la - lb) > max || la > BUF || lb > BUF) return max + 1;
  if (la === 0) return lb <= max ? lb : max + 1;
  if (lb === 0) return la <= max ? la : max + 1;
  let prev2 = rowA;
  let prev = rowB;
  let cur = rowC;
  for (let j = 0; j <= lb; j++) prev[j] = j;
  for (let i = 1; i <= la; i++) {
    cur[0] = i;
    let rowMin = i;
    const ca = a.charCodeAt(i - 1);
    for (let j = 1; j <= lb; j++) {
      const cost = ca === b.charCodeAt(j - 1) ? 0 : 1;
      let v = prev[j] + 1;
      const ins = cur[j - 1] + 1;
      if (ins < v) v = ins;
      const sub = prev[j - 1] + cost;
      if (sub < v) v = sub;
      if (i > 1 && j > 1 && ca === b.charCodeAt(j - 2) && a.charCodeAt(i - 2) === b.charCodeAt(j - 1)) {
        const tr = prev2[j - 2] + 1;
        if (tr < v) v = tr;
      }
      cur[j] = v;
      if (v < rowMin) rowMin = v;
    }
    if (rowMin > max) return max + 1;
    const t = prev2;
    prev2 = prev;
    prev = cur;
    cur = t;
  }
  const r = prev[lb];
  return r <= max ? r : max + 1;
}

/** Türkçe ekler (sadeleşmiş biçim). Yalnız SORGU sözcüğünden gövde türetmek içindir. */
const SUFFIXES = [
  'larimiz', 'lerimiz', 'lardan', 'lerden', 'larin', 'lerin', 'larda', 'lerde', 'larla', 'lerle', 'lari', 'leri',
  'lara', 'lere', 'lar', 'ler', 'nin', 'nun', 'dan', 'den', 'tan', 'ten', 'da', 'de', 'ta', 'te', 'in', 'un',
  'la', 'le', 'ya', 'ye', 'si', 'su', 'yi', 'yu', 'i', 'u', 'a', 'e',
].sort((a, b) => b.length - a.length);

/**
 * Sorgu sözcüğünün olası gövdeleri ("mesajlarından" → mesajlarin, mesajlar, mesaj). Kendisi dahil değildir.
 * En fazla 3 ek soyulur; 3 harften kısa gövdeler ve tek harfli ekten sonra 4 harften kısa gövdeler atılır.
 * Gövdeler yalnız eşleşmeyi genişletir; yanlış bir gövde sonuç kirletmez (VE kuralı + yalnız önek/yazım hatası).
 */
export function stems(token: string): string[] {
  const out: string[] = [];
  const seen = new Set<string>([token]);
  let frontier = [token];
  for (let depth = 0; depth < 3 && frontier.length > 0; depth++) {
    const next: string[] = [];
    for (const w of frontier) {
      for (const suf of SUFFIXES) {
        if (!w.endsWith(suf)) continue;
        const stem = w.slice(0, w.length - suf.length);
        if (stem.length < (suf.length === 1 ? 4 : 3) || seen.has(stem)) continue;
        seen.add(stem);
        out.push(stem);
        next.push(stem);
      }
    }
    frontier = next;
  }
  // uzun gövde (özgün sözcüğe en yakın) önce; en çok 6
  return out.sort((a, b) => b.length - a.length).slice(0, 6);
}

/** Sözcük uzunluğuna göre yazım hatası payı: ≤3 harf 0, 4-7 harf 1, 8+ harf 2. */
export function tolerance(len: number): number {
  if (len <= 3) return 0;
  if (len <= 7) return 1;
  return 2;
}
