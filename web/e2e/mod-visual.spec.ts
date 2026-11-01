/**
 * MOD: Moderasyon + Destek görsel doğrulaması (backendsiz). Ekran görüntüleri repoya girmez:
 * SHOTS_DIR (varsayılan C:\bu_qa\shots\adminvisual\after\MOD). Çalıştırma:
 *   cd web && E2E_PORT=5302 npx playwright test mod-visual.spec.ts
 */
import { expect, test, type Page } from '@playwright/test';
import { mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { pageOverflow, stubPanel } from './mockPanel';
import { stubModeration, type Scenario } from './fixtures/moderation';

const DIR = process.env.SHOTS_DIR || 'C:\\bu_qa\\shots\\adminvisual\\after\\MOD';
mkdirSync(DIR, { recursive: true });

/** Dokunma hedefi < 44 px olan görünür etkileşimli öğeler. */
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

const PAGES: [string, string][] = [
  ['reports', '/admin/reports'],
  ['posts', '/admin/posts'],
  ['polls', '/admin/polls'],
  ['blocklist', '/admin/moderation/blocklist'],
  ['strikes', '/admin/moderation/strikes'],
  ['hidden', '/admin/moderation/hidden'],
  ['reason-templates', '/admin/moderation/reason-templates'],
  ['profanity', '/admin/profanity'],
  ['tickets', '/admin/support/tickets'],
  ['ticket-detail', '/admin/support/tickets/2'],
  ['feedback', '/admin/support/feedback'],
];

const SIZES = [
  [390, 844],
  [768, 1024],
  [1280, 800],
] as const;

async function setup(page: Page, theme: 'light' | 'dark', w: number, h: number, scenario: Scenario) {
  await page.emulateMedia({ colorScheme: theme });
  await page.setViewportSize({ width: w, height: h });
  await stubPanel(page, 'FULL');
  await stubModeration(page, scenario);
  await page.addInitScript((t) => localStorage.setItem('bu.theme', t), theme);
}

for (const theme of ['light', 'dark'] as const) {
  for (const [w, h] of SIZES) {
    for (const [name, route] of PAGES) {
      test(`${name} @${w} ${theme}`, async ({ page }) => {
        await setup(page, theme, w, h, 'full');
        await page.goto(route);
        await page.waitForSelector('main h1');
        await page.waitForLoadState('networkidle');
        await page.screenshot({ path: join(DIR, `${name}-${w}-${theme}.png`), fullPage: true });
        if (w === 390 && theme === 'light') {
          const o = await pageOverflow(page);
          const small = await smallTargets(page);
          console.log(`[MOD ${name}] taşma sw=${o.sw}/cw=${o.cw} ${o.offenders.join(' | ')} ; küçük hedef ${small.length}: ${small.slice(0, 6).join(' ; ')}`);
          expect(o.sw, `taşma: ${o.offenders.join(' | ')}`).toBeLessThanOrEqual(o.cw);
        }
      });
    }
  }
}

for (const scenario of ['empty', 'error'] as const) {
  for (const [name, route] of PAGES) {
    test(`${name} ${scenario} @390 light`, async ({ page }) => {
      await setup(page, 'light', 390, 844, scenario);
      await page.goto(route);
      await page.waitForSelector('main h1');
      await page.waitForTimeout(scenario === 'error' ? 9000 : 800);
      await page.screenshot({ path: join(DIR, `${name}-${scenario}-390-light.png`), fullPage: true });
      const o = await pageOverflow(page);
      expect(o.sw, `taşma: ${o.offenders.join(' | ')}`).toBeLessThanOrEqual(o.cw);
    });
  }
}

test('gönderi ayrıntı çekmecesi telefonda kapatılabilir (P-2)', async ({ page }) => {
  await setup(page, 'light', 390, 844, 'full');
  await page.goto('/admin/posts?open=3');
  const close = page.getByRole('button', { name: /Kapat|Close/ }).first();
  await expect(close).toBeVisible();
  const box = await close.boundingBox();
  expect(box && box.x + box.width <= 390 + 1).toBeTruthy();
  await page.screenshot({ path: join(DIR, 'posts-detail-390-light.png') });
  const o = await pageOverflow(page);
  expect(o.sw).toBeLessThanOrEqual(o.cw);
});

test('sohbet akışı mesajlar sekmesi telefonda taşmaz (C-1)', async ({ page }) => {
  await setup(page, 'light', 390, 844, 'full');
  await page.goto('/admin/chat-feed');
  await page.waitForSelector('main h1');
  await page.screenshot({ path: join(DIR, 'chat-feed-gate-390-light.png'), fullPage: true });
  await page.getByRole('textbox').first().fill('Rapor incelemesi 1234 numaralı şikâyet için bakılıyor');
  await page.getByRole('button', { name: /Devam|Onayla|Tamam|Görüntüle/ }).first().click();
  await page.getByRole('tab', { name: 'Mesajlar' }).click();
  await page.getByLabel('Sohbet no').fill('30');
  await page.waitForSelector('[data-testid="feed-list"]');
  await page.waitForLoadState('networkidle');
  await page.screenshot({ path: join(DIR, 'chat-feed-messages-390-light.png'), fullPage: true });
  const o = await pageOverflow(page);
  expect(o.sw, `taşma: ${o.offenders.join(' | ')}`).toBeLessThanOrEqual(o.cw);
});

test('raporlarda ayrıntı telefonda tam ekran açılır ve listeye dönülür (R-1)', async ({ page }) => {
  await setup(page, 'light', 390, 844, 'full');
  await page.goto('/admin/reports');
  await page.waitForSelector('[data-search-anchor="reports-queue"]');
  await page.locator('[data-search-anchor="reports-queue"] button').first().click();
  const back = page.getByRole('button', { name: 'Listeye dön' });
  await expect(back).toBeVisible();
  await page.screenshot({ path: join(DIR, 'reports-sheet-390-light.png') });
  await page.getByRole('radio').nth(3).click();
  await page.screenshot({ path: join(DIR, 'reports-sheet-suspend-390-light.png') });
  await back.click();
  await expect(back).toBeHidden();
});

test('yasaklı görsel: dosya seçilince özet otomatik dolar (B-1)', async ({ page }) => {
  await setup(page, 'light', 1280, 800, 'full');
  await page.goto('/admin/moderation/blocklist');
  await page.waitForSelector('main h1');
  await page.setInputFiles('input[type=file]', { name: 'x.png', mimeType: 'image/png', buffer: Buffer.from('merhaba') });
  const expected = await page.evaluate(async () => {
    const d = await crypto.subtle.digest('SHA-256', new TextEncoder().encode('merhaba'));
    return Array.from(new Uint8Array(d), (b) => b.toString(16).padStart(2, '0')).join('');
  });
  await expect(page.getByRole('textbox', { name: /SHA-256 özeti/ })).toHaveValue(expected);
  await page.screenshot({ path: join(DIR, 'blocklist-hashed-1280-light.png') });
});
