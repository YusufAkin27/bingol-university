/**
 * Arama motoru (saf TypeScript, React'siz). Dizin bir kez sadeleştirilir (createSearcher); sorgu başına yalnız
 * sözcük karşılaştırması yapılır (1000+ girdide birkaç ms).
 *
 * Eşleşme: her sorgu sözcüğü bir alanda tam / önek / alt dizgi / küçük yazım hatası (Damerau-Levenshtein) ile bulunmalı
 * (çok sözcük = VE). Ağırlık: başlık > anahtar kelime > açıklama > kırıntı. Tam başlık/anahtar kelime eşleşmesi en üstte.
 */
import { editDistance, fold, tokenize, tolerance, words } from './fold';
import { classOf, type SearchClass, type SearchKind } from './types';

/** Motorun beklediği asgari girdi biçimi (ResolvedEntry bunu sağlar). */
export interface Searchable {
  id: string;
  kind: SearchKind;
  title: string;
  keywords?: string[];
  description?: string;
  /** Üst başlıklar (grup, sayfa, bölüm): düşük ağırlıkla aranır. */
  crumbs?: string[];
}

export interface Hit<T extends Searchable> {
  item: T;
  score: number;
}

export interface SearchOptions<T extends Searchable> {
  /** En çok kaç sonuç (varsayılan 60). */
  limit?: number;
  /** Puanlamadan önce elenir (RBAC). */
  filter?: (item: T) => boolean;
}

interface Field {
  text: string;
  words: string[];
}

interface Doc<T extends Searchable> {
  item: T;
  title: Field;
  keywords: Field[];
  description: Field;
  crumbs: Field;
  boost: number;
}

interface Weights {
  exact: number;
  prefix: number;
  sub: number;
  fuzzy: number;
}

const W_TITLE: Weights = { exact: 100, prefix: 82, sub: 56, fuzzy: 44 };
const W_KEYWORD: Weights = { exact: 72, prefix: 60, sub: 42, fuzzy: 32 };
const W_DESC: Weights = { exact: 26, prefix: 20, sub: 12, fuzzy: 8 };
const W_CRUMB: Weights = { exact: 32, prefix: 26, sub: 15, fuzzy: 10 };

const KIND_BOOST: Record<SearchKind, number> = { page: 3, section: 2, setting: 1.5, field: 1, action: 1 };

function field(text: string): Field {
  const ws = words(fold(text));
  return { text: ws.join(' '), words: ws };
}

/** Tek sorgu sözcüğünün bir alandaki en iyi puanı (0 = eşleşmedi). `fz`: sözlükte yazım hatası payı içindeki sözcükler → mesafe. */
function scoreToken(q: string, f: Field, w: Weights, fz: Map<string, number> | null): number {
  if (f.words.length === 0) return 0;
  let best = 0;
  const qlen = q.length;
  for (const word of f.words) {
    if (word === q) return w.exact;
    if (word.startsWith(q)) {
      // kısa sözcük (daha çok yazılmış kısmı kapsayan) biraz önde
      const s = w.prefix - Math.min(8, (word.length - qlen) * 0.6);
      if (s > best) best = s;
    }
  }
  if (best > 0) return best;
  if (qlen >= 3 && f.text.includes(q)) return w.sub;
  if (!fz) return 0;
  for (const word of f.words) {
    const d = fz.get(word);
    if (d !== undefined) {
      const s = w.fuzzy - d * 6;
      if (s > best) best = s;
    }
  }
  return best;
}

export interface Searcher<T extends Searchable> {
  readonly size: number;
  search(query: string, opts?: SearchOptions<T>): Hit<T>[];
  /** Sonuçsuz sorgu için "Şunu mu aradınız?" önerisi; yoksa null. */
  suggest(query: string, opts?: SearchOptions<T>): string | null;
}

