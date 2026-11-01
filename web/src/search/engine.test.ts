import { describe, expect, it } from 'vitest';
import { createSearcher, groupHits, highlight, type Searchable } from './engine';
import { editDistance, fold, tokenize } from './fold';

const items: Searchable[] = [
  { id: 'page.settings', kind: 'page', title: 'Ayarlar', crumbs: ['Sistem'], keywords: ['yapılandırma', 'tercihler'] },
  {
    id: 'settings.maintenance_mode',
    kind: 'setting',
    title: 'Bakım modu',
    crumbs: ['Sistem', 'Ayarlar', 'Bakım modu'],
    keywords: ['bakıma al', 'siteyi kapat', 'geçici kapatma'],
    description: 'Açınca tüm kullanıcılar bakım mesajını görür.',
  },
  {
    id: 'settings.maintenance_message_tr',
    kind: 'setting',
    title: 'Bakım mesajı (Türkçe)',
    crumbs: ['Sistem', 'Ayarlar', 'Bakım modu'],
    keywords: ['bakım yazısı'],
  },
  { id: 'page.sources', kind: 'page', title: 'Kaynak durumu', crumbs: ['Sistem'], keywords: ['scraper', 'bakımda'] },
  { id: 'page.posts', kind: 'page', title: 'Gönderiler', crumbs: ['Moderasyon'], keywords: ['paylaşım', 'keşfet'] },
  { id: 'page.campaigns', kind: 'page', title: 'Kampanyalar', crumbs: ['Bildirimler'], keywords: ['duyuru gönder', 'push'] },
  { id: 'page.appeals', kind: 'page', title: 'İtirazlar', crumbs: ['Kullanıcılar'], keywords: ['şikayet kararı'] },
  { id: 'action.publish', kind: 'action', title: 'Yeni Android sürümünü yayınla', crumbs: ['Sistem', 'Uygulama güncelleme'] },
  { id: 'page.iskele', kind: 'page', title: 'IŞIK ve ığ', crumbs: [] },
];

const s = createSearcher(items);
const top = (q: string) => s.search(q)[0]?.item.id;
const ids = (q: string) => s.search(q).map((h) => h.item.id);

describe('Türkçe katlama', () => {
  it('İ/ı/I/i, ç ğ ö ş ü ve büyük/küçük harfi eşitler; uzunluk korunur', () => {
    expect(fold('İTİRAZLAR')).toBe('itirazlar');
    expect(fold('ISIK ığ')).toBe('isik ig');
    expect(fold('Çalışma Öğrenci Üye Şifre Ğ')).toBe('calisma ogrenci uye sifre g');
    for (const t of ['Bakım Modu', 'İĞÜŞÖÇ', 'a-b_c (d)']) expect(fold(t)).toHaveLength(t.length);
  });
  it('noktalama boşluk olur, sözcüklere bölünür', () => {
    expect(tokenize('Bakım-modu (TR)')).toEqual(['bakim', 'modu', 'tr']);
    expect(tokenize('   ')).toEqual([]);
  });
  it('aksansız/büyük harfli yazım aynı sonucu verir', () => {
    expect(top('bakim modu')).toBe('settings.maintenance_mode');
    expect(top('BAKIM MODU')).toBe('settings.maintenance_mode');
    expect(top('bakım modu')).toBe('settings.maintenance_mode');
    expect(top('itiraz')).toBe('page.appeals');
    expect(top('İTİRAZ')).toBe('page.appeals');
    expect(top('isik')).toBe('page.iskele');
  });
});

describe('düzenleme mesafesi', () => {
  it('bitişik harf yer değiştirmeyi 1 sayar, sınırı aşınca max+1 döner', () => {
    expect(editDistance('bakim', 'bakmi', 1)).toBe(1);
    expect(editDistance('bakim', 'bakin', 1)).toBe(1);
    expect(editDistance('bakim', 'bak', 1)).toBe(2);
    expect(editDistance('abc', 'abc', 1)).toBe(0);
  });
});

