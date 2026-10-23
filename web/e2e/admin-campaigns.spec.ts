/**
 * Topluluk/etkinlik onayı, bildirim kampanyaları ve ayarlar sayfalarının uçtan uca testleri (gerçek backend: http://localhost:8080).
 *
 *   cd web && E2E_PORT=5194 E2E_ADMIN_EMAIL=admin4@bingol.edu.tr npx playwright test admin-campaigns.spec.ts
 *
 * Kurallar: push yalnızca kendine (SELF) veya tek test kullanıcısına gider; ALL gönderimi mock'lanır.
 * Değiştirilen ayarlar test sonunda eski değerine döner; bakım modu hiç açılmaz.
 */
import { expect, test, type APIRequestContext, type Page } from '@playwright/test';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { ADMIN_EMAIL, ADMIN_PASSWORD } from './helpers';

const API = process.env.VITE_DEV_BACKEND || 'http://localhost:8080';
const PREFIX = 'E2E-campaigns-';
const STAMP = Date.now().toString(36);
const ACCESS = 'bu.admin.access';
const REFRESH = 'bu.admin.refresh';
const DRAFT_KEY = 'bu.admin.campaignDraft';
const PASSWORD = 'Sifre1234';

interface Tok {
  accessToken: string;
  refreshToken: string;
}

let api: APIRequestContext;
let admin: Tok;
const userTokens: Record<string, string> = {};
const originalSettings: Record<string, string> = {};
const TOUCHED_KEYS = ['banner_text_tr', 'banner_text_en', 'banner_text_ar', 'banner_url', 'faculties'];

async function login(email: string): Promise<Tok> {
  const res = await api.post('/api/auth/login', { data: { email, password: PASSWORD } });
  if (!res.ok()) throw new Error(`login ${email}: ${res.status()} ${await res.text()}`);
  return (await res.json()) as Tok;
}

/** Giriş hız sınırı (e-posta başına 15 dk'da 10) için belirteçleri kısa süre diskte paylaşır. */
async function cachedLogin(email: string): Promise<Tok> {
  const file = path.join(os.tmpdir(), `bu-e2e-campaigns-${email.replace(/[^a-z0-9]/gi, '_')}.json`);
  try {
    const c = JSON.parse(fs.readFileSync(file, 'utf8')) as { at: number; tok: Tok };
    if (Date.now() - c.at < 12 * 60 * 1000) return c.tok;
  } catch {
    /* önbellek yok */
  }
  const tok = await login(email);
  try {
    fs.writeFileSync(file, JSON.stringify({ at: Date.now(), tok }));
  } catch {
    /* yoksay */
  }
  return tok;
}

const auth = (token: string) => ({ Authorization: `Bearer ${token}` });
const adminH = () => auth(admin.accessToken);

async function userToken(email: string): Promise<string> {
  userTokens[email] ??= (await cachedLogin(email)).accessToken;
  return userTokens[email];
}

/** Onay bekleyen kayıt açar: hız sınırına takılırsa sıradaki normal kullanıcıyı dener. */
async function createAsUser(pathUrl: string, data: Record<string, unknown>): Promise<{ id: number }> {
  const pool = ['sahip4409', 'yabanci4409', 'dorduncu4409', 'uye4409', 'wa911533', 'wb911533', 'wc911533', 'mali6579', 'mayse6579', 'mcan6579', 'tr1013'];
  for (const u of pool) {
    let token: string;
    try {
      token = await userToken(`${u}@bingol.edu.tr`);
    } catch {
      continue; // giriş hız sınırı: sıradaki kullanıcı
    }
    const res = await api.post(pathUrl, { data, headers: auth(token) });
    if (res.status() === 429 || (res.status() === 409 && (await res.text()).includes('COMMUNITY_LIMIT'))) continue;
    if (!res.ok()) throw new Error(`${pathUrl}: ${res.status()} ${await res.text()}`);
    return (await res.json()) as { id: number };
  }
  throw new Error('tüm test kullanıcıları hız sınırında');
}
const makeCommunity = (name: string) =>
  createAsUser('/api/communities', { name, description: `${PREFIX} test topluluğu. Açıklama metni.`, category: 'Test' });
