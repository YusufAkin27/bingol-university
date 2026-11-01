/**
 * İLETİŞİM: Destek + bildirimler sayfalarının görsel doğrulaması (backendsiz, /api taklit). Ekran görüntüleri repoya girmez:
 * SHOTS_DIR (varsayılan ../.playwright-mcp/iletisim/after). Çalıştırma:
 *   cd web && E2E_PORT=5311 SHOTS_DIR=../.playwright-mcp/iletisim/after npx playwright test iletisim-visual.spec.ts
 * "Önce" görüntüsü için aynı betik taban dalda SHOTS_DIR=.../before ile çalıştırılır (yeni metin denetimleri yalnız SHOTS_ONLY=1 ile atlanır).
 */
import { expect, test, type Page } from '@playwright/test';
import { mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { stubIletisim, type Scenario } from './fixtures/iletisim';
import { pageOverflow, stubPanel } from './mockPanel';

const DIR = process.env.SHOTS_DIR || '../.playwright-mcp/iletisim/after';
const SHOTS_ONLY = process.env.SHOTS_ONLY === '1';
mkdirSync(DIR, { recursive: true });

async function smallTargets(page: Page) {
  return page.evaluate(() => {
    const out: string[] = [];
    const sel = 'button, a[href], input:not([type=hidden]), select, textarea, [role=tab], [role=button]';
    for (const el of Array.from(document.querySelectorAll<HTMLElement>(sel))) {
      const r = el.getBoundingClientRect();
      if (r.width === 0 || r.height === 0) continue;
      if (getComputedStyle(el).visibility === 'hidden' || el.closest('[hidden]') || el.closest('.sr-only')) continue;
      if (el.tagName === 'A' && getComputedStyle(el).display === 'inline') continue;
      const label = el.closest('label');
      const box = label ? label.getBoundingClientRect() : r;
      if (Math.max(r.height, box.height) < 43.5 || Math.max(r.width, box.width) < 43.5)
        out.push(`${el.tagName.toLowerCase()}[${(el.getAttribute('aria-label') || el.textContent || '').trim().slice(0, 22)}] ${Math.round(r.width)}x${Math.round(r.height)}`);
    }
    return out;
  });
}

interface PageSpec {
  name: string;
  path: string;
  /** Sayfada görünmesi beklenen yeni metin (yeni denetim). */
  expect?: RegExp;
  /** Boş senaryoda görünmesi beklenen metin. */
  expectEmpty?: RegExp;
}

const PAGES: PageSpec[] = [
  { name: 'tickets', path: '/admin/support/tickets', expect: /Taleplerin durumu/, expectEmpty: /Yanıt bekleyen talep yok/ },
  { name: 'feedback', path: '/admin/support/feedback', expect: /Durumlara göre dağılım/ },
  { name: 'campaigns', path: '/admin/campaigns', expect: /Hedef kitle ve ulaşılan kişi/ },
  { name: 'campaign-new', path: '/admin/campaigns/new', expect: /Kitle|kitle/ },
  { name: 'mail-templates', path: '/admin/mail/templates', expect: /E-posta şablonları özeti|eksik dil/ },
  { name: 'mail-campaigns', path: '/admin/mail/campaigns', expect: /Kampanyaların durumu/ },
  { name: 'mail-campaign-detail', path: '/admin/mail/campaigns/5', expect: /sıraya alındı/ },
  { name: 'mail-queue', path: '/admin/mail/queue', expect: /Müdahale gerekli|Sorunsuz/ },
  { name: 'mail-suppressions', path: '/admin/mail/suppressions', expect: /E-posta engel listesi özeti|spam olarak işaretledi/ },
  { name: 'push-queue', path: '/admin/push/ops?tab=queue', expect: /Bildirim kuyruğunun sağlığı/ },
  { name: 'push-devices', path: '/admin/push/ops?tab=devices', expect: /cihaz son 7 günde/ },
  { name: 'push-stats', path: '/admin/push/ops?tab=stats', expect: /bildirim okundu/ },
];

const SIZES = [
  { tag: '1280', w: 1280, h: 900 },
  { tag: '390', w: 390, h: 844 },
] as const;

async function setup(page: Page, theme: 'light' | 'dark', w: number, h: number, scenario: Scenario) {
  await page.emulateMedia({ colorScheme: theme });
  await page.setViewportSize({ width: w, height: h });
  await stubPanel(page, 'FULL');
  await stubIletisim(page, scenario);
  await page.addInitScript((t) => localStorage.setItem('bu.theme', t), theme);
}

for (const sz of SIZES) {
  for (const ps of PAGES) {
    test(`${ps.name} @${sz.tag} (aydınlık, dolu)`, async ({ page }) => {
      const errors: string[] = [];
      page.on('pageerror', (e) => errors.push(e.message));
      await setup(page, 'light', sz.w, sz.h, 'full');
      await page.goto(ps.path);
      await page.waitForLoadState('networkidle', { timeout: 8000 }).catch(() => {}); // canlı yenilenen sayfalar hiç boşta kalmaz
      await page.waitForTimeout(700);
      if (!SHOTS_ONLY && ps.expect) await expect(page.getByText(ps.expect).first()).toBeVisible();
      await page.screenshot({ path: join(DIR, `${ps.name}-${sz.tag}-light.png`), fullPage: true });
      const o = await pageOverflow(page);
      expect(o.offenders, `yatay taşma ${ps.name}@${sz.tag}`).toEqual([]);
      expect(o.sw).toBeLessThanOrEqual(o.cw + 1);
      expect(errors, 'sayfa hataları').toEqual([]);
      if (sz.tag === '390') {
        const small = await smallTargets(page);
        if (small.length) console.log(`[dokunma<44] ${ps.name}: ${small.slice(0, 6).join(' | ')}`);
      }
    });
  }
}

for (const ps of PAGES) {
  test(`${ps.name} @1280 (koyu, dolu)`, async ({ page }) => {
    await setup(page, 'dark', 1280, 900, 'full');
    await page.goto(ps.path);
    await page.waitForLoadState('networkidle', { timeout: 8000 }).catch(() => {}); // canlı yenilenen sayfalar hiç boşta kalmaz
    await page.waitForTimeout(500);
    await page.screenshot({ path: join(DIR, `${ps.name}-1280-dark.png`), fullPage: true });
  });
}

for (const ps of PAGES.filter((p) => ['tickets', 'feedback', 'campaigns', 'mail-queue', 'mail-suppressions', 'push-queue'].includes(p.name))) {
  for (const sc of ['empty', 'error'] as const) {
    test(`${ps.name} @1280 (${sc})`, async ({ page }) => {
      await setup(page, 'light', 1280, 900, sc);
      await page.goto(ps.path);
      await page.waitForLoadState('networkidle', { timeout: 8000 }).catch(() => {}); // canlı yenilenen sayfalar hiç boşta kalmaz
      await page.waitForTimeout(500);
      if (!SHOTS_ONLY && sc === 'empty' && ps.expectEmpty) await expect(page.getByText(ps.expectEmpty).first()).toBeVisible();
      await page.screenshot({ path: join(DIR, `${ps.name}-1280-${sc}.png`), fullPage: true });
    });
  }
}
