/**
 * Akademisyen paneli ve yonetim akademisyen sayfalari: 390 / 768 / 1440 px x acik / koyu. Her sayfada yatay tasma yok, etkilesimli
 * ogeler birbirini ortmez, sayfa disina tasan oge yok, axe (kontrast dahil) temiz, konsol temiz; ekran goruntuleri repo DISINA yazilir.
 *   SHOTS_DIR=<klasor> cd web && npx playwright test academician-visual.spec.ts
 *
 * BILINEN BULGULAR (urun hatasi; test gevsetilmedi, bu yuzden kirmizi kalir):
 *  - 390 px'te /akademisyen/dersler/7 (tum sekmeler): ders basligi eylemleri (Yoklama baslat/Duzenle/Arsivle/Sil) ve sekme cubugu sarmaz,
 *    sayfa scrollWidth 660 > 390 (yatay tasma).
 *  - axe label-content-name-mismatch (WCAG 2.5.3): akademisyen kabugundaki marka baglantisi (aria-label gorunen metni icermiyor),
 *    yonetimde ders secme dugmeleri ve basvuru satiri baglantilari (aria-label "... ayrintisini ac" gorunen adla baslamiyor).
 */
import { createRequire } from 'node:module';
import { mkdirSync } from 'node:fs';
import path from 'node:path';
import { expect, test, type Page } from '@playwright/test';
import { guardConsole, installAcademicianFake, newState, seedAcadSession, type FakeState } from './academician-fake';
import { boot, fresh } from './admin-academicians-fake';

const require = createRequire(import.meta.url);
const AXE = require.resolve('axe-core/axe.min.js');
const SHOTS = process.env.SHOTS_DIR || path.join('e2e', '.results', 'acad-shots');
mkdirSync(SHOTS, { recursive: true });

const WIDTHS = [390, 768, 1440] as const;
const THEMES = ['light', 'dark'] as const;

async function axeViolations(page: Page): Promise<string[]> {
  await page.addScriptTag({ path: AXE });
  return page.evaluate(async () => {
    const res = await (window as unknown as { axe: { run: (c: unknown, o: unknown) => Promise<{ violations: { id: string; impact: string; nodes: { target: string[]; html: string }[] }[] }> } }).axe.run(
      document,
      { rules: { region: { enabled: false } } },
    );
    return res.violations.map((v) => `${v.id} (${v.impact}): ${v.nodes.slice(0, 3).map((n) => n.target.join(' ')).join(' | ')}`);
  });
}

/** Sayfa disina tasan (kaydirilabilir kapsayici disinda) ve birbirini ortup tiklamayi engelleyen etkilesimli ogeler. */
async function layoutProblems(page: Page): Promise<string[]> {
  return page.evaluate(() => {
    const out: string[] = [];
    const vw = document.documentElement.clientWidth;
    const scrollable = (el: Element | null) => {
      for (let e = el; e && e !== document.body; e = e.parentElement) {
        const o = getComputedStyle(e).overflowX;
        if ((o === 'auto' || o === 'scroll' || o === 'hidden') && e.scrollWidth > e.clientWidth) return true;
        if (getComputedStyle(e).position === 'fixed') return true;
      }
      return false;
    };
    const vis = (el: Element) => {
      const r = el.getBoundingClientRect();
      const cs = getComputedStyle(el);
      return r.width > 0 && r.height > 0 && cs.visibility !== 'hidden' && cs.display !== 'none' && cs.opacity !== '0';
    };
    for (const el of Array.from(document.querySelectorAll('main *, header *'))) {
      if (!vis(el)) continue;
      const r = el.getBoundingClientRect();
      if ((r.right > vw + 1 || r.left < -1) && !scrollable(el) && r.width < vw * 3) {
        const label = (el.textContent || '').trim().slice(0, 40);
        out.push(`disarida: <${el.tagName.toLowerCase()} class="${(el.getAttribute('class') || '').slice(0, 30)}"> "${label}" [${Math.round(r.left)}..${Math.round(r.right)}] vw=${vw}`);
        if (out.length > 8) break;
      }
    }
    const inter = Array.from(document.querySelectorAll('a[href],button,input:not([type=hidden]),select,textarea,[role=tab],[role=checkbox]')).filter(vis);
    for (let i = 0; i < inter.length; i++) {
      for (let j = i + 1; j < inter.length; j++) {
        const a = inter[i], b = inter[j];
        if (a.contains(b) || b.contains(a)) continue;
        if (a.parentElement === b.parentElement && (a.tagName === 'INPUT' || b.tagName === 'INPUT')) continue; // alan ici dugme (parola goster)
        if ((a.textContent || '').trim() === 'İçeriğe geç' || (b.textContent || '').trim() === 'İçeriğe geç') continue; // gorunmez atlama baglantisi
        const ra = a.getBoundingClientRect(), rb = b.getBoundingClientRect();
        const w = Math.min(ra.right, rb.right) - Math.max(ra.left, rb.left);
        const h = Math.min(ra.bottom, rb.bottom) - Math.max(ra.top, rb.top);
        if (w > 4 && h > 4) {
          const ta = (a.getAttribute('aria-label') || a.textContent || a.tagName).trim().slice(0, 30);
          const tb = (b.getAttribute('aria-label') || b.textContent || b.tagName).trim().slice(0, 30);
          out.push(`ortusme: "${ta}" x "${tb}" (${Math.round(w)}x${Math.round(h)})`);
          if (out.length > 14) return out;
        }
      }
    }
    return out;
  });
}

