/**
 * Yonetim paneli icerik/moderasyon sayfalari: raporlar, destek, geri bildirim, sozlesmeler, SSS, haber.
 *
 *   cd web && E2E_PORT=5193 E2E_ADMIN_EMAIL=admin3@bingol.edu.tr npx playwright test admin-content.spec.ts
 *   (gorsel dogrulama icin ek olarak E2E_SHOTS=1: ekran goruntuleri e2e/.results/shots/ altina yazilir)
 *
 * Veri: "E2E-content-" onekli; kullanici tarafi admin1@bingol.edu.tr hesabiyla API'den uretilir.
 * Giris hiz siniri nedeniyle her hesap dosya basina BIR kez giris yapar. Sozlesme yayini MOCK'lanir (gercek metne dokunulmaz).
 */
import { expect, request as pwRequest, test, type APIRequestContext, type Page } from '@playwright/test';
import { ADMIN_PASSWORD, apiLogin, type Tokens } from './helpers';

const BACKEND = process.env.VITE_DEV_BACKEND || 'http://localhost:8080';
const ADMIN_EMAIL = process.env.E2E_ADMIN_EMAIL || 'admin3@bingol.edu.tr';
const USER_EMAIL = process.env.E2E_USER_EMAIL || 'admin1@bingol.edu.tr';
const PREFIX = `E2E-content-${Date.now().toString(36)}`;

let api: APIRequestContext;
let admin: Tokens;
let user: Tokens;

const auth = (t: Tokens) => ({ Authorization: `Bearer ${t.accessToken}` });

async function adminGet<T>(path: string): Promise<T> {
  const r = await api.get(`/api${path}`, { headers: auth(admin) });
  if (!r.ok()) throw new Error(`GET ${path} -> ${r.status()}`);
  return (await r.json()) as T;
}
async function userPost<T>(path: string, data: unknown): Promise<{ status: number; body: T }> {
  const r = await api.post(`/api${path}`, { headers: auth(user), data });
  const text = await r.text();
  return { status: r.status(), body: (text ? JSON.parse(text) : null) as T };
}

test.beforeAll(async () => {
  api = await pwRequest.newContext({ baseURL: BACKEND });
  admin = await apiLogin(api, ADMIN_EMAIL, ADMIN_PASSWORD);
  user = await apiLogin(api, USER_EMAIL, ADMIN_PASSWORD);
});
test.afterAll(async () => {
  await api.dispose();
});

async function openAs(page: Page, lang: 'tr' | 'en' | 'ar' = 'tr', theme: 'light' | 'dark' = 'light') {
  // Vite proxy'si Origin basligini oldugu gibi iletir; backend yalnizca CORS_ORIGINS'teki kokenleri kabul eder
  // (varsayilan 5173/3000). Yazma isteklerinde 403 "Invalid CORS request" almamak icin izinli bir koken bildirilir.
  await page.route('**/api/**', (route) => {
    const h = route.request().headers();
    if (h.origin) return route.continue({ headers: { ...h, origin: 'http://localhost:5173' } });
    return route.continue();
  });
  await page.addInitScript(
    ([a, r, l, th]) => {
      sessionStorage.setItem('bu.admin.access', a);
      sessionStorage.setItem('bu.admin.refresh', r);
      localStorage.setItem('bu.lang', l);
      localStorage.setItem('bu.theme', th);
    },
    [admin.accessToken, admin.refreshToken, lang, theme],
  );
}

/** Imeç tabanlı listede "Daha fazla yükle" ile aranan öğe görünene dek ilerler. */
async function revealWithLoadMore(page: Page, locator: ReturnType<Page['locator']>) {
  for (let i = 0; i < 15; i++) {
    if (await locator.first().isVisible().catch(() => false)) return;
    const more = page.getByRole('button', { name: 'Daha fazla yükle' });
    if (!(await more.isVisible().catch(() => false))) break;
    await more.click();
    await page.waitForTimeout(300);
  }
}