const makeEvent = (title: string, startsInHours: number) =>
  createAsUser('/api/events', {
    title,
    description: `${PREFIX} test etkinliği.`,
    startsAt: new Date(Date.now() + startsInHours * 3600_000).toISOString(),
    endsAt: new Date(Date.now() + (startsInHours + 2) * 3600_000).toISOString(),
    location: 'Test salonu',
    capacity: 50,
  });

async function openAsAdmin(page: Page, url: string, lang: 'tr' | 'en' | 'ar' = 'tr'): Promise<void> {
  // Vite dev proxy'si tarayıcının Origin başlığını aynen iletir; backend CORS yalnızca :5173/:3000 kabul eder
  // (POST/PUT için 403 "Invalid CORS request"). E2E farklı portta koştuğundan Origin :5173'e çevrilir.
  await page.route('**/api/**', (route) => {
    const headers = { ...route.request().headers() };
    if (headers.origin) headers.origin = 'http://localhost:5173';
    return route.continue({ headers });
  });
  await page.addInitScript(
    ([a, r, ak, rk, l, dk]) => {
      sessionStorage.setItem(ak, a);
      sessionStorage.setItem(rk, r);
      try {
        localStorage.setItem('bu.lang', l);
        if (!sessionStorage.getItem('e2e-draft-kept')) {
          localStorage.removeItem(dk);
          sessionStorage.setItem('e2e-draft-kept', '1');
        }
      } catch {
        /* yoksay */
      }
    },
    [admin.accessToken, admin.refreshToken, ACCESS, REFRESH, lang, DRAFT_KEY],
  );
  await page.goto(url);
}

test.describe.configure({ mode: 'serial' });

test.beforeAll(async ({ playwright }) => {
  api = await playwright.request.newContext({ baseURL: API });
  admin = await cachedLogin(ADMIN_EMAIL);
  expect(ADMIN_EMAIL).toBe('admin4@bingol.edu.tr');
  void ADMIN_PASSWORD;
  const res = await api.get('/api/admin/settings', { headers: adminH() });
  const all = (await res.json()) as Record<string, string>;
  for (const k of TOUCHED_KEYS) originalSettings[k] = all[k] ?? '';
});

test.afterAll(async () => {
  // ayarları eski değerine döndür; bakım modunu asla açık bırakma
  for (const k of TOUCHED_KEYS) {
    await api.put(`/api/admin/settings/${k}`, { data: { value: originalSettings[k] ?? '' }, headers: adminH() });
  }
  await api.put('/api/admin/settings/maintenance_mode', { data: { value: 'false' }, headers: adminH() });
  // kuyrukta kalan test kayıtlarını reddet (kuyruk temiz kalsın)
  for (const kind of ['communities', 'events']) {
    const res = await api.get(`/api/admin/${kind}?status=PENDING_REVIEW&size=100`, { headers: adminH() });
    if (!res.ok()) continue;
    const items = ((await res.json()) as { items: { id: number; name?: string; title?: string }[] }).items;
    for (const it of items) {
      if ((it.name ?? it.title ?? '').startsWith(PREFIX)) {
        await api.post(`/api/admin/${kind}/${it.id}/reject`, { data: { reason: 'e2e temizlik' }, headers: adminH() });
      }
    }
  }
  await api.dispose();
});