describe('eşleşme', () => {
  it('"bakım modu" ayar alanını en üste koyar (tam başlık)', () => {
    const r = ids('bakım modu');
    expect(r[0]).toBe('settings.maintenance_mode');
    expect(r).toContain('settings.maintenance_message_tr');
  });
  it('günlük dil anahtar kelimeleri bulur: "siteyi kapat", "bakıma al"', () => {
    expect(top('siteyi kapat')).toBe('settings.maintenance_mode');
    expect(top('bakıma al')).toBe('settings.maintenance_mode');
  });
  it('kelime öneki ve alt dizgi', () => {
    expect(top('baki')).toBeDefined();
    expect(ids('ayar')).toContain('page.settings');
    expect(ids('rlar')).toContain('page.settings'); // alt dizgi (>= 3 harf)
  });
  it('çok sözcük VE ile çalışır, sıra önemsiz', () => {
    expect(ids('modu bakım')[0]).toBe('settings.maintenance_mode');
    expect(ids('bakım zzzz')).toEqual([]);
    expect(ids('android yayınla')).toEqual(['action.publish']);
  });
  it('küçük yazım hatasını tolere eder (uzunluğa göre)', () => {
    expect(top('bakm modu')).toBe('settings.maintenance_mode');
    expect(top('bakim mdou')).toBe('settings.maintenance_mode');
    expect(top('kampayalar')).toBe('page.campaigns');
    expect(top('gonderlier')).toBe('page.posts');
  });
  it('kısa sözcüklerde yazım hatası payı yok', () => {
    expect(ids('xyz')).toEqual([]);
    expect(ids('pus')).toContain('page.campaigns'); // önek
    expect(ids('pux')).toEqual([]);
  });
  it('yalnız yazım hatasıyla eşleşenler, kesin eşleşme varsa gürültü olmaz ("gonderi" → "gönder")', () => {
    expect(ids('gonderi')).toEqual(['page.posts']);
  });
  it('boş sorgu sonuç vermez; filtre (RBAC) sonucu eler', () => {
    expect(s.search('')).toEqual([]);
    const r = s.search('bakım', { filter: (i) => i.id !== 'settings.maintenance_mode' });
    expect(r.map((h) => h.item.id)).not.toContain('settings.maintenance_mode');
  });
  it('sonuç sınırı uygulanır', () => {
    expect(s.search('a', { limit: 2 }).length).toBeLessThanOrEqual(2);
  });
});

describe('sıralama', () => {
  it('başlık > anahtar kelime > açıklama', () => {
    const x = createSearcher<Searchable>([
      { id: 'desc', kind: 'page', title: 'Başka', description: 'rapor burada geçer' },
      { id: 'kw', kind: 'page', title: 'Diğer', keywords: ['rapor'] },
      { id: 'title', kind: 'page', title: 'Rapor' },
    ]);
    expect(x.search('rapor').map((h) => h.item.id)).toEqual(['title', 'kw', 'desc']);
  });
  it('tam başlık eşleşmesi önek eşleşmesinden önce gelir', () => {
    const x = createSearcher<Searchable>([
      { id: 'a', kind: 'page', title: 'Kullanıcılar ve roller' },
      { id: 'b', kind: 'page', title: 'Kullanıcı' },
    ]);
    expect(x.search('kullanıcı')[0].item.id).toBe('b');
  });
  it('sayfa, aynı puanda ayardan önce gelir', () => {
    const x = createSearcher<Searchable>([
      { id: 'set', kind: 'setting', title: 'Duyuru' },
      { id: 'pg', kind: 'page', title: 'Duyuru' },
    ]);
    expect(x.search('duyuru')[0].item.id).toBe('pg');
  });
});

describe('gruplama', () => {
  it('Sayfalar / Ayarlar / Eylemler olarak ayırır ve en iyi puanlı grup üstte olur', () => {
    const g = groupHits(s.search('bakım'));
    const kinds = g.map((x) => x.cls);
    expect(kinds[0]).toBe('settings'); // "Bakım modu" ayarı en iyi
    expect(kinds).toContain('pages');
    const g2 = groupHits(s.search('sürüm'));
    expect(g2.map((x) => x.cls)).toEqual(['actions']);
  });
  it('grup başına sınır uygular', () => {
    const many = createSearcher<Searchable>(
      Array.from({ length: 30 }, (_, i) => ({ id: `s${i}`, kind: 'setting' as const, title: `Ayar ${i}` })),
    );
    expect(groupHits(many.search('ayar'), 5)[0].hits).toHaveLength(5);
  });
});