interface PageSpec {
  name: string;
  url: string;
  ready: (p: Page) => Promise<void>;
  anonymous?: boolean;
  state?: Partial<FakeState>;
  /** Canli QR: kod degisir; ekran goruntusu yine alinir. */
  skipAxe?: boolean;
}

const heading = (re: RegExp | string) => (p: Page) => p.getByRole('heading', { name: re }).first().waitFor();

const PAGES: PageSpec[] = [
  { name: 'giris', url: '/akademisyen/giris', anonymous: true, ready: heading('Akademisyen girişi') },
  { name: 'kayit', url: '/akademisyen/kayit', anonymous: true, ready: heading('Akademisyen kaydı') },
  { name: 'beklemede', url: '/akademisyen/beklemede', state: { me: { status: 'PENDING', approvalMode: null, title: 'Doç. Dr.', firstName: 'Çağrı', lastName: 'Öztürk', unit: 'Mühendislik ve Mimarlık Fakültesi', rejectReason: null } }, ready: heading('Başvurunuz inceleniyor') },
  { name: 'reddedildi', url: '/akademisyen/beklemede', state: { me: { status: 'REJECTED', approvalMode: 'ADMIN', title: 'Dr.', firstName: 'Şule', lastName: 'Işık', unit: null, rejectReason: 'Kurumsal kimlik doğrulanamadı. Lütfen bilgileri düzeltip yeniden başvurun.' } }, ready: heading('Başvurunuz reddedildi') },
  { name: 'pano', url: '/akademisyen', ready: heading(/Merhaba/) },
  { name: 'dersler', url: '/akademisyen/dersler', ready: async (p) => { await p.getByRole('link', { name: /Veri Yapıları/ }).first().waitFor(); } },
  { name: 'ders-program', url: '/akademisyen/dersler/7?sekme=program', ready: heading(/Veri Yapıları/) },
  { name: 'ders-ogrenciler', url: '/akademisyen/dersler/7?sekme=ogrenciler', ready: async (p) => { await p.getByText('Ayşe Örnek').first().waitFor(); } },
  { name: 'ders-yoklamalar', url: '/akademisyen/dersler/7?sekme=yoklamalar', ready: async (p) => { await p.getByRole('link', { name: /Canlı ekran/ }).first().waitFor(); } },
  { name: 'ders-devamsizlik', url: '/akademisyen/dersler/7?sekme=devamsizlik', ready: async (p) => { await p.getByText('Öğrenciler (risk sırasıyla)').first().waitFor(); }, state: { limit: { type: 'COUNT', value: 3 } } },
  { name: 'ders-duyurular', url: '/akademisyen/dersler/7?sekme=duyurular', ready: async (p) => { await p.getByText('Vize sınavı').first().waitFor(); },
    state: { notices: [
      { id: 2, type: 'EXAM', title: 'Vize sınavı', note: 'Kâğıt ve kalem getirin. Ünite 1-5 sorumludur.', eventAt: '2026-12-20T07:00:00Z', createdAt: '2026-11-12T08:00:00Z', files: [{ id: 5, name: 'çalışma-soruları-2026-güz-dönemi-uzun-dosya-adı.pdf', contentType: 'application/pdf', sizeBytes: 245760 }] },
      { id: 1, type: 'ROOM_CHANGED', title: 'B-204', note: null, eventAt: null, createdAt: '2026-11-11T08:00:00Z', files: [] },
    ] } },
  { name: 'ders-disa-aktar', url: '/akademisyen/dersler/7?sekme=disa-aktar', ready: heading('Devamsızlık tablosunu indir') },
  { name: 'ogrenci-ekle', url: '/akademisyen/dersler/7/ogrenciler/ekle', ready: heading('Derse öğrenci ekle') },
  { name: 'canli', url: '/akademisyen/yoklama/5', ready: async (p) => { await p.locator('svg[data-qr]').waitFor(); await p.getByText('Kayıtsız Kişi').first().waitFor(); }, skipAxe: false },
  { name: 'profil', url: '/akademisyen/profil', ready: heading('Profil') },
];