export function createSearcher<T extends Searchable>(items: readonly T[]): Searcher<T> {
  const docs: Doc<T>[] = items.map((item) => ({
    item,
    title: field(item.title),
    keywords: (item.keywords ?? []).map(field),
    description: field(item.description ?? ''),
    crumbs: field((item.crumbs ?? []).join(' ')),
    boost: KIND_BOOST[item.kind],
  }));

  // Öneri sözlüğü: sözcük → (görünen biçim, sıklık)
  const vocab = new Map<string, { shown: string; n: number }>();
  const addVocab = (text: string) => {
    for (const raw of text.split(/\s+/)) {
      const shown = raw.replace(/[^\p{L}\p{N}]/gu, '').toLocaleLowerCase('tr');
      const key = fold(shown);
      if (key.length < 3) continue;
      const v = vocab.get(key);
      if (v) v.n += 1;
      else vocab.set(key, { shown, n: 1 });
    }
  };
  for (const it of items) {
    addVocab(it.title);
    for (const k of it.keywords ?? []) addVocab(k);
  }

  // Yazım hatası için sözlük: tüm benzersiz sözcükler. Sorgu sözcüğüne yakın olanlar bir kez hesaplanır (belge başına değil).
  const uniq = new Set<string>();
  for (const d of docs) {
    for (const wd of d.title.words) uniq.add(wd);
    for (const k of d.keywords) for (const wd of k.words) uniq.add(wd);
    for (const wd of d.description.words) uniq.add(wd);
    for (const wd of d.crumbs.words) uniq.add(wd);
  }
  const uniqList = [...uniq];
  const fzCache = new Map<string, Map<string, number> | null>();
  function fuzzyWords(q: string): Map<string, number> | null {
    const tol = tolerance(q.length);
    if (tol === 0) return null;
    const hit = fzCache.get(q);
    if (hit !== undefined) return hit;
    const m = new Map<string, number>();
    for (const wd of uniqList) {
      const wl = wd.length;
      if (wl < q.length - tol) continue;
      let d = wl - q.length <= tol ? editDistance(q, wd, tol) : tol + 1;
      if (d > tol && wl > q.length) d = editDistance(q, wd.slice(0, q.length), tol);
      if (d <= tol) m.set(wd, d);
    }
    const out = m.size > 0 ? m : null;
    if (fzCache.size > 300) fzCache.clear();
    fzCache.set(q, out);
    return out;
  }

  function scoreDoc(d: Doc<T>, tokens: string[], fzs: (Map<string, number> | null)[], phrase: string): { score: number; soft: boolean } | null {
    let total = 0;
    let allFuzzy = true;
    for (let ti = 0; ti < tokens.length; ti++) {
      const q = tokens[ti];
      const fz = fzs[ti];
      let s = 0;
      let fuzzy = false;
      // yazım hatası eşleşmeleri her zaman ilgili alanın `fuzzy` ağırlığını aşmaz; kesin eşleşmeler aşar
      const consider = (f: Field, w: Weights) => {
        const v = scoreToken(q, f, w, fz);
        if (v > s) {
          s = v;
          fuzzy = v <= w.fuzzy;
        }
      };
      consider(d.title, W_TITLE);
      if (s < W_TITLE.exact) {
        for (const k of d.keywords) consider(k, W_KEYWORD);
        if (s < W_KEYWORD.exact) {
          consider(d.description, W_DESC);
          consider(d.crumbs, W_CRUMB);
        }
      }
      if (s <= 0) return null; // VE: her sözcük bulunmalı
      if (!fuzzy) allFuzzy = false;
      total += s;
    }
    let score = total / tokens.length;
    // tüm cümlenin eşleşmesi (sözcük sırası önemli)
    if (d.title.text.trim() === phrase) score += 300;
    else if (d.title.text.startsWith(phrase)) score += 90;
    else if (tokens.length > 1 && d.title.text.includes(phrase)) score += 60;
    let kwBonus = 0;
    for (const k of d.keywords) {
      const kt = k.text.trim();
      if (kt === phrase) kwBonus = Math.max(kwBonus, 220);
      else if (kt.startsWith(phrase)) kwBonus = Math.max(kwBonus, 60);
      else if (tokens.length > 1 && kt.includes(phrase)) kwBonus = Math.max(kwBonus, 40);
    }
    score += kwBonus;
    return { score: score + d.boost - d.title.text.length * 0.04, soft: allFuzzy };
  }

  function search(query: string, opts: SearchOptions<T> = {}): Hit<T>[] {
    const tokens = tokenize(query);
    if (tokens.length === 0) return [];
    const phrase = tokens.join(' ');
    const fzs = tokens.map(fuzzyWords);
    const limit = opts.limit ?? 60;
    const hits: Hit<T>[] = [];
    const soft: Hit<T>[] = [];
    for (const d of docs) {
      if (opts.filter && !opts.filter(d.item)) continue;
      const r = scoreDoc(d, tokens, fzs, phrase);
      if (!r) continue;
      if (r.soft) soft.push({ item: d.item, score: r.score });
      else hits.push({ item: d.item, score: r.score });
    }
    // yalnız yazım hatasıyla eşleşenler, kesin eşleşme varsa gürültü olur (örn. "gonderi" → "gönder"): geri çekilir
    if (hits.length === 0) hits.push(...soft);
    hits.sort((a, b) => b.score - a.score || a.item.title.length - b.item.title.length);
    return hits.length > limit ? hits.slice(0, limit) : hits;
  }

  function nearestWord(q: string): string | null {
    // zaten (önek olarak) bilinen sözcük: olduğu gibi kalır
    const exact = vocab.get(q);
    if (exact) return exact.shown;
    let bestKey: string | null = null;
    let bestD = Infinity;
    let bestN = 0;
    const tol = Math.min(3, Math.max(1, Math.ceil(q.length / 3)));
    for (const [key, v] of vocab) {
      if (key.startsWith(q)) {
        // yarım yazılmış sözcük
        const d = 0.5;
        if (d < bestD || (d === bestD && v.n > bestN)) {
          bestD = d;
          bestKey = key;
          bestN = v.n;
        }
        continue;
      }
      let d = Math.abs(key.length - q.length) > tol ? tol + 1 : editDistance(q, key, tol);
      // yarım yazılmış ve hatalı: sözcüğün başıyla karşılaştır
      if (d > tol && key.length > q.length) d = editDistance(q, key.slice(0, q.length), tol) + 0.5;
      if (d <= tol && (d < bestD || (d === bestD && v.n > bestN))) {
        bestD = d;
        bestKey = key;
        bestN = v.n;
      }
    }
    return bestKey ? (vocab.get(bestKey)?.shown ?? null) : null;
  }

  function suggest(query: string, opts: SearchOptions<T> = {}): string | null {
    const tokens = tokenize(query);
    if (tokens.length === 0) return null;
    const fixed = tokens.map(nearestWord);
    const keep = fixed.filter((w): w is string => w !== null);
    if (keep.length === 0) return null;
    // önce düzeltilmiş cümle, olmazsa tek tek düzeltilmiş sözcükler (VE eşleşmesi tutmuyorsa)
    const candidates = keep.length > 1 ? [keep.join(' '), ...keep] : [keep[0]];
    const original = fold(query).trim().replace(/\s+/g, ' ');
    for (const c of candidates) {
      if (fold(c) === original) continue;
      if (search(c, { ...opts, limit: 1 }).length > 0) return c;
    }
    return null;
  }

  return { size: docs.length, search, suggest };
}

