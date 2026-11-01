/**
 * REVIEW-VISUAL: arama uçtan uca (backendsiz). Sonuçlar SHOTS_DIR/search-*.jsonl + ekran görüntüleri.
 *   cd web && E2E_PORT=5306 npx playwright test review-search.spec.ts
 */
import { expect, test, type Page } from '@playwright/test';
import { appendFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { json, stubPanel, type Profile, permsOf } from './mockPanel';

const DIR = process.env.SHOTS_DIR || 'C:\\bu_qa\\shots\\adminvisual\\after\\REVIEW';
mkdirSync(DIR, { recursive: true });
const LOG = join(DIR, `${process.env.RUN || 'search'}.jsonl`);
const log = (o: unknown) => appendFileSync(LOG, JSON.stringify(o) + '\n');

const SETTINGS = {
  app_name: 'BÜ Kampüs',
  website: 'https://bukampus.example',
  contact_email: 'info@bingol.edu.tr',
  maintenance_mode: 'false',
  maintenance_message_tr: 'Kısa süreli bakım yapıyoruz.',
  faculties: 'Mühendislik ve Mimarlık Fakültesi;Fen-Edebiyat Fakültesi',
};

async function boot(page: Page, profile: Profile, w: number, h: number, theme: 'light' | 'dark' = 'light', route = '/admin/users') {
  await page.setViewportSize({ width: w, height: h });
  await page.emulateMedia({ colorScheme: theme, reducedMotion: 'no-preference' });
  await page.addInitScript((t) => {
    try {
      localStorage.setItem('bu.theme', t);
      localStorage.setItem('bu.cookies', 'ack:v1');
    } catch {
      /* yoksay */
    }
  }, theme);
  await stubPanel(page, profile);
  await page.route('**/api/admin/settings', (r) => json(r, SETTINGS));
  await page.goto(route, { waitUntil: 'domcontentloaded' });
  await page.waitForSelector('main h1');
}

async function openSearch(page: Page, w: number) {
  if (w >= 1100) await page.keyboard.press('Control+k');
  else await page.getByRole('button', { name: 'Panelde ara' }).click();
  await expect(page.getByRole('combobox', { name: 'Panelde sayfa, ayar ya da işlem ara' })).toBeVisible();
}

const options = (page: Page) => page.getByRole('dialog').getByRole('option');

test('S1 Ctrl+K "bakım modu" -> Ayarlar > Bakım alanı vurgulanır', async ({ page }) => {
  await boot(page, 'FULL', 1280, 800);
  await openSearch(page, 1280);
  await page.keyboard.type('bakım modu');
  await expect(options(page).first()).toContainText('Bakım modu');
  const top = (await options(page).first().innerText()).replace(/\s+/g, ' ');
  await page.screenshot({ path: join(DIR, 'S1-sonuc-1280-light.png') });
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(/\/admin\/settings.*#maintenance_mode$/);
  const target = page.locator('[data-search-anchor="maintenance_mode"]');
  await expect(target).toBeVisible();
  await expect(target).toHaveAttribute('data-search-hit', 'true');
  await expect(page.getByRole('tab', { name: /Bakım modu/ })).toHaveAttribute('aria-selected', 'true');
  const inView = await target.evaluate((el) => {
    const r = el.getBoundingClientRect();
    return r.top >= 0 && r.bottom <= window.innerHeight;
  });
  await page.screenshot({ path: join(DIR, 'S1-vurgu-1280-light.png') });
  log({ s: 'S1', top, inView, url: page.url() });
  expect(inView).toBeTruthy();
});

for (const q of ['siteyi kapat', 'bakim mdu', 'bakım modu', 'BAKIM MODU', 'bakıma al']) {
  test(`S2 sorgu "${q}" ilk sonuç bakım modu`, async ({ page }) => {
    await boot(page, 'FULL', 1280, 800);
    await openSearch(page, 1280);
    await page.keyboard.type(q);
    await page.waitForTimeout(300);
    const n = await options(page).count();
    const texts = (await options(page).allInnerTexts()).slice(0, 4).map((s) => s.replace(/\s+/g, ' '));
    log({ s: 'S2', q, n, texts });
    await page.screenshot({ path: join(DIR, `S2-${q.replace(/\W+/g, '_')}-1280-light.png`) });
    expect(texts.join(' ')).toMatch(/Bakım modu/);
    await page.keyboard.press('Enter');
    await expect(page).toHaveURL(/#maintenance_mode$/);
    await expect(page.locator('[data-search-anchor="maintenance_mode"]')).toHaveAttribute('data-search-hit', 'true');
  });
}

test('S3 yan menü süzgeci alt sonuçları (1280) + tıklayınca derin bağlantı', async ({ page }) => {
  await boot(page, 'FULL', 1280, 800);
  const box = page.getByRole('searchbox', { name: 'Menüde ara' });
  await box.fill('bakim modu');
  const menu = page.getByRole('navigation', { name: 'Yönetim menüsü' });
  await expect(menu.locator('a[href="/admin/settings#maintenance_mode"]')).toBeVisible();
  const links = await menu.locator('a').evaluateAll((as) => as.map((a) => (a as HTMLAnchorElement).getAttribute('href')));
  log({ s: 'S3', links });
  await page.screenshot({ path: join(DIR, 'S3-menu-1280-light.png') });
  await box.fill('');
  await box.fill('sifre');
  await page.waitForTimeout(250);
  await page.screenshot({ path: join(DIR, 'S3-menu-sifre-1280-light.png') });
  log({ s: 'S3b', q: 'sifre', links: await menu.locator('a').evaluateAll((as) => as.map((a) => (a as HTMLAnchorElement).getAttribute('href'))) });
});

for (const theme of ['light', 'dark'] as const) {
  test(`S4 telefonda tam ekran arama 390 ${theme}`, async ({ page }) => {
    await boot(page, 'FULL', 390, 844, theme);
    await openSearch(page, 390);
    const dlg = page.getByRole('dialog');
    const r = await dlg.evaluate((el) => {
      const b = el.getBoundingClientRect();
      return { x: b.x, y: b.y, w: b.width, h: b.height, vw: innerWidth, vh: innerHeight };
    });
    await page.screenshot({ path: join(DIR, `S4-bos-390-${theme}.png`) });
    await page.keyboard.type('bakim');
    await page.waitForTimeout(250);
    await page.screenshot({ path: join(DIR, `S4-sonuc-390-${theme}.png`) });
    const small = await dlg.locator('button, [role=option], input').evaluateAll((els) =>
      els
        .map((e) => e.getBoundingClientRect())
        .filter((b) => b.width > 0 && (b.height < 43.5 || b.width < 43.5))
        .map((b) => `${Math.round(b.width)}x${Math.round(b.height)}`),
    );
    const sw = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
    log({ s: 'S4', theme, rect: r, small, overflow: sw });
    expect(r.w).toBeGreaterThanOrEqual(r.vw - 1);
    expect(r.h).toBeGreaterThanOrEqual(r.vh - 1);
    expect(sw).toBeLessThanOrEqual(0);
    await page.keyboard.press('Escape');
    await expect(dlg).toBeHidden();
  });
}

test('S5 klavye: yukarı/aşağı/Enter/Esc', async ({ page }) => {
  await boot(page, 'FULL', 1280, 800);
  await openSearch(page, 1280);
  await page.keyboard.type('kullanici');
  await page.waitForTimeout(250);
  const a0 = await page.getByRole('dialog').locator('[role=option][data-active="true"]').innerText();
  await page.keyboard.press('ArrowDown');
  const a1 = await page.getByRole('dialog').locator('[role=option][data-active="true"]').innerText();
  await page.keyboard.press('ArrowUp');
  const a2 = await page.getByRole('dialog').locator('[role=option][data-active="true"]').innerText();
  log({ s: 'S5', a0, a1, a2 });
  expect(a0).not.toEqual(a1);
  expect(a0).toEqual(a2);
  await page.keyboard.press('Escape');
  await expect(page.getByRole('dialog')).toBeHidden();
});

// ---- RBAC: yetkisiz sonuç görünmez ----
interface E {
  id: string;
  title: string;
  description: string;
  crumbs: string[];
  to: string;
  perm?: string;
  anchor?: string;
  pageId: string;
  groupId: string;
  kind: string;
}
async function entriesOf(page: Page): Promise<E[]> {
  return page.evaluate(async () => {
    const b = await import(/* @vite-ignore */ '/src/search/build.ts');
    const i = await import(/* @vite-ignore */ '/src/i18n/index.ts');
    const nav = await import(/* @vite-ignore */ '/src/layouts/adminNav.ts');
    const permOf = new Map<string, string | undefined>();
    for (const g of nav.adminNav) for (const it of g.items) permOf.set(it.id, it.perm);
    return (b.buildSearchEntries((k: string) => i.translate('tr', k)) as E[]).map((e) => ({ ...e, perm: e.perm ?? permOf.get(e.pageId) }));
  });
}

for (const profile of ['SUPPORT', 'VIEWER', 'EDITOR'] as const) {
  test(`S6 RBAC ${profile}: yetkisiz girdi görünmez`, async ({ page }) => {
    test.setTimeout(150000);
    await boot(page, profile, 1280, 800, 'light', '/admin');
    const all = await entriesOf(page);
    const granted = new Set(permsOf(profile));
    const restricted = all.filter((e) => e.perm && !granted.has(e.perm) && e.title.length > 3);
    // başlığı başka girdilerle çakışmayan, sayfa başına birer örnek
    const byPage = new Map<string, E>();
    for (const e of restricted) if (!byPage.has(e.pageId) && !all.some((o) => o.id !== e.id && o.title === e.title && (!o.perm || granted.has(o.perm)))) byPage.set(e.pageId, e);
    const sample = Array.from(byPage.values()).slice(0, 14);
    await openSearch(page, 1280);
    const leaks: string[] = [];
    for (const e of sample) {
      await page.getByRole('dialog').getByRole('combobox').fill(e.title);
      await page.waitForTimeout(120);
      const texts = (await options(page).allInnerTexts()).map((s) => s.replace(/\s+/g, ' '));
      const crumb = e.crumbs[e.crumbs.length - 1] ?? '';
      if (texts.some((t) => t.includes(e.title) && (e.description ? t.includes(e.description.slice(0, 20)) : t.includes(crumb)))) leaks.push(`${e.id} (${e.perm})`);
    }
    // olumlu kontrol: yetkili bir girdi bulunuyor
    const okEntry = all.find((e) => e.kind === 'page' && e.perm && granted.has(e.perm))!;
    await page.getByRole('dialog').getByRole('combobox').fill(okEntry.title);
    await page.waitForTimeout(150);
    const found = await options(page).count();
    log({ s: 'S6', profile, checked: sample.length, leaks, positive: okEntry.title, found });
    expect(leaks).toEqual([]);
    expect(found).toBeGreaterThan(0);
  });
}

// ---- 15+ farklı sayfadan derin bağlantı: planı yaz (ziyaretler review-deeplink.spec.ts'te, testi başına temiz sayfa) ----
test('S7 plan: sayfa başına tohumlu rastgele bir ayar/alan girdisi seç ve dosyaya yaz', async ({ page }) => {
  test.setTimeout(180000);
  await boot(page, 'FULL', 1280, 800, 'light', '/admin');
  const all = (await entriesOf(page)).filter((e) => e.anchor && e.kind !== 'page');
  let seed = 20261101;
  const rnd = () => ((seed = (seed * 1664525 + 1013904223) % 4294967296) / 4294967296);
  const byPage = new Map<string, E[]>();
  for (const e of all) byPage.set(e.pageId, [...(byPage.get(e.pageId) ?? []), e]);
  const pages = Array.from(byPage.keys()).sort(() => rnd() - 0.5);
  const picks = pages.map((p) => {
    const l = byPage.get(p)!;
    return l[Math.floor(rnd() * l.length)];
  });
  writeFileSync(join(DIR, 's7-plan.json'), JSON.stringify(picks.map((e) => ({ id: e.id, pageId: e.pageId, groupId: e.groupId, to: e.to, anchor: e.anchor, title: e.title })), null, 1));
  log({ s: 'S7-plan', pages: picks.length });
  expect(picks.length).toBeGreaterThanOrEqual(15);
});