for (const pg of PAGES) {
  test(`gorsel: ${pg.name}`, async ({ page }) => {
    test.setTimeout(240_000);
    const st = newState(pg.state);
    const g = guardConsole(page, st);
    const issues: string[] = [];
    for (const width of WIDTHS) {
      for (const theme of THEMES) {
        await page.setViewportSize({ width, height: 900 });
        await page.unrouteAll({ behavior: 'ignoreErrors' });
        await page.addInitScript((t) => { try { localStorage.setItem('bu.theme', t); localStorage.setItem('bu.cookies', 'ack:v1'); } catch { /* yok */ } }, theme);
        if (!pg.anonymous) await seedAcadSession(page, theme);
        await installAcademicianFake(page, st);
        await page.goto(pg.url);
        await pg.ready(page);
        await page.waitForTimeout(700);
        const tag = `${pg.name} ${width}px ${theme}`;
        const o = await page.evaluate(() => ({ sw: document.documentElement.scrollWidth, cw: document.documentElement.clientWidth }));
        if (o.sw > o.cw) issues.push(`${tag}: yatay tasma scrollWidth ${o.sw} > ${o.cw}`);
        for (const l of await layoutProblems(page)) issues.push(`${tag}: ${l}`);
        if (!pg.skipAxe) for (const v of await axeViolations(page)) issues.push(`${tag}: axe ${v}`);
        await page.screenshot({ path: path.join(SHOTS, `acad-${pg.name}-${width}-${theme}.png`), fullPage: true });
      }
    }
    g.assertClean();
    expect(issues, issues.join('\n')).toEqual([]);
  });
}

const ADMIN_PAGES: Array<{ name: string; url: string; ready: (p: Page) => Promise<void> }> = [
  { name: 'liste', url: '/admin/academicians', ready: async (p) => { await p.locator('a[href^="/admin/academicians/"]').first().waitFor({ state: 'attached' }); } },
  { name: 'liste-reddedilen', url: '/admin/academicians?tab=rejected', ready: async (p) => { await p.getByText('Belgeler eksik').first().waitFor({ state: 'attached' }); } },
  { name: 'ayrinti', url: '/admin/academicians/200?course=7', ready: async (p) => { await p.getByText('Haftalık program').first().waitFor(); } },
  { name: 'ayrinti-yoklama', url: '/admin/academicians/200?course=7', ready: async (p) => { await p.getByRole('tab', { name: 'Yoklama' }).click(); await p.getByRole('table', { name: 'Yoklama matrisi' }).waitFor(); } },
  { name: 'ayrinti-duyurular', url: '/admin/academicians/200?course=7', ready: async (p) => { await p.getByRole('tab', { name: 'Duyurular' }).click(); await p.getByText('sorular.pdf').first().waitFor(); } },
];

for (const pg of ADMIN_PAGES) {
  test(`gorsel: yonetim ${pg.name}`, async ({ page }) => {
    test.setTimeout(240_000);
    const issues: string[] = [];
    let problems: string[] = [];
    for (const width of WIDTHS) {
      for (const theme of THEMES) {
        await page.setViewportSize({ width, height: 900 });
        await page.unrouteAll({ behavior: 'ignoreErrors' });
        problems = await boot(page, fresh(), theme);
        await page.goto(pg.url);
        await pg.ready(page);
        await page.waitForTimeout(700);
        const tag = `admin-${pg.name} ${width}px ${theme}`;
        const o = await page.evaluate(() => ({ sw: document.documentElement.scrollWidth, cw: document.documentElement.clientWidth }));
        if (o.sw > o.cw) issues.push(`${tag}: yatay tasma scrollWidth ${o.sw} > ${o.cw}`);
        for (const l of await layoutProblems(page)) issues.push(`${tag}: ${l}`);
        for (const v of await axeViolations(page)) issues.push(`${tag}: axe ${v}`);
        await page.screenshot({ path: path.join(SHOTS, `admin-acad-${pg.name}-${width}-${theme}.png`), fullPage: true });
      }
    }
    expect(problems).toEqual([]);
    expect(issues, issues.join('\n')).toEqual([]);
  });
}
