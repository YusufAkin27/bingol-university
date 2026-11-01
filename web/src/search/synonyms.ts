/**
 * Eş anlamlılar ve ilgili kavramlar (arama motoru genişletmesi). Sözcükler SADELEŞMİŞ biçimde yazılır (fold: ı→i, ş→s ...),
 * tek sözcüktür (çok sözcüklü kalıp için sayfa girdisinin `keywords` alanı kullanılır).
 *
 *  - SYNONYM_GROUPS: birbirinin yerine geçen sözcükler. Gruptan biri sorulunca hepsi aranır (puan ×0,8).
 *  - RELATED: tek yönlü, zayıf ilişki ("mesaj" → duyuru, kampanya...). Hedefler daha düşük puanla (×0,5) listelenir:
 *    "mesaj" yazan yönetici kampanya/duyuru gibi mesaj içeren sayfaları da görsün, ama doğrudan eşleşmelerin ardından.
 *
 * Bir sayfa girdisine özgü söyleyişler hâlâ girdinin `keywords` alanına yazılır; burası YAYGIN, panel genelinde geçerli sözlüktür.
 */
export const SYNONYM_GROUPS: readonly (readonly string[])[] = [
  ['mesaj', 'sohbet', 'yazisma', 'dm', 'ileti', 'konusma', 'mesajlasma', 'chat', 'mesajlar'],
  ['kullanici', 'uye', 'ogrenci', 'hesap', 'kisi', 'personel'],
  ['sikayet', 'ihbar', 'rapor', 'sikayetler'],
  ['engel', 'engelle', 'yasak', 'yasakla', 'ban', 'blok', 'engelleme'],
  ['sil', 'kaldir', 'cikar', 'silme'],
  ['mail', 'eposta', 'posta', 'email', 'mektup'],
  ['kulup', 'topluluk'],
  ['bildirim', 'push', 'anlik', 'notification'],
  ['duyuru', 'ilan', 'anons'],
  ['yedek', 'yedekleme', 'backup'],
  ['sifre', 'parola', 'password'],
  ['giris', 'login', 'oturum'],
  ['etkinlik', 'event', 'organizasyon'],
  ['yemek', 'menu', 'yemekhane', 'kafeterya'],
  ['destek', 'yardim', 'talep', 'ticket', 'sorun'],
  ['ayar', 'tercih', 'yapilandirma', 'konfigurasyon', 'ayarlar'],
  ['gonderi', 'paylasim', 'post'],
  ['anket', 'oylama', 'poll', 'oy'],
  ['istatistik', 'analitik', 'grafik', 'metrik', 'analiz'],
  ['cokme', 'crash', 'hata', 'cokus'],
  ['log', 'gunluk', 'denetim', 'audit'],
  ['surum', 'versiyon', 'guncelleme', 'update', 'release'],
  ['yonetici', 'admin', 'moderator'],
  ['sozlesme', 'kosul', 'gizlilik', 'kvkk', 'politika'],
  ['gorsel', 'resim', 'foto', 'fotograf', 'medya', 'image'],
  ['dogrulama', 'verify'],
  ['askiya', 'dondur', 'uzaklastir', 'suspend'],
  ['itiraz', 'appeal'],
  ['kampanya', 'broadcast'],
  ['haber', 'gazete', 'news'],
  ['takvim', 'akademik', 'donem'],
  ['sinav', 'vize', 'final', 'butunleme'],
  ['sertifika', 'belge'],
  ['yoklama', 'qr', 'katilim', 'devam'],
  ['filtre', 'suzgec'],
  ['indir', 'disa', 'export', 'csv', 'aktar'],
  ['sifreleme', 'sifrele', 'anahtar', 'encrypt'],
];

