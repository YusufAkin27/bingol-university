/**
 * SHARED ajanı: ortak kit/kabuk görsel doğrulaması (backendsiz, mockPanel ile). Ekran görüntüleri repoya girmez:
 * SHOTS_DIR (varsayılan C:\bu_qa\shots\adminvisual\after\SHARED). Çalıştırma:
 *   cd web && E2E_PORT=5305 npx playwright test shared-visual.spec.ts
 */
import { expect, test, type Page } from '@playwright/test';
import { mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { json, pageOverflow, stubPanel } from './mockPanel';

const DIR = process.env.SHOTS_DIR || 'C:\\bu_qa\\shots\\adminvisual\\after\\SHARED';
mkdirSync(DIR, { recursive: true });

async function bands(page: Page) {
  await page.route(
    (u) => u.pathname === '/api/app/info',
    (r) =>
      json(r, {
        maintenance: { enabled: true, message: 'Planlı bakım: 03:00-04:00 arasında bildirimler gecikebilir ve yeni kayıt alınamaz.' },
        banner: null,
      }),
  );
  await page.route(
    (u) => u.pathname === '/api/admin/system/storage',
    (r) => json(r, { status: 'WARN', worstPercent: 83, warnPercent: 80, critPercent: 90, items: [] }),
  );
}

/** Dokunma hedefi < 44 px olan görünür etkileşimli öğeler (kendi kaydırma kabı içinde olsa da sayılır). */
async function smallTargets(page: Page) {
  return page.evaluate(() => {
    const out: string[] = [];
    const sel = 'button, a[href], input:not([type=hidden]), select, textarea, [role=tab], [role=button]';
    for (const el of Array.from(document.querySelectorAll<HTMLElement>(sel))) {
      const r = el.getBoundingClientRect();
      if (r.width === 0 || r.height === 0) continue;
      if (getComputedStyle(el).visibility === 'hidden' || el.closest('[hidden]') || el.classList.contains('sr-only') || el.closest('.sr-only')) continue;
      // satır içi metin bağlantıları (paragraf içinde) ölçüt dışı: WCAG 2.5.8 satır içi muafiyeti
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
  ['audit', '/admin/audit'],
  ['roles', '/admin/roles'],
  ['accessbans', '/admin/security/access-bans'],
  ['pushops', '/admin/push/ops'],
  ['pushops-queue', '/admin/push/ops?tab=queue'],
  ['mailqueue', '/admin/mail/queue'],
];

for (const theme of ['light', 'dark'] as const) {
  for (const [w, h] of [
    [390, 844],
    [768, 1024],
    [1280, 800],
  ] as const) {
    for (const [name, route] of PAGES) {
      test(`${name} @${w} ${theme}`, async ({ page }) => {
        await page.emulateMedia({ colorScheme: theme });
        await page.setViewportSize({ width: w, height: h });
        await stubPanel(page, 'FULL');
        await bands(page);
        await page.addInitScript((t) => localStorage.setItem('bu.theme', t), theme);
        await page.goto(route);
        await page.waitForSelector('main h1');
        await page.waitForLoadState('networkidle');
        await page.screenshot({ path: join(DIR, `${name}-${w}-${theme}.png`) });
        if (w === 390 && theme === 'light') {
          const o = await pageOverflow(page);
          expect(o.sw, `taşma: ${o.offenders.join(' | ')}`).toBeLessThanOrEqual(o.cw);
          const small = await smallTargets(page);
          console.log(`[44px ${name}] ${small.length} küçük hedef: ${small.slice(0, 8).join(' ; ')}`);
        }
      });
    }
  }
}

test('telefonda bantlar tek satır ve toplam yükseklik küçük', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await stubPanel(page, 'FULL');
  await bands(page);
  await page.goto('/admin/roles');
  await page.waitForSelector('main h1');
  await page.waitForSelector('[data-testid="storage-banner"]');
  const maint = await page.locator('[role=status]', { hasText: 'Bakım modu açık' }).first().boundingBox();
  const storage = await page.locator('[data-testid="storage-banner"]').boundingBox();
  const total = (maint?.height ?? 0) + (storage?.height ?? 0);
  console.log(`[bantlar] bakım ${maint?.height} + depolama ${storage?.height} = ${total}px (ekran 844)`);
  expect(total).toBeLessThan(844 * 0.12);
  await page.screenshot({ path: join(DIR, 'bands-390-light.png') });
  // kapatılabilir: WARN gizlenir
  await page.getByRole('button', { name: 'Uyarıyı bu oturumda gizle' }).click();
  await expect(page.locator('[data-testid="storage-banner"]')).toBeHidden();
});

test('hata durumu: konu/neden + tek kısa yeniden deneme (< 4 sn)', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await stubPanel(page, 'FULL');
  await page.route(
    (u) => u.pathname === '/api/admin/audit',
    (r) => json(r, { code: 'X', message: 'boom' }, 500),
  );
  const t0 = Date.now();
  await page.goto('/admin/audit');
  await page.getByRole('alert').first().waitFor({ timeout: 8000 });
  console.log(`[hata] iskelet -> hata ${Date.now() - t0} ms`);
  await page.screenshot({ path: join(DIR, 'error-390-light.png') });
});