describe('öneri (Şunu mu aradınız?)', () => {
  it('yazım hatalı sorguyu düzeltir', () => {
    expect(s.suggest('bakim mdu')).toBe('bakım modu');
    expect(s.suggest('kampnya')).toBe('kampanyalar');
  });
  it('anlamsız sorguda null', () => {
    expect(s.suggest('qqqqqq')).toBeNull();
  });
  it('doğru yazılmış ama eşleşmeyen sözcüğü atar', () => {
    expect(s.suggest('bakım qqqqqq')).toBe('bakım');
  });
});

describe('gövde (ek soyma)', () => {
  const x = createSearcher<Searchable>([
    { id: 'msg', kind: 'page', title: 'Mesaj erişim kayıtları', crumbs: ['Sistem'] },
    { id: 'club', kind: 'page', title: 'Kulüp denetimi', crumbs: ['Topluluk'] },
    { id: 'user', kind: 'page', title: 'Kullanıcılar', crumbs: ['Kullanıcılar'] },
  ]);
  it('çekim eki almış sorgu, başlıktaki kökü bulur', () => {
    expect(x.search('mesajlar')[0]?.item.id).toBe('msg');
    expect(x.search('mesajlarından')[0]?.item.id).toBe('msg');
    expect(x.search('kulüpte')[0]?.item.id).toBe('club');
    expect(x.search('kullanıcıların')[0]?.item.id).toBe('user');
  });
  it('ek soyma yazım hatasıyla birlikte de çalışır ("mesjalar")', () => {
    expect(x.search('mesjalar')[0]?.item.id).toBe('msg');
    expect(x.search('meaj')[0]?.item.id).toBe('msg');
  });
});

describe('eş anlamlılar ve ilgili kavramlar', () => {
  const x = createSearcher<Searchable>([
    { id: 'chat', kind: 'page', title: 'Sohbet akışı', crumbs: ['Moderasyon'] },
    { id: 'access', kind: 'page', title: 'Mesaj erişim kayıtları', crumbs: ['Sistem'] },
    { id: 'camp', kind: 'page', title: 'Kampanyalar', crumbs: ['Bildirimler'] },
    { id: 'ann', kind: 'page', title: 'Duyurular', crumbs: ['Akademik'] },
    { id: 'users', kind: 'page', title: 'Üyeler', crumbs: ['Kullanıcılar'] },
    { id: 'banner', kind: 'setting', title: 'Duyuru bandı', crumbs: ['Ayarlar'] },
    { id: 'block', kind: 'page', title: 'Erişim engelleri', crumbs: ['Kullanıcılar'] },
  ]);
  const order = (q: string) => x.search(q).map((h) => h.item.id);

  it('"mesaj" sohbet ve yazışma sayfalarını da getirir; doğrudan eşleşme önde', () => {
    const r = order('mesaj');
    expect(r.slice(0, 2).sort()).toEqual(['access', 'chat']);
    expect(order('dm')).toContain('chat');
    expect(order('yazışma')).toContain('chat');
    expect(order('sohbet')).toContain('access');
  });
  it('ilgili (zayıf) kavramlar: "mesaj" kampanya ve duyuruyu da listeler ama sona koyar', () => {
    const r = order('mesaj');
    expect(r).toContain('camp');
    expect(r).toContain('ann');
    expect(r.indexOf('chat')).toBeLessThan(r.indexOf('camp'));
    expect(r.indexOf('access')).toBeLessThan(r.indexOf('ann'));
  });
  it('yazım hatalı eş anlamlı da genişler', () => {
    expect(order('meaj')).toContain('chat');
    expect(order('sohbte')).toContain('access');
  });
  it('"kullanıcı" ↔ "üye"', () => {
    expect(order('kullanıcı')).toContain('users');
    expect(order('uye')).toContain('users');
  });
  it('kısa sözcükler yalnız tam eşleşir ("ban" bandı değil engeli getirir)', () => {
    const r = order('ban');
    expect(r).toContain('block');
    expect(r).not.toContain('banner');
  });
  it('çok sözcüklü sorguda her sözcük genişler (VE)', () => {
    expect(order('üye mesajı')).toEqual([]); // üye ve mesaj birlikte geçen sayfa yok
    const y = createSearcher<Searchable>([{ id: 'um', kind: 'section', title: 'Kullanıcı mesajlarını görüntüle' }]);
    expect(y.search('üye yazışma').map((h) => h.item.id)).toEqual(['um']);
  });
  it('e-posta gibi tek harfli parçalar sorguyu bozmaz', () => {
    const y = createSearcher<Searchable>([
      { id: 'p', kind: 'page', title: 'Posta kuyruğu' },
      { id: 'z', kind: 'page', title: 'Elma' },
    ]);
    expect(y.search('e-posta').map((h) => h.item.id)).toEqual(['p']);
  });
});