async function createTicket(subject: string): Promise<number> {
  const r = await userPost<{ ticket: { id: number } }>('/support/tickets', {
    category: 'TECHNICAL',
    subject,
    message: 'Uygulamaya giriş yaparken hata alıyorum. Lütfen yardımcı olun. (E2E)',
  });
  expect(r.status).toBeLessThan(300);
  return r.body.ticket.id;
}

test.describe.configure({ mode: 'serial' });

test.describe('raporlar', () => {
  test('rapor olustur -> kuyrukta gor -> DISMISS', async ({ page }) => {
    // Açık raporu olmayan bir hedef kullanıcı seç (başka ajanların verisine dokunma)
    const open = await adminGet<{ items: { targetType: string; targetId: number }[] }>('/admin/reports?status=OPEN&size=100');
    const busy = new Set(open.items.filter((i) => i.targetType === 'USER').map((i) => i.targetId));
    const candidates = await adminGet<{ items: { id: number; email: string }[] }>('/admin/users?q=admin&size=50');
    const me = await adminGet<{ id: number }>('/admin/me');
    const target = candidates.items.find((u) => /^admin[24]@/.test(u.email) && !busy.has(u.id) && u.id !== me.id);
    test.skip(!target, 'açık raporu olmayan hedef kullanıcı yok');

    const note = `${PREFIX}-rapor`;
    const res = await userPost('/reports', { targetType: 'USER', targetId: target!.id, reason: 'SPAM', note });
    expect(res.status).toBeLessThan(300);

    await openAs(page);
    await page.goto('/admin/reports');
    const card = page.locator('button[id^="report-"]', { hasText: note });
    await revealWithLoadMore(page, card);
    await expect(card).toBeVisible();
    await card.click();
    await expect(page.getByText(target!.email, { exact: false }).first()).toBeVisible(); // hedef önizleme
    await page.getByRole('radio', { name: /Reddet/ }).click();
    await page.getByRole('button', { name: 'Kararı uygula' }).click();
    const dialog = page.getByRole('dialog');
    await expect(dialog).toContainText('Aynı hedefe ait tüm açık raporlar');
    await dialog.getByRole('button', { name: 'Reddet' }).click();
    await expect(page.getByText('Rapor çözüldü: Reddet')).toBeVisible();
    await expect(card).toHaveCount(0);

    const resolved = await adminGet<{ items: { note: string | null; resolution: string }[] }>('/admin/reports?status=RESOLVED&size=100');
    // en eski önce sıralandığından yeni karar son sayfada olabilir: durum çözülmüş sayısı yeterli kanıt değilse API'den ara
    const found = resolved.items.some((i) => i.note === note);
    if (!found) {
      await page.getByRole('tab', { name: 'Çözüldü' }).click();
      const done = page.locator('button[id^="report-"]', { hasText: note });
      await revealWithLoadMore(page, done);
      await expect(done).toBeVisible();
    }
  });
});

test.describe('destek talebi', () => {
  test('talep ac -> yanitla -> kullanici tarafinda dogrula -> kapat', async ({ page }) => {
    const subject = `${PREFIX}-talep`;
    const id = await createTicket(subject);
    await openAs(page);
    await page.goto('/admin/support/tickets');
    const row = page.getByRole('row', { name: new RegExp(subject) });
    await revealWithLoadMore(page, row);
    await expect(row).toBeVisible();
    await expect(row).toContainText('Yanıt bekliyor');
    await expect(row).toContainText(USER_EMAIL);
    await row.click();
    await expect(page).toHaveURL(new RegExp(`/admin/support/tickets/${id}$`));
    await expect(page.getByText('Uygulamaya giriş yaparken')).toBeVisible();

    const reply = `Merhaba, ${PREFIX} yanıtı: lütfen uygulamayı güncelleyin.`;
    await page.getByLabel('Yanıtınız').fill(reply);
    await expect(page.getByText(`${reply.length} / 2000`)).toBeVisible();
    await page.getByLabel('Yanıtınız').press('Control+Enter');
    await expect(page.getByText('Yanıt gönderildi.')).toBeVisible();
    await expect(page.getByText('Yanıtlandı').first()).toBeVisible();
    await expect(page.getByText(reply)).toBeVisible();

    const mine = await (await api.get(`/api/support/tickets/${id}`, { headers: auth(user) })).json();
    expect(mine.ticket.status).toBe('ANSWERED');
    expect(mine.messages.some((m: { fromStaff: boolean; text: string }) => m.fromStaff && m.text === reply)).toBe(true);

    await page.getByRole('button', { name: 'Talebi kapat' }).first().click();
    await page.getByRole('dialog').getByRole('button', { name: 'Talebi kapat' }).click();
    await expect(page.getByText('Bu talep kapalı; yeni yanıt yazılamaz.')).toBeVisible();
    const after = await (await api.get(`/api/support/tickets/${id}`, { headers: auth(user) })).json();
    expect(after.ticket.status).toBe('CLOSED');
  });
});