test.describe('topluluklar ve etkinlikler', () => {
  test('topluluk: kuyrukta görünür, onaylanır ve reddedilir', async ({ page }) => {
    const okName = `${PREFIX}onay-${STAMP}`;
    const noName = `${PREFIX}red-${STAMP}`;
    await makeCommunity(okName);
    await makeCommunity(noName);
    await openAsAdmin(page, '/admin/communities');

    const okRow = page.getByRole('listitem').filter({ hasText: okName });
    await expect(okRow).toBeVisible();
    await expect(okRow).toContainText('Açıklama metni');
    await okRow.getByRole('button', { name: 'Onayla' }).click();
    await expect(page.getByText(`“${okName}” onaylandı`)).toBeVisible();
    await expect(okRow).toHaveCount(0);

    const noRow = page.getByRole('listitem').filter({ hasText: noName });
    await noRow.getByRole('button', { name: 'Reddet' }).click();
    const dialog = page.getByRole('dialog');
    await dialog.getByLabel(/Red nedeni/).fill('E2E: uygun değil');
    await dialog.getByRole('button', { name: 'Reddet' }).click();
    await expect(page.getByText(`“${noName}” reddedildi`)).toBeVisible();
    await expect(noRow).toHaveCount(0);

    await page.getByRole('tab', { name: 'Aktif' }).click();
    await expect(page.getByRole('listitem').filter({ hasText: okName })).toBeVisible();
    await page.getByRole('tab', { name: 'Reddedilen' }).click();
    await expect(page.getByRole('listitem').filter({ hasText: noName })).toBeVisible();
  });

  test('topluluk: önizleme çekmecesinden onaylanır', async ({ page }) => {
    const name = `${PREFIX}cekmece-${STAMP}`;
    await makeCommunity(name);
    await openAsAdmin(page, '/admin/communities');
    await page.getByRole('listitem').filter({ hasText: name }).getByRole('heading').click();
    const drawer = page.getByRole('dialog');
    await expect(drawer.getByText('Katılım politikası')).toBeVisible();
    await drawer.getByRole('button', { name: 'Reddet' }).click();
    await page.getByRole('dialog').last().getByRole('button', { name: 'Reddet' }).click();
    await expect(page.getByText(`“${name}” reddedildi`)).toBeVisible();
  });

  test('etkinlik: yakında başlayan vurgulanır; onaylanır ve reddedilir', async ({ page }) => {
    const soon = `${PREFIX}yakin-${STAMP}`;
    const far = `${PREFIX}uzak-${STAMP}`;
    await makeEvent(soon, 5);
    await makeEvent(far, 24 * 10);
    await openAsAdmin(page, '/admin/events');

    const soonRow = page.getByRole('listitem').filter({ hasText: soon });
    await expect(soonRow).toBeVisible();
    await expect(soonRow).toContainText('Yakında başlıyor');
    await expect(soonRow).toContainText('Test salonu');
    await expect(soonRow).toContainText('50');
    const farRow = page.getByRole('listitem').filter({ hasText: far });
    await expect(farRow).not.toContainText('Yakında başlıyor');

    await soonRow.getByRole('button', { name: 'Onayla' }).click();
    await expect(page.getByText(`“${soon}” onaylandı`)).toBeVisible();
    await farRow.getByRole('button', { name: 'Reddet' }).click();
    await page.getByRole('dialog').getByRole('button', { name: 'Reddet' }).click();
    await expect(page.getByText(`“${far}” reddedildi`)).toBeVisible();
    await page.getByRole('tab', { name: 'Aktif' }).click();
    await expect(page.getByRole('listitem').filter({ hasText: soon })).toBeVisible();
  });
});

async function fillContent(page: Page, title: string, body: string): Promise<void> {
  await page.getByLabel('Başlık').fill(title);
  await page.getByLabel('Metin', { exact: true }).fill(body);
}