export interface HitGroup<T extends Searchable> {
  cls: SearchClass;
  hits: Hit<T>[];
}

/** Sonuçları Sayfalar / Ayarlar / Eylemler olarak ayırır; gruplar en iyi puanına göre sıralanır, her grup `perGroup` ile sınırlanır. */
export function groupHits<T extends Searchable>(hits: Hit<T>[], perGroup = 12): HitGroup<T>[] {
  const order: SearchClass[] = ['pages', 'settings', 'actions'];
  const map = new Map<SearchClass, Hit<T>[]>();
  for (const h of hits) {
    const cls = classOf(h.item.kind);
    const list = map.get(cls);
    if (list) {
      if (list.length < perGroup) list.push(h);
    } else map.set(cls, [h]);
  }
  return order
    .filter((c) => map.has(c))
    .map((cls) => ({ cls, hits: map.get(cls) as Hit<T>[] }))
    .sort((a, b) => b.hits[0].score - a.hits[0].score || order.indexOf(a.cls) - order.indexOf(b.cls));
}

export interface Segment {
  text: string;
  hit: boolean;
}

/** Metindeki eşleşen kısımları (sorgu sözcükleri; önek, alt dizgi ve küçük yazım hatası) işaretler. */
export function highlight(text: string, query: string): Segment[] {
  const tokens = tokenize(query);
  if (tokens.length === 0 || !text) return [{ text, hit: false }];
  const f = fold(text);
  const mark = new Array<boolean>(text.length).fill(false);
  // sözcük konumları
  const spans: { start: number; end: number }[] = [];
  const re = /\S+/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(f)) !== null) spans.push({ start: m.index, end: m.index + m[0].length });

  for (const q of tokens) {
    let done = false;
    // 1) sözcük başı eşleşmesi
    for (const sp of spans) {
      if (f.startsWith(q, sp.start)) {
        for (let i = sp.start; i < sp.start + q.length; i++) mark[i] = true;
        done = true;
        break;
      }
    }
    if (done) continue;
    // 2) alt dizgi
    if (q.length >= 3) {
      const idx = f.indexOf(q);
      if (idx >= 0) {
        for (let i = idx; i < idx + q.length; i++) mark[i] = true;
        continue;
      }
    }
    // 3) küçük yazım hatası: tüm sözcük ya da önek
    const tol = tolerance(q.length);
    if (tol === 0) continue;
    for (const sp of spans) {
      const word = f.slice(sp.start, sp.end);
      if (word.length < q.length - tol) continue;
      const full = editDistance(q, word, tol) <= tol;
      const pre = word.length > q.length && editDistance(q, word.slice(0, q.length), tol) <= tol;
      if (full || pre) {
        const end = full ? sp.end : sp.start + q.length;
        for (let i = sp.start; i < end; i++) mark[i] = true;
        break;
      }
    }
  }

  const out: Segment[] = [];
  let cur = '';
  let curHit = mark[0];
  for (let i = 0; i < text.length; i++) {
    if (mark[i] !== curHit) {
      out.push({ text: cur, hit: curHit });
      cur = '';
      curHit = mark[i];
    }
    cur += text[i];
  }
  out.push({ text: cur, hit: curHit });
  return out;
}