test.describe('geri bildirim', () => {
  test('oneri olustur -> panoya al -> durum ve yanit; diger kategoride pano anahtari kapali', async ({ page }) => {
    const subject = `${PREFIX}-oneri`;
    const mk = await userPost('/feedback', { category: 'SUGGESTION', subject, message: 'Karanlık tema olsun. (E2E)' });
    expect(mk.status).toBeLessThan(300);
    const bugSubject = `${PREFIX}-hata`;
    expect((await userPost('/feedback', { category: 'BUG', subject: bugSubject, message: 'Bir hata. (E2E)' })).status).toBeLessThan(300);

    await openAs(page);
    await page.goto('/admin/support/feedback');
    const card = page.locator('li', { hasText: subject });
    await revealWithLoadMore(page, card);
    await card.getByRole('button', { name: 'Değerlendir' }).click();
    const drawer = page.getByRole('dialog');
    await expect(drawer).toContainText('kullanıcıya bildirim gider');
    await drawer.getByLabel('Durum').selectOption({ label: 'Planlandı' });
    await drawer.getByLabel('Yönetici yanıtı').fill('Planlandı: sonraki sürümde.');
    await drawer.getByRole('switch', { name: /öneri panosuna al/ }).click();
    await drawer.getByRole('button', { name: 'Kaydet' }).click();
    await expect(page.getByText('Kaydedildi. Kullanıcıya bildirim gönderildi.')).toBeVisible();

    const board = await (await api.get('/api/suggestions?size=50&sort=new', { headers: auth(user) })).json();
    const hit = board.items.find((s: { subject: string }) => s.subject === subject);
    expect(hit?.status).toBe('PLANNED');
    expect(hit?.adminResponse).toBe('Planlandı: sonraki sürümde.');

    // Hata kategorisinde anahtar devre dışı ve açıklama görünür
    const bug = page.locator('li', { hasText: bugSubject });
    await revealWithLoadMore(page, bug);
    await bug.getByRole('button', { name: 'Değerlendir' }).click();
    const d2 = page.getByRole('dialog');
    await expect(d2.getByRole('switch')).toBeDisabled();
    await expect(d2).toContainText('Yalnızca "Öneri" kategorisindeki kayıtlar');
  });
});