test.describe('kampanyalar', () => {
  test('SELF: oluştur → liste → SENT → kullanıcının bildirim listesinde', async ({ page }) => {
    const title = `${PREFIX}self-${STAMP}`;
    await openAsAdmin(page, '/admin/campaigns/new');
    await expect(page.getByRole('radio', { name: /Yalnızca ben/ })).toBeChecked();
    await expect(page.getByTestId('audience-count')).toContainText('1');
    await expect(page.getByTestId('audience-count')).toContainText('kişiye gidecek');

    await fillContent(page, title, 'Bu bir otomatik test bildirimidir.');
    await expect(page.getByTestId('phone-notification')).toContainText(title);
    await page.getByTestId('send-button').click();
    const dialog = page.getByRole('dialog');
    await expect(dialog).toContainText('1 kişiye şu içerikle gönderilecek');
    await expect(dialog).toContainText('geri alınamaz');
    await dialog.getByTestId('confirm-send').click();

    await expect(page).toHaveURL(/\/admin\/campaigns$/);
    const row = page.getByRole('row').filter({ hasText: title });
    await expect(row).toBeVisible();
    await expect(row.getByText('Gönderildi')).toBeVisible({ timeout: 45_000 });

    await expect
      .poll(
        async () => {
          const r = await api.get('/api/notifications?size=20', { headers: adminH() });
          return JSON.stringify(await r.json());
        },
        { timeout: 20_000 },
      )
      .toContain(title);
  });

  test('USERS: arama ile tek kullanıcı seç; en kullanıcısı bildirimi kendi dilinde alır', async ({ page }) => {
    const stamp = `${PREFIX}dil-${STAMP}`;
    await openAsAdmin(page, '/admin/campaigns/new');
    await page.getByRole('radio', { name: /Seçili kullanıcılar/ }).check();
    await page.getByLabel(/Kullanıcı ara/).fill('en1013');
    await page.getByRole('button', { name: /en1013@bingol\.edu\.tr/ }).click();
    await expect(page.getByRole('list', { name: 'Seçilen kullanıcılar' })).toContainText('en1013@bingol.edu.tr');
    await expect(page.getByTestId('audience-count')).toContainText('1');
    await expect(page.getByText('1 / 500 kişi seçildi')).toBeVisible();

    // üç dilde içerik
    await fillContent(page, `${stamp} TR`, 'Türkçe metin');
    await page.getByRole('tab', { name: /English/ }).click();
    await fillContent(page, `${stamp} EN`, 'English text');
    await page.getByRole('tab', { name: /العربية/ }).click();
    await fillContent(page, `${stamp} AR`, 'نص عربي');

    await page.getByTestId('send-button').click();
    await page.getByRole('dialog').getByTestId('confirm-send').click();
    await expect(page).toHaveURL(/\/admin\/campaigns$/);
    await expect(page.getByRole('row').filter({ hasText: `${stamp} TR` }).getByText('Gönderildi')).toBeVisible({
      timeout: 45_000,
    });

    const en = await userToken('en1013@bingol.edu.tr');
    await expect
      .poll(async () => JSON.stringify(await (await api.get('/api/notifications?size=10', { headers: auth(en) })).json()), {
        timeout: 20_000,
      })
      .toContain(`${stamp} EN`);
  });

  test('zamanlanmış kampanya iptal edilir', async ({ page }) => {
    const title = `${PREFIX}zaman-${STAMP}`;
    await openAsAdmin(page, '/admin/campaigns/new');
    await fillContent(page, title, 'Zamanlanmış test');
    await page.getByRole('radio', { name: /İleri tarihe zamanla/ }).check();
    const when = new Date(Date.now() + 3 * 3600_000);
    const p = (n: number) => String(n).padStart(2, '0');
    const local = `${when.getFullYear()}-${p(when.getMonth() + 1)}-${p(when.getDate())}T${p(when.getHours())}:${p(when.getMinutes())}`;
    await page.getByLabel(/Gönderim zamanı/).fill(local);
    await expect(page.getByText(/Sunucuya UTC olarak gider: \d{4}-\d{2}-\d{2}T/)).toBeVisible();
    await page.getByTestId('send-button').click();
    const dialog = page.getByRole('dialog');
    await expect(dialog).toContainText('seçtiğiniz zamanda');
    await dialog.getByTestId('confirm-send').click();

    await expect(page).toHaveURL(/\/admin\/campaigns$/);
    const row = page.getByRole('row').filter({ hasText: title });
    await expect(row.getByText('Zamanlandı')).toBeVisible();
    await row.click();
    await page.getByRole('button', { name: 'Kampanyayı iptal et' }).click();
    await page.getByRole('dialog').last().getByRole('button', { name: 'Kampanyayı iptal et' }).click();
    await expect(page.getByText('Kampanya iptal edildi.')).toBeVisible();
    await expect(row.getByText('İptal edildi')).toBeVisible();
  });

  test('ALL: ek onay kutusu ister; hız sınırı (RATE_LIMITED) anlaşılır gösterilir (gönderim mock)', async ({ page }) => {
    let posted = 0;
    await openAsAdmin(page, '/admin/campaigns/new');
    await page.route('**/api/admin/push/campaigns', async (route) => {
      if (route.request().method() !== 'POST') return route.fallback();
      posted++;
      return route.fulfill({
        status: 429,
        contentType: 'application/json',
        body: JSON.stringify({ code: 'RATE_LIMITED', message: 'rate' }),
      });
    });
    await page.getByRole('radio', { name: /Tüm kullanıcılar/ }).check();
    await expect(page.getByTestId('audience-count')).toContainText('kişiye gidecek', { timeout: 15_000 });
    await fillContent(page, `${PREFIX}all`, 'Gerçekte gönderilmez');
    await page.getByRole('radio', { name: /Sistem/ }).check();
    await expect(page.getByText('Kullanıcı tercihlerini yok sayar').first()).toBeVisible();
    await page.getByTestId('send-button').click();
    const dialog = page.getByRole('dialog');
    const confirm = dialog.getByTestId('confirm-send');
    await expect(confirm).toBeDisabled();
    await dialog.getByLabel(/Tüm kullanıcılara/).check();
    await expect(confirm).toBeDisabled();
    await dialog.getByLabel(/tercihlerini yok sayacağını/).check();
    await expect(confirm).toBeEnabled();
    await confirm.click();
    await expect(dialog.getByText(/Saatte en fazla 20 kampanya/)).toBeVisible();
    expect(posted).toBe(1);
  });

  test('taslak yenilemede geri yüklenir; “Yeni kampanya” temizler', async ({ page }) => {
    await openAsAdmin(page, '/admin/campaigns/new');
    await fillContent(page, `${PREFIX}taslak`, 'Taslak metni');
    await page.waitForTimeout(700);
    await page.reload();
    await expect(page.getByText(/Önceki taslağınız geri yüklendi/)).toBeVisible();
    await expect(page.getByLabel('Başlık')).toHaveValue(`${PREFIX}taslak`);
    await page.getByRole('button', { name: 'Yeni kampanya' }).click();
    await page.getByRole('dialog').getByRole('button', { name: 'Yeni kampanya' }).click();
    await expect(page.getByLabel('Başlık')).toHaveValue('');
  });

  test('karakter sınırı aşılınca uyarı gösterilir ve gönderim engellenir', async ({ page }) => {
    await openAsAdmin(page, '/admin/campaigns/new');
    await fillContent(page, 'x'.repeat(101), 'kısa');
    await expect(page.getByText('101 / 100')).toBeVisible();
    await expect(page.getByText('Karakter sınırı aşıldı.').first()).toBeVisible();
    await page.getByTestId('send-button').click();
    await expect(page.getByRole('dialog')).toHaveCount(0);
  });
});

