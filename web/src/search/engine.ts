/**
 * Arama motoru (saf TypeScript, React'siz). Dizin bir kez sadeleştirilir (createSearcher); sorgu başına yalnız
 * sözcük karşılaştırması yapılır (1000+ girdide birkaç ms).
 *
 * Eşleşme: her sorgu sözcüğü bir alanda tam / önek / alt dizgi / küçük yazım hatası (Damerau-Levenshtein) ile bulunmalı
 * (çok sözcük = VE). Ağırlık: başlık > anahtar kelime > açıklama > kırıntı. Tam başlık/anahtar kelime eşleşmesi en üstte.
 */
import { editDistance, fold, stems, tokenize, tolerance, words } from './fold';
import { groupMembers, groupsFor, relatedFor, type Alt } from './synonyms';
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
  /** Başlıkta görünmeyen eşleşmenin kaynağı (anahtar kelime / eş anlamlı): "Eşleşen: sohbet". Başlık eşleştiyse yoktur. */
  via?: string;
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
  /** Özgün anahtar kelime metinleri (`via` gösterimi için; keywords ile aynı sırada). */
  keywordTexts: string[];
  description: Field;
  crumbs: Field;
  boost: number;
  /** Tüm alanların birleşik sadeleşmiş metni + sözcük kümesi: alanlara bakmadan hızlı eleme için. */
  blob: string;
  wordSet: Set<string>;
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

/** Tür çarpanı: aynı metin eşleşmesinde sayfa > bölüm > ayar > eylem > alan/süzgeç. */
const KIND_BOOST: Record<SearchKind, number> = { page: 1.25, section: 1.05, setting: 1, action: 0.95, field: 0.85 };

/** Gövde (ek soyulmuş) ve eş anlamlı/ilgili sözcük çarpanları. */
const F_STEM = 0.85;
const F_SYNONYM = 0.8;
const F_RELATED = 0.5;

/** Çok sözcüklü sorguda tek harfli parçalar ("e-posta" → e, posta) gürültüdür: atılır (tek başına yazılmışsa korunur). */
function significant(tokens: string[]): string[] {
  const long = tokens.filter((t) => t.length > 1);
  return long.length > 0 ? long : tokens;
}

function anyIn(map: Map<string, number>, set: Set<string>): boolean {
  for (const w of map.keys()) if (set.has(w)) return true;
  return false;
}

/** Sorgu sözcüğünün arama biçimleri: özgün + gövdeler + eş anlamlılar + ilgili kavramlar. */
function buildAlts(token: string): Alt[] {
  const alts = new Map<string, Alt>();
  const put = (a: Alt) => {
    const e = alts.get(a.q);
    if (!e || e.factor < a.factor) alts.set(a.q, a);
  };
  put({ q: token, factor: 1, fuzzy: true, exactOnly: false });
  const st = stems(token);
  for (const s of st) {
    // tek harf soyulan gövde ("gönderi" → "gönder") belirsizdir: zayıf biçim
    const weak = token.length - s.length <= 1;
    put({ q: s, factor: weak ? 0.6 : F_STEM, fuzzy: s.length >= 4, exactOnly: false, soft: weak, noSub: true });
  }
  const corrected = new Map<string, number>();
  const gs = groupsFor(token, st, editDistance, corrected);
  // kısa ve sözlükte bilinen sözcük ("ban", "log", "dm") yalnız tam eşleşir: "ban" → "bant/banner" gürültüsü olmaz
  if (token.length <= 3 && gs.size > 0) alts.set(token, { q: token, factor: 1, fuzzy: false, exactOnly: true });
  // yarım yazılmış / yazım hatalı sözcük sözlükteki sözcüğe çevrilir ("meaj" → "mesaj"): neredeyse özgün sözcük kadar güçlü
  for (const [w, conf] of corrected) put({ q: w, factor: conf, fuzzy: false, exactOnly: w.length <= 3, noSub: true });
  for (const [gi, conf] of gs) {
    for (const m of groupMembers(gi)) put({ q: m, factor: F_SYNONYM * conf, fuzzy: false, exactOnly: m.length <= 3, noSub: true });
  }
  for (const r of relatedFor(gs.keys())) put({ q: r, factor: F_RELATED, fuzzy: false, exactOnly: r.length <= 3, noSub: true });
  return [...alts.values()];
}