/** Tek yönlü zayıf ilişkiler: sol taraftaki sözcük (veya grubu) sorulunca sağdakiler de düşük puanla aranır. */
export const RELATED: readonly { from: readonly string[]; to: readonly string[] }[] = [
  { from: ['mesaj'], to: ['duyuru', 'kampanya', 'bildirim', 'posta', 'destek', 'yanit', 'sablon'] },
  { from: ['kullanici'], to: ['profil', 'rol', 'cihaz'] },
  { from: ['sikayet'], to: ['itiraz', 'engel', 'moderasyon'] },
  { from: ['bildirim'], to: ['kampanya', 'duyuru', 'mesaj', 'cihaz'] },
  { from: ['destek'], to: ['mesaj', 'sss', 'geri'] },
  { from: ['etkinlik'], to: ['kulup', 'yoklama', 'sertifika'] },
  { from: ['yedek'], to: ['surucu', 'drive', 'veri'] },
];

export interface Alt {
  /** Aranan sadeleşmiş sözcük. */
  q: string;
  /** Puan çarpanı (özgün sözcük = 1). */
  factor: number;
  /** Yazım hatası (bulanık) eşleşmesi denensin mi. */
  fuzzy: boolean;
  /** Yalnız tam sözcük eşleşmesi (kısa eş anlamlılar "ban" → "banner" gibi önek gürültüsü yapmasın). */
  exactOnly: boolean;
  /** Zayıf biçim: kesin eşleşme varsa bu biçimin tek başına getirdiği sonuçlar geri çekilir ("gönderi" → "gönder" gürültüsü). */
  soft?: boolean;
  /** Alt dizgi eşleşmesi kapalı (eş anlamlı "kisi" → "akışı" gürültüsü olmasın). */
  noSub?: boolean;
}

const groupsOf = new Map<string, number[]>();
SYNONYM_GROUPS.forEach((g, i) => {
  for (const w of g) {
    const list = groupsOf.get(w);
    if (list) list.push(i);
    else groupsOf.set(w, [i]);
  }
});
const vocabulary = [...groupsOf.keys()];

/** Bir sorgu sözcüğünün (ya da gövdelerinin) üyesi olduğu eş anlamlı gruplar; yarım yazılmış ve küçük hatalı sözcükleri de yakalar. */
export function groupsFor(
  token: string,
  stemList: readonly string[],
  dist: (a: string, b: string, max: number) => number,
  corrected?: Map<string, number>,
): Map<number, number> {
  // grup → eşleşme güveni (1 tam, 0,85 yarım yazılmış, 0,75 yazım hatalı)
  const found = new Map<number, number>();
  const add = (word: string, conf: number) => {
    for (const g of groupsOf.get(word) ?? []) if ((found.get(g) ?? 0) < conf) found.set(g, conf);
  };
  for (const cand of [token, ...stemList]) {
    if (groupsOf.has(cand)) add(cand, cand === token ? 1 : 0.95);
  }
  if (found.size > 0) return found;
  for (const cand of [token, ...stemList]) {
    if (cand.length < 4) continue;
    const tol = cand.length <= 7 ? 1 : 2;
    for (const w of vocabulary) {
      if (w.length < 4) continue;
      if (w.startsWith(cand)) {
        add(w, 0.85);
        corrected?.set(w, Math.max(corrected.get(w) ?? 0, 0.95));
      }
      else if (dist(cand, w, tol) <= tol) {
        add(w, 0.75);
        corrected?.set(w, Math.max(corrected.get(w) ?? 0, 0.88));
      }
    }
  }
  return found;
}

/** İlgili (zayıf) sözcükler: eş anlamlı grup üyelerinden biri ilişkinin sol tarafındaysa. */
export function relatedFor(groupIdx: Iterable<number>): string[] {
  const out: string[] = [];
  for (const gi of groupIdx) {
    const members = SYNONYM_GROUPS[gi];
    for (const r of RELATED) if (r.from.some((f) => members.includes(f))) out.push(...r.to);
  }
  return out;
}

export function groupMembers(gi: number): readonly string[] {
  return SYNONYM_GROUPS[gi];
}