test.describe('ayarlar', () => {
  test('banner ve fakülte düzenlenir; herkese açık uçlarda yansır', async ({ page }) => {
    const banner = `${PREFIX}bant-${STAMP}`;
    const faculty = `${PREFIX}Fakulte-${STAMP}`;
    await openAsAdmin(page, '/admin/settings');
    await page.getByRole('tab', { name: /Duyuru bandı/ }).click();
    const field = page.getByLabel('Bant metni (Türkçe)');
    await field.fill(banner);
    await expect(page.locator('[data-key="banner_text_tr"]')).toContainText('Kaydedilmemiş');
    await expect(page.getByTestId('banner-preview')).toContainText(banner);
    await page.getByTestId('save-banner_text_tr').click();
    await expect(page.getByText('“Bant metni (Türkçe)” kaydedildi.')).toBeVisible();
    await expect(page.locator('[data-key="banner_text_tr"]')).not.toContainText('Kaydedilmemiş');
    const info = await (await api.get('/api/app/info', { headers: { 'Accept-Language': 'tr' } })).json();
    expect(info.banner?.text ?? JSON.stringify(info.banner)).toContain(banner);

    // geçersiz bağlantı kaydedilemez
    await page.getByLabel('Bant bağlantısı').fill('http://guvensiz.example');
    await expect(page.getByText('Bağlantı https:// ile başlamalıdır.').first()).toBeVisible();
    await expect(page.getByTestId('save-banner_url')).toBeDisabled();

    await page.getByRole('tab', { name: /Fakülteler/ }).click();
    const add = page.getByLabel('Fakülte ekle');
    await add.fill(faculty);
    await add.press('Enter');
    await add.fill(`${faculty}-2`);
    await add.press('Enter');
    await page.getByRole('button', { name: new RegExp(`${faculty}-2 yukarı taşı`) }).click();
    await page.getByTestId('save-faculties').click();
    await expect(page.getByText('“Fakülte listesi” kaydedildi.')).toBeVisible();
    const list = (await (await api.get('/api/faculties')).json()) as string[];
    expect(list.slice(-2)).toEqual([`${faculty}-2`, faculty]);

    // silme
    await page.getByRole('button', { name: new RegExp(`${faculty}-2 sil`) }).click();
    await page.getByTestId('save-faculties').click();
    await expect.poll(async () => ((await (await api.get('/api/faculties')).json()) as string[]).includes(`${faculty}-2`)).toBe(false);
  });

  test('bakım modu açma onay ister (açılmaz)', async ({ page }) => {
    await openAsAdmin(page, '/admin/settings');
    await page.getByRole('tab', { name: /^Bakım modu/ }).click();
    await page.getByRole('switch').click();
    await page.getByTestId('save-maintenance_mode').click();
    const dialog = page.getByRole('dialog');
    await expect(dialog).toContainText('tüm kullanıcılar bakım mesajını görür');
    await dialog.getByRole('button', { name: 'Vazgeç' }).click();
    const info = await (await api.get('/api/app/info')).json();
    expect(info.maintenance.enabled).toBe(false);
  });

  test('sürüm biçimi doğrulanır', async ({ page }) => {
    await openAsAdmin(page, '/admin/settings');
    await page.getByRole('tab', { name: /Mağaza ve sürümler/ }).click();
    await page.getByLabel('En düşük sürüm (zorunlu)').first().fill('abc');
    await expect(page.getByText(/Sürüm sayılardan ve noktalardan/).first()).toBeVisible();
    await expect(page.getByTestId('save-min_version_android')).toBeDisabled();
    await expect(page.getByText(/minimum sürümün altındaki|en düşük sürüm”ün altında/)).toBeVisible();
  });
});