function field(text: string): Field {
  const ws = words(fold(text));
  return { text: ws.join(' '), words: ws };
}

/** Tek sorgu sözcüğünün bir alandaki en iyi puanı (0 = eşleşmedi). `fz`: sözlükte yazım hatası payı içindeki sözcükler → mesafe. */
function scoreToken(q: string, f: Field, w: Weights, fz: Map<string, number> | null, exactOnly = false, noSub = false): number {
  if (f.words.length === 0) return 0;
  let best = 0;
  const qlen = q.length;
  for (const word of f.words) {
    if (word === q) return w.exact;
    if (exactOnly) continue;
    if (word.startsWith(q)) {
      // kısa sözcük (daha çok yazılmış kısmı kapsayan) biraz önde
      const s = w.prefix - Math.min(8, (word.length - qlen) * 0.6);
      if (s > best) best = s;
    }
  }
  if (best > 0 || exactOnly) return best;
  if (qlen >= 3 && !noSub && f.text.includes(q)) return w.sub;
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
  const docs: Doc<T>[] = items.map((item) => {
    const title = field(item.title);
    const keywords = (item.keywords ?? []).map(field);
    const description = field(item.description ?? '');
    const crumbs = field((item.crumbs ?? []).join(' '));
    const all = [title, ...keywords, description, crumbs];
    return {
      item,
      title,
      keywords,
      keywordTexts: item.keywords ?? [],
      description,
      crumbs,
      boost: KIND_BOOST[item.kind],
      blob: all.map((f) => f.text).join(' '),
      wordSet: new Set(all.flatMap((f) => f.words)),
    };
  });

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
    if (fzCache.size > 1000) fzCache.clear();
    fzCache.set(q, out);
    return out;
  }

  /** Sorgu sözcüğü başına arama biçimleri ve her biri için yazım hatası sözlüğü (sorgu başına bir kez). */
  interface TokenPlan {
    alts: { alt: Alt; fz: Map<string, number> | null }[];
  }
  const altCache = new Map<string, Alt[]>();
  function planFor(token: string): TokenPlan {
    let alts = altCache.get(token);
    if (!alts) {
      alts = buildAlts(token);
      if (altCache.size > 200) altCache.clear();
      altCache.set(token, alts);
    }
    return { alts: alts.map((alt) => ({ alt, fz: alt.fuzzy ? fuzzyWords(alt.q) : null })) };
  }

  function scoreDoc(d: Doc<T>, plans: TokenPlan[], tokens: string[], phrase: string): { score: number; soft: boolean; via?: string } | null {
    let total = 0;
    let allFuzzy = true;
    let allTitle = true;
    let via: string | undefined;
    for (const plan of plans) {
      let s = 0;
      let fuzzy = false;
      let src = 0; // 1 başlık, 2 anahtar kelime, 3 açıklama/kırıntı
      let kwi = -1;
      let bestFac = 1;
      // yazım hatası eşleşmeleri her zaman ilgili alanın `fuzzy` ağırlığını aşmaz; kesin eşleşmeler aşar
      for (const { alt, fz } of plan.alts) {
        const fac = alt.factor;
        // bu biçim en iyi olsa bile mevcut puanı geçemezse alanlara bakılmaz
        if (s >= W_TITLE.exact) break;
        // hızlı eleme: belgenin hiçbir alanında bu biçim (ya da yazım hatası karşılığı) geçmiyorsa alanlara bakma
        if (!d.blob.includes(alt.q) && !(fz && anyIn(fz, d.wordSet))) continue;
        const rawT = scoreToken(alt.q, d.title, W_TITLE, fz, alt.exactOnly, alt.noSub);
        if (rawT * fac > s) {
          s = rawT * fac;
          src = 1;
          bestFac = fac;
          fuzzy = rawT <= W_TITLE.fuzzy || alt.soft === true;
        }
        if (W_KEYWORD.exact * fac > s) {
          for (let ki = 0; ki < d.keywords.length; ki++) {
            const raw = scoreToken(alt.q, d.keywords[ki], W_KEYWORD, fz, alt.exactOnly, alt.noSub);
            if (raw * fac > s) {
              s = raw * fac;
              src = 2;
              bestFac = fac;
              kwi = ki;
              fuzzy = raw <= W_KEYWORD.fuzzy || alt.soft === true;
            }
          }
        }
        if (W_CRUMB.exact * fac > s) {
          const raw = scoreToken(alt.q, d.description, W_DESC, fz, alt.exactOnly, alt.noSub);
          if (raw * fac > s) {
            s = raw * fac;
            src = 3;
            bestFac = fac;
            fuzzy = raw <= W_DESC.fuzzy || alt.soft === true;
          }
          const rawC = scoreToken(alt.q, d.crumbs, W_CRUMB, fz, alt.exactOnly, alt.noSub);
          if (rawC * fac > s) {
            s = rawC * fac;
            src = 3;
            bestFac = fac;
            fuzzy = rawC <= W_CRUMB.fuzzy || alt.soft === true;
          }
        }
      }
      if (s <= 0) return null; // VE: her sözcük bulunmalı
      if (!fuzzy) allFuzzy = false;
      if (src !== 1 || bestFac < F_SYNONYM) allTitle = false;
      if (src === 2 && via === undefined) via = d.keywordTexts[kwi];
      total += s;
    }
    let score = total / plans.length;
    // tüm cümlenin eşleşmesi (sözcük sırası önemli)
    if (d.title.text.trim() === phrase) score += 300;
    else if (d.title.text.startsWith(phrase)) score += 90;
    else if (tokens.length > 1 && d.title.text.includes(phrase)) score += 60;
    // tam anahtar kelime eşleşmesi: başlık eşleşmesinin ardında, açıklama/kırıntıdan önce
    let kwBonus = 0;
    for (const k of d.keywords) {
      const kt = k.text.trim();
      if (kt === phrase) kwBonus = Math.max(kwBonus, 100);
      else if (kt.startsWith(phrase)) kwBonus = Math.max(kwBonus, 50);
      else if (tokens.length > 1 && kt.includes(phrase)) kwBonus = Math.max(kwBonus, 35);
    }
    score += kwBonus;
    // her sözcük başlıkta bulunuyorsa: "mesaj" için başlığında mesaj geçen sayfa, yalnız anahtar kelimesi olandan önde
    if (allTitle) score += 40;
    return { score: (score - d.title.text.length * 0.1) * d.boost, soft: allFuzzy, via: allTitle ? undefined : via };
  }

  function search(query: string, opts: SearchOptions<T> = {}): Hit<T>[] {
    const tokens = significant(tokenize(query));
    if (tokens.length === 0) return [];
    const phrase = tokens.join(' ');
    const plans = tokens.map(planFor);
    const limit = opts.limit ?? 60;
    const hits: Hit<T>[] = [];
    const soft: Hit<T>[] = [];
    for (const d of docs) {
      if (opts.filter && !opts.filter(d.item)) continue;
      const r = scoreDoc(d, plans, tokens, phrase);
      if (!r) continue;
      const hit: Hit<T> = { item: d.item, score: r.score };
      if (r.via) hit.via = r.via;
      if (r.soft) soft.push(hit);
      else hits.push(hit);
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

  /** Tek biçimi (sözcük ya da gövde) metinde işaretler; işaretlediyse true. */
  const markOne = (q: string): boolean => {
    // 1) sözcük başı eşleşmesi
    for (const sp of spans) {
      if (f.startsWith(q, sp.start)) {
        for (let i = sp.start; i < sp.start + q.length; i++) mark[i] = true;
        return true;
      }
    }
    // 2) alt dizgi
    if (q.length >= 3) {
      const idx = f.indexOf(q);
      if (idx >= 0) {
        for (let i = idx; i < idx + q.length; i++) mark[i] = true;
        return true;
      }
    }
    // 3) küçük yazım hatası: tüm sözcük ya da önek
    const tol = tolerance(q.length);
    if (tol === 0) return false;
    for (const sp of spans) {
      const word = f.slice(sp.start, sp.end);
      if (word.length < q.length - tol) continue;
      const full = editDistance(q, word, tol) <= tol;
      const pre = word.length > q.length && editDistance(q, word.slice(0, q.length), tol) <= tol;
      if (full || pre) {
        const end = full ? sp.end : sp.start + q.length;
        for (let i = sp.start; i < end; i++) mark[i] = true;
        return true;
      }
    }
    return false;
  };

  // önce yazılan biçim, olmazsa gövdeleri ("mesajlar" → "Mesaj erişim kayıtları" içindeki "Mesaj")
  for (const q of tokens) {
    if (markOne(q)) continue;
    for (const s of stems(q)) if (markOne(s)) break;
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