test.describe('sozlesmeler', () => {
  test('editor, onizleme, TASLAK uyarisi, kaydedilmemis degisiklik korumasi ve yayin penceresi (yayin mock)', async ({ page }) => {
    let posted: { url: string; body: Record<string, unknown> } | null = null;
    await openAs(page); // önce: sonradan eklenen route önceliklidir, mock bunun üstünde olmalı
    await page.route('**/api/admin/legal/COMMUNITY_RULES', async (route) => {
      if (route.request().method() !== 'POST') return route.continue();
      posted = { url: route.request().url(), body: route.request().postDataJSON() as Record<string, unknown> };
      return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ version: 99 }) });
    });

    await page.goto('/admin/content/legal');
    await expect(page.getByRole('heading', { name: 'Sözleşmeler', level: 1 })).toBeVisible();
    await page.locator('[data-type="COMMUNITY_RULES"]').click();
    await page.getByRole('tab', { name: /Yeni sürüm/ }).click();

    await page.getByRole('textbox', { name: /^Başlık/ }).fill(`${PREFIX} Topluluk kuralları`);
    const area = page.locator('#legal-content');
    await area.fill('Giriş metni');
    await area.press('Control+A');
    await page.getByRole('button', { name: 'Kalın' }).click();
    await expect(area).toHaveValue('**Giriş metni**');
    await page.getByRole('button', { name: 'Liste' }).click();
    await expect(area).toHaveValue('- **Giriş metni**');
    await area.fill('## Madde 1\n\nSaygılı olun. **Kalın** [bağlantı](https://bingol.edu.tr)\n\n- bir\n- iki\n\nTASLAK');
    const preview = page.getByLabel('Önizleme', { exact: true });
    await expect(preview.locator('h4')).toHaveText('Madde 1');
    await expect(preview.locator('strong')).toHaveText('Kalın');
    await expect(preview.locator('li')).toHaveCount(2);
    await expect(page.getByText('Metinde "TASLAK" ibaresi var.')).toBeVisible();
    await expect(page.getByText('Kaydedilmemiş değişiklikleriniz var.')).toBeVisible();

    // Eksik dil bilgisi + İngilizce sekmesi
    await page.getByRole('tab', { name: /İngilizce/ }).click();
    await expect(page.getByText('Bu dilde Türkçe metin gösterilecek.')).toBeVisible();
    await page.getByRole('textbox', { name: /^Başlık/ }).fill(`${PREFIX} Community rules`);
    await page.locator('#legal-content').fill('Be kind.');

    // Rota değişiminde onay: iptal edilirse sayfadan çıkılmaz
    let dialogSeen = false;
    page.once('dialog', async (d) => {
      dialogSeen = true;
      await d.dismiss();
    });
    await page.getByRole('link', { name: 'Raporlar' }).first().click();
    expect(dialogSeen).toBe(true);
    await expect(page).toHaveURL(/\/admin\/content\/legal/);

    await page.getByRole('switch', { name: /yeniden onay/i }).click(); // kapat
    await page.getByRole('button', { name: 'Yayınla' }).first().click();
    const dlg = page.getByRole('dialog');
    await expect(dlg).toContainText('geri alınamaz');
    await expect(dlg).toContainText('Topluluk kuralları');
    await expect(dlg).toContainText('Türkçe, İngilizce');
    await expect(dlg).toContainText('Arapça'); // Türkçe gösterilecek diller
    await dlg.getByRole('button', { name: 'Yayınla' }).click();
    await expect(page.getByText('Sürüm 99 yayınlandı.')).toBeVisible();

    expect(posted).not.toBeNull();
    const body = posted!.body as { tr: { title: string }; en: { title: string }; ar?: unknown; requireReaccept: boolean };
    expect(body.tr.title).toBe(`${PREFIX} Topluluk kuralları`);
    expect(body.en.title).toBe(`${PREFIX} Community rules`);
    expect(body.ar).toBeUndefined();
    expect(body.requireReaccept).toBe(false);

    // Gerçek yayın yapılmadı: herkese açık uç değişmedi ve çalışıyor
    const pub = await api.get('/api/legal/COMMUNITY_RULES');
    expect(pub.ok()).toBe(true);
    expect((await pub.json()).title).not.toContain(PREFIX);
  });
});