test.describe('diller', () => {
  const titles: Record<'tr' | 'en' | 'ar', string[]> = {
    tr: ['Topluluklar', 'Etkinlikler', 'Kampanyalar', 'Yeni kampanya oluştur', 'Ayarlar'],
    en: ['Communities', 'Events', 'Campaigns', 'Create a campaign', 'Settings'],
    ar: ['المجتمعات', 'الفعاليات', 'الحملات', 'إنشاء حملة', 'الإعدادات'],
  };
  const urls = ['/admin/communities', '/admin/events', '/admin/campaigns', '/admin/campaigns/new', '/admin/settings'];
  for (const lang of ['tr', 'en', 'ar'] as const) {
    test(`${lang}: sayfalar açılır`, async ({ page }) => {
      for (let i = 0; i < urls.length; i++) {
        await openAsAdmin(page, urls[i], lang);
        await expect(page.getByRole('heading', { level: 1, name: titles[lang][i] })).toBeVisible();
        await expect(page.locator('html')).toHaveAttribute('dir', lang === 'ar' ? 'rtl' : 'ltr');
      }
    });
  }
});

// ---------------------------------------------------------------------------------------------------------------
// Görsel doğrulama: ekran görüntüleri e2e/.results/shots altına yazılır (E2E_SHOTS=1 ile).
const SHOTS = process.env.E2E_SHOTS === '1';
const SHOT_DIR = path.join('e2e', '.results', 'shots');

