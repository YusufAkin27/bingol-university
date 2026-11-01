/**
 * PANEL-icerik: akademik takvim çizelgesi, menü kalori grafiği, kaynak ızgarası, haber dağılımı (backendsiz, sahte API).
 *   cd web && E2E_PORT=5311 npx playwright test panel-icerik.spec.ts
 * Ekran görüntüleri SHOTS_DIR'e (varsayılan e2e/.results/shots-icerik) yazılır; repoya girmez.
 */
import { expect, test, type Page } from '@playwright/test';
import { mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { json, pageOverflow, stubPanel } from './mockPanel';

const DIR = process.env.SHOTS_DIR || join('e2e', '.results', 'shots-icerik');
mkdirSync(DIR, { recursive: true });

const iso = (d: Date) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
const plus = (days: number) => {
  const d = new Date();
  d.setDate(d.getDate() + days);
  return d;
};

let seq = 0;
const ev = (kind: string, title: string, from: number, to: number | null, published = true) => {
  seq += 1;
  return {
    id: seq,
    kind,
    title,
    startsAt: `${iso(plus(from))}T00:00:00+03:00`,
    endsAt: to === null ? null : `${iso(plus(to))}T23:59:00+03:00`,
    allDay: true,
    scopeDepartment: null,
    note: null,
    published,
  };
};

const EVENTS = [
  ev('DONEM_BASLANGIC', 'Güz dönemi başlangıcı', -40, -40),
  ev('DERS_KAYIT', 'Ders kayıtları', -45, -38),
  ev('VIZE', 'Ara sınav haftası', 2, 6),
  ev('VIZE', 'Mazeret sınavları', 8, 9, false),
  ev('FINAL', 'Final sınavları', 55, 68),
  ev('BUT', 'Bütünleme sınavları', 80, 86),
  ev('RESMI_TATIL', 'Cumhuriyet Bayramı', -3, 0),
  ev('TATIL', 'Yarıyıl tatili', 70, 160),
  ev('DIGER', 'Mezuniyet töreni', 150, null),
];

const dayKcal = (n: number) => {
  // ayın günleri: bazı günler eksik/hiç yok
  const date = iso(new Date(new Date().getFullYear(), new Date().getMonth(), n));
  const dishes = [
    { name: 'Mercimek çorbası', kcal: n % 7 === 0 ? null : 180 },
    { name: 'Tavuk sote', kcal: n % 5 === 0 ? null : 320 + n * 3 },
    { name: 'Pilav', kcal: n % 11 === 0 ? null : 260 },
    { name: 'Ayran', kcal: n % 11 === 0 ? null : 90 },
  ];
  const known = dishes.filter((d) => d.kcal !== null);
  return {
    date,
    items: dishes.map((d) => d.name),
    dishes,
    imageUrl: n % 3 === 0 ? null : '/files/x.jpg',
    totalKcal: known.length ? known.reduce((s, d) => s + (d.kcal ?? 0), 0) : null,
    kcalComplete: known.length === dishes.length,
  };
};

const SRC = (i: number) => {
  const maint = i % 9 === 0;
  const never = i === 4;
  const old = i === 6;
  const off = i === 20;
  return {
    code: `u${i}`,
    name: `${i % 3 === 0 ? 'Meslek Yüksekokulu' : 'Fakültesi'} ${i}`,
    kind: 'FACULTY',
    baseUrl: `https://u${i}.bingol.edu.tr`,
    enabled: !off,
    graduate: false,
    facultyKeys: [],
    departmentCount: 3,
    announcementCount: 40 - i,
    lastSuccessAt: never ? null : old ? new Date(Date.now() - 5 * 86_400_000).toISOString() : new Date(Date.now() - 3_600_000).toISOString(),
    lastAttemptAt: new Date().toISOString(),
    lastMessage: null,
    maintenance: maint,
  };
};

async function stub(page: Page) {
  await stubPanel(page, 'FULL');
  await page.route(
    (u) => u.pathname.startsWith('/api/'),
    (r, next) => {
      const u = new URL(r.request().url());
      const p = u.pathname.replace(/^\/api/, '');
      if (p === '/admin/academic/events')
        return json(r, { items: EVENTS, page: 0, size: 100, total: EVENTS.length, totalPages: 1, totalItems: EVENTS.length });
      if (p === '/admin/menu') return json(r, Array.from({ length: 28 }, (_, i) => dayKcal(i + 1)));
      if (p === '/admin/sources/status')
        return json(r, {
          news: { maintenance: false, lastSuccess: new Date(Date.now() - 7_200_000).toISOString(), lastAttempt: new Date().toISOString(), message: null, itemsLast7d: 14, total: 500, hidden: 6, byType: { HABER: 120, DUYURU: 340, ETKINLIK: 40 } },
          menu: { maintenance: false, lastSuccess: new Date(Date.now() - 10 * 86_400_000).toISOString(), lastAttempt: new Date().toISOString(), message: null, totalDays: 60, upcomingDays: 20, withImage: 30 },
          syncPerHour: 3,
        });
      if (p === '/admin/unit-news/sources') return json(r, Array.from({ length: 23 }, (_, i) => SRC(i + 1)));
      if (p === '/admin/news')
        return json(r, { items: [], page: 0, size: 20, total: 0, totalPages: 1, totalItems: 0 });
      return next();
    },
  );
}

async function shot(page: Page, name: string) {
  await page.waitForTimeout(500);
  await page.screenshot({ path: join(DIR, `${name}.png`), fullPage: true });
}

for (const [w, h, tag] of [
  [1280, 900, 'd'],
  [390, 844, 'm'],
] as const) {
  test.describe(`${tag} ${w}px`, () => {
    test.use({ viewport: { width: w, height: h } });

    test('akademik takvim çizelgesi', async ({ page }) => {
      await stub(page);
      await page.goto('/admin/academic/calendar');
      await expect(page.getByTestId('cal-timeline')).toBeVisible();
      await expect(page.getByRole('heading', { name: 'Yaklaşan olaylar' })).toBeVisible();
      await expect(page.getByRole('button', { name: /Ara sınav haftası, Vize/ }).first()).toBeVisible();
      await shot(page, `takvim-cizelge-${tag}`);
      const o = await pageOverflow(page);
      expect(o.sw, `yatay taşma: ${o.offenders.join(', ')}`).toBeLessThanOrEqual(o.cw);
    });

    test('menü kalori grafiği', async ({ page }) => {
      await stub(page);
      await page.goto('/admin/content/menu');
      await expect(page.getByTestId('menu-kcal-chart')).toBeVisible();
      await shot(page, `menu-kalori-${tag}`);
      const o = await pageOverflow(page);
      expect(o.sw, `yatay taşma: ${o.offenders.join(', ')}`).toBeLessThanOrEqual(o.cw);
    });

    test('kaynak durumu ızgarası', async ({ page }) => {
      await stub(page);
      await page.goto('/admin/sources');
      await expect(page.getByTestId('source-grid')).toBeVisible();
      await expect(page.getByTestId('source-grid').getByRole('listitem').first()).toBeVisible();
      await shot(page, `kaynak-izgara-${tag}`);
      const o = await pageOverflow(page);
      expect(o.sw, `yatay taşma: ${o.offenders.join(', ')}`).toBeLessThanOrEqual(o.cw);
    });

    test('haber dağılımı', async ({ page }) => {
      await stub(page);
      await page.goto('/admin/content/news');
      await expect(page.getByText('Kayıt dağılımı')).toBeVisible();
      await shot(page, `haber-dagilim-${tag}`);
      const o = await pageOverflow(page);
      expect(o.sw, `yatay taşma: ${o.offenders.join(', ')}`).toBeLessThanOrEqual(o.cw);
    });
  });
}