test.describe('sss', () => {
  test('ekle -> duzenle -> taslaga cevir -> sil; Arapca form RTL', async ({ page }) => {
    const q = `${PREFIX} soru?`;
    await openAs(page);
    await page.goto('/admin/content/faq');
    await page.getByRole('button', { name: 'Soru ekle' }).first().click();
    const modal = page.getByRole('dialog');
    await modal.getByRole('button', { name: 'Kaydet' }).click(); // boş: doğrulama
    await expect(modal.getByText('Bu alan zorunludur.').first()).toBeVisible();
    await modal.getByLabel(/^Kategori/).fill('E2E-content');
    await modal.getByLabel(/^Soru/).fill(q);
    await modal.getByLabel(/^Yanıt/).fill('İlk yanıt.');
    await modal.getByLabel('Sıra numarası').fill('999');
    await modal.getByRole('button', { name: 'Kaydet' }).click();
    await expect(page.getByText('Soru kaydedildi.')).toBeVisible();
    const item = page.locator('li', { hasText: q });
    await expect(item).toContainText('Yayında');
    const faq = async () => (await (await api.get('/api/faq', { headers: { 'Accept-Language': 'tr' } })).json()) as { items: { question: string }[] }[];
    expect((await faq()).some((g) => g.items.some((i) => i.question === q))).toBe(true);

    await item.getByRole('button', { name: 'Düzenle' }).click();
    await page.getByRole('dialog').getByLabel(/^Yanıt/).fill('Güncel yanıt.');
    await page.getByRole('dialog').getByRole('button', { name: 'Kaydet' }).click();
    await expect(item).toContainText('Güncel yanıt.');

    await item.getByRole('button', { name: 'Taslağa çevir' }).click();
    await expect(item).toContainText('Taslak');
    expect((await faq()).some((g) => g.items.some((i) => i.question === q))).toBe(false);

    await item.getByRole('button', { name: 'Sil', exact: true }).click();
    await page.getByRole('dialog').getByRole('button', { name: 'Sil', exact: true }).click();
    await expect(page.getByText('Soru silindi.')).toBeVisible();
    await expect(item).toHaveCount(0);

    // Arapça sekme: form RTL
    await page.getByRole('tab', { name: 'Arapça' }).click();
    await page.getByRole('button', { name: 'Soru ekle' }).first().click();
    await expect(page.getByRole('dialog').locator('[dir="rtl"]').first()).toBeVisible();
  });
});

test.describe('haber', () => {
  test('gizle -> herkese acik uctan kaybolur -> goster; senkron onayi ve sonuc toast (mock)', async ({ page }) => {
    const list = await adminGet<{ items: { id: number; title: string }[] }>('/admin/news?hidden=false&size=1');
    test.skip(list.items.length === 0, 'haber yok');
    const news = list.items[0];

    await openAs(page);
    await page.goto('/admin/content/news');
    await page.getByRole('searchbox', { name: 'Ara' }).fill(news.title.slice(0, 60));
    const hideBtn = page.getByRole('button', { name: `Gizle: ${news.title}` }).first();
    await expect(hideBtn).toBeVisible();
    try {
      await hideBtn.click();
      await expect(page.getByText('Haber gizlendi; herkese açık listelerden kalktı.')).toBeVisible();
      expect((await api.get(`/api/news/${news.id}`)).status()).toBe(404);
      await expect(page.getByRole('button', { name: `Göster: ${news.title}` }).first()).toBeVisible();
    } finally {
      // Her koşulda geri aç
      await api.patch(`/api/admin/news/${news.id}`, { headers: auth(admin), data: { hidden: false } });
    }
    expect((await api.get(`/api/news/${news.id}`)).status()).toBe(200);

    // Senkron: gerçek kaynağa istek atılmaz
    await page.route('**/api/admin/sync', (route) =>
      route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ HABER: 2, DUYURU: 0, ETKINLIK: 0 }) }),
    );
    await expect(page.locator('[data-source="NEWS"]')).toContainText('Son başarılı');
    await page.locator('[data-source="NEWS"]').getByRole('button', { name: 'Şimdi senkronize et' }).click();
    const dlg = page.getByRole('dialog');
    await expect(dlg).toContainText('siteye yük bindirir');
    await dlg.getByRole('button', { name: 'Senkronize et' }).click();
    await expect(page.getByText('Haber senkronu bitti: HABER 2')).toBeVisible();
  });
});