describe('eşleşme kaynağı (via)', () => {
  it('başlıkta görünmeyen eşleşme, eşleşen anahtar kelimeyi bildirir', () => {
    const x = createSearcher<Searchable>([
      { id: 'a', kind: 'page', title: 'Karar şablonları', keywords: ['hazır cevap'] },
      { id: 'b', kind: 'page', title: 'Hazır cevaplar' },
    ]);
    const hits = x.search('hazır cevap');
    const a = hits.find((h) => h.item.id === 'a');
    const b = hits.find((h) => h.item.id === 'b');
    expect(a?.via).toBe('hazır cevap');
    expect(b?.via).toBeUndefined();
  });
});

describe('vurgulama', () => {
  it('ek almış sorguda kökü işaretler', () => {
    expect(highlight('Mesaj erişim kayıtları', 'mesajlar')[0]).toEqual({ text: 'Mesaj', hit: true });
  });
  it('eşleşen kısımları özgün harflerle işaretler', () => {
    const seg = highlight('Bakım modu', 'bakim');
    expect(seg[0]).toEqual({ text: 'Bakım', hit: true });
    expect(seg.map((x) => x.text).join('')).toBe('Bakım modu');
  });
  it('yazım hatalı sözcüğü ve alt dizgiyi de işaretler', () => {
    expect(highlight('Kampanyalar', 'kampayalar').some((x) => x.hit)).toBe(true);
    expect(highlight('Gönderiler', 'deril')).toEqual([
      { text: 'Gön', hit: false },
      { text: 'deril', hit: true },
      { text: 'er', hit: false },
    ]);
  });
  it('eşleşme yoksa tek parça döner', () => {
    expect(highlight('Ayarlar', 'zzz')).toEqual([{ text: 'Ayarlar', hit: false }]);
  });
});

describe('başarım', () => {
  it('1500 girdide sorgu başına birkaç ms', () => {
    const words = ['bakım', 'modu', 'kullanıcı', 'rapor', 'bildirim', 'sürüm', 'yedek', 'mesaj', 'etkinlik', 'kulüp', 'ayar', 'filtre', 'tablo', 'dışa', 'aktar'];
    const big: Searchable[] = Array.from({ length: 1500 }, (_, i) => ({
      id: `e${i}`,
      kind: (['page', 'setting', 'field', 'action', 'section'] as const)[i % 5],
      title: `${words[i % words.length]} ${words[(i * 7) % words.length]} ${i}`,
      keywords: [words[(i * 3) % words.length], `${words[(i * 5) % words.length]} ${words[(i * 11) % words.length]}`],
      description: `${words[(i * 2) % words.length]} ile ilgili açıklama metni ${words[(i * 13) % words.length]}`,
      crumbs: ['Sistem', words[i % 4]],
    }));
    const t0 = performance.now();
    const big$ = createSearcher(big);
    const build = performance.now() - t0;
    // ısınma + ölçüm: her sorgu 5 kez, en iyi süre alınır (paylaşılan CI/geliştirme makinesindeki gürültüyü eler)
    for (const q of ['bakim', 'rapr', 'zzzzzz']) big$.search(q);
    const runs: number[] = [];
    for (const q of ['bakim modu', 'kullnıcı rapor', 'zzzzzzzz', 'sürüm yedk']) {
      let best = Infinity;
      for (let k = 0; k < 5; k++) {
        const a = performance.now();
        big$.search(q);
        best = Math.min(best, performance.now() - a);
      }
      runs.push(best);
    }
    // hedef < 10 ms (yük altında dahi tipik 2-6 ms); eşik gürültüye karşı gevşektir
    expect(Math.max(...runs), `build=${build.toFixed(1)}ms best-of-5=${runs.map((r) => r.toFixed(1)).join(',')}`).toBeLessThan(30);
  });
});