test.describe('görsel ekran görüntüleri', () => {
  test.skip(!SHOTS, 'E2E_SHOTS=1 ile çalışır');
  test.setTimeout(600_000);

  test('tüm sayfalar: tr+ar × açık+koyu × 1440/390', async ({ browser }) => {
    fs.mkdirSync(SHOT_DIR, { recursive: true });
    await makeCommunity(`${PREFIX}gorsel-${STAMP}`);
    await makeEvent(`${PREFIX}gorsel-etkinlik-${STAMP}`, 6);
    // kampanya satırları için mevcut kampanyalar kullanılır (SELF); ek gönderim yapılmaz
    const draft = {
      audienceType: 'ALL',
      department: '',
      classYear: '',
      users: [],
      contents: {
        tr: { title: 'Final sınavı tarihleri açıklandı', body: 'Güz dönemi final sınav programı yayınlandı. Ayrıntılar için uygulamayı açın.' },
        en: { title: 'Final exam dates announced', body: 'The fall semester final exam schedule is out. Open the app for details.' },
        ar: { title: 'تم الإعلان عن مواعيد الامتحانات النهائية', body: 'تم نشر جدول الامتحانات النهائية للفصل الخريفي. افتح التطبيق للاطلاع على التفاصيل.' },
      },
      notifType: 'SYSTEM',
      targetType: 'URL',
      targetValue: 'https://www.bingol.edu.tr/duyuru',
      scheduleMode: 'later',
      scheduledLocal: (() => {
        const d = new Date(Date.now() + 2 * 86400000);
        const q = (n: number) => String(n).padStart(2, '0');
        return `${d.getFullYear()}-${q(d.getMonth() + 1)}-${q(d.getDate())}T10:00`;
      })(),
    };
    const sizes = [
      { w: 1440, h: 900 },
      { w: 390, h: 844 },
    ];
    for (const lang of ['tr', 'ar'] as const) {
      for (const scheme of ['light', 'dark'] as const) {
        for (const size of sizes) {
          const ctx = await browser.newContext({
            viewport: { width: size.w, height: size.h },
            colorScheme: scheme,
            locale: lang === 'ar' ? 'ar' : 'tr-TR',
          });
          const page = await ctx.newPage();
          const tag = `${lang}-${scheme}-${size.w}`;
          const shot = async (name: string) => {
            await page.waitForTimeout(350);
            await page.screenshot({ path: path.join(SHOT_DIR, `${name}-${tag}.png`), fullPage: true });
          };
          await openAsAdmin(page, '/admin/communities', lang);
          await page.getByRole('heading', { level: 1 }).waitFor();
          await page.getByRole('listitem').first().waitFor();
          await shot('communities');
          await page.goto('/admin/events');
          await page.getByRole('listitem').first().waitFor();
          await shot('events');
          await page.goto('/admin/campaigns');
          await page.getByRole('row').nth(1).waitFor();
          await shot('campaigns');
          await page.getByRole('row').nth(1).click();
          await page.getByRole('dialog').waitFor();
          await shot('campaign-drawer');
          await page.keyboard.press('Escape');
          await page.evaluate(([k, v]) => localStorage.setItem(k, v), [DRAFT_KEY, JSON.stringify(draft)]);
          await page.goto('/admin/campaigns/new');
          await page.getByTestId('audience-count').waitFor();
          await page.waitForTimeout(800);
          await shot('compose');
          await page.getByRole('button', { name: 'AR', exact: true }).click();
          await shot('compose-ar-preview');
          await page.getByTestId('send-button').click();
          await page.getByRole('dialog').waitFor();
          await shot('send-dialog');
          await page.keyboard.press('Escape');
          await page.evaluate((k) => localStorage.removeItem(k), DRAFT_KEY);
          await page.goto('/admin/settings');
          await page.getByRole('heading', { level: 1 }).waitFor();
          await page.locator('[data-key="app_name"]').waitFor();
          await shot('settings-general');
          const tabs = page.getByRole('tab');
          await tabs.nth(1).click();
          await shot('settings-stores');
          await tabs.nth(2).click();
          await page.locator('[data-key="banner_text_tr"] textarea').fill('Kayıtlar 15 Ekim’e kadar uzatıldı. Ayrıntılar için dokunun.');
          await page.locator('[data-key="banner_text_ar"] textarea').fill('تم تمديد التسجيل حتى 15 أكتوبر. اضغط للتفاصيل.');
          await shot('settings-banner');
          await tabs.nth(3).click();
          await shot('settings-maintenance');
          await tabs.nth(4).click();
          const add = page.locator('#faculty-add');
          for (const f of ['Mühendislik Fakültesi', 'Fen-Edebiyat Fakültesi', 'İslami İlimler Fakültesi ile çok uzun bir ad örneği']) {
            await add.fill(f);
            await add.press('Enter');
          }
          await shot('settings-faculties');
          await ctx.close();
        }
      }
    }
  });
});