test.describe('dil ve rtl', () => {
  const pages: [string, string, string, string][] = [
    ['/admin/reports', 'Raporlar', 'Reports', 'البلاغات'],
    ['/admin/support/tickets', 'Destek talepleri', 'Support tickets', 'تذاكر الدعم'],
    ['/admin/support/feedback', 'Geri bildirim ve öneriler', 'Feedback and suggestions', 'الملاحظات والاقتراحات'],
    ['/admin/content/legal', 'Sözleşmeler', 'Legal documents', 'الاتفاقيات'],
    ['/admin/content/faq', 'Sık sorulan sorular', 'FAQ', 'الأسئلة الشائعة'],
    ['/admin/content/news', 'Haberler', 'News', 'الأخبار'],
  ];
  for (const [path, tr, en, ar] of pages) {
    test(`${path} tr/en/ar acilir`, async ({ browser }) => {
      for (const [lang, title] of [['tr', tr], ['en', en], ['ar', ar]] as const) {
        const ctx = await browser.newContext();
        const page = await ctx.newPage();
        await openAs(page, lang);
        await page.goto(path);
        await expect(page.getByRole('heading', { level: 1, name: title })).toBeVisible();
        await expect(page.locator('html')).toHaveAttribute('dir', lang === 'ar' ? 'rtl' : 'ltr');
        await ctx.close();
      }
    });
  }
});

test.describe('gorsel dogrulama', () => {
  test.skip(!process.env.E2E_SHOTS, 'E2E_SHOTS=1 ile calisir');
  test.setTimeout(10 * 60_000);

  test('tr+ar x acik+koyu x 1440/390 ekran goruntuleri', async ({ browser }) => {
    const ticketId = await createTicket(`${PREFIX}-gorsel`);
    await userPost('/feedback', { category: 'SUGGESTION', subject: `${PREFIX}-gorsel-oneri`, message: 'Görsel doğrulama için örnek öneri metni.' });
    for (const lang of ['tr', 'ar'] as const) {
      for (const theme of ['light', 'dark'] as const) {
        for (const [w, h] of [[1440, 900], [390, 844]] as const) {
          const ctx = await browser.newContext({ viewport: { width: w, height: h } });
          const page = await ctx.newPage();
          await openAs(page, lang, theme);
          const tag = `${lang}-${theme}-${w}`;
          const shot = async (name: string) => {
            await page.waitForTimeout(600);
            await page.screenshot({ path: `e2e/.results/shots/${name}-${tag}.png`, fullPage: false });
          };
          for (const [name, path] of [
            ['reports', '/admin/reports'],
            ['tickets', '/admin/support/tickets'],
            ['ticket', `/admin/support/tickets/${ticketId}`],
            ['feedback', '/admin/support/feedback'],
            ['legal', '/admin/content/legal'],
            ['faq', '/admin/content/faq'],
            ['news', '/admin/content/news'],
          ] as const) {
            await page.goto(path);
            await page.waitForLoadState('networkidle');
            if (name === 'ticket') {
              await page.getByLabel(/Yanıtınız|ردّك/).fill(lang === 'ar' ? 'مرحبًا، شكرًا لتواصلك.' : 'Merhaba, bildiriminiz için teşekkürler.');
            }
            await shot(name);
            if (name === 'legal') {
              await page.getByRole('tab', { name: /Yeni sürüm|إصدار جديد/ }).click();
              await page.getByRole('textbox', { name: /^(Başlık|العنوان)/ }).fill(lang === 'ar' ? 'قواعد المجتمع' : 'Topluluk kuralları');
              if (lang === 'ar') await page.getByRole('tab', { name: /العربية/ }).click();
              await page.getByRole('textbox', { name: /^(Başlık|العنوان)/ }).fill(lang === 'ar' ? 'قواعد المجتمع' : 'Topluluk kuralları');
              await page.locator('#legal-content').fill(
                lang === 'ar'
                  ? '## المادة 1\n\nيرجى الاحترام. **مهم** [رابط](https://bingol.edu.tr)\n\n- الأول\n- الثاني\n\nTASLAK'
                  : '## Madde 1\n\nSaygılı olun. **Önemli** [bağlantı](https://bingol.edu.tr)\n\n- bir\n- iki\n\nTASLAK',
              );
              await shot('legal-editor');
              await page.evaluate(() => (window.onbeforeunload = null));
            }
            if (name === 'faq') {
              await page.getByRole('button', { name: /Soru ekle|إضافة سؤال/ }).first().click();
              await shot('faq-modal');
            }
          }
          await ctx.close();
        }
      }
    }
  });
});
