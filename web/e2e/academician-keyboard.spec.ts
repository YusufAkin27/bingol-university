/**
 * Klavye ile gezinme (BACKEND'SIZ): sekmeler ok tuslariyla, dosya secimi dugmesi klavyeyle, Tab sirasinda gorunur odak,
 * onay penceresi Escape ile kapanir ve odagi tetikleyiciye dondurur.
 *   cd web && npx playwright test academician-keyboard.spec.ts
 */
import { expect, test } from '@playwright/test';
import { guardConsole, installAcademicianFake, newState, seedAcadSession } from './academician-fake';

test('ders sekmeleri ok tuslariyla degisir; Tab sirasinda her durakta gorunur odak halkasi var', async ({ page }) => {
  const st = newState();
  const g = guardConsole(page, st);
  await seedAcadSession(page);
  await installAcademicianFake(page, st);
  await page.goto('/akademisyen/dersler/7?sekme=program');
  const first = page.getByRole('tab', { name: 'Program' });
  await first.focus();
  await page.keyboard.press('ArrowRight');
  await expect(page.getByRole('tab', { name: 'Öğrenciler', selected: true })).toBeVisible();
  await expect(page.getByRole('tab', { name: 'Öğrenciler' })).toBeFocused();
  await page.keyboard.press('End');
  await expect(page.getByRole('tab', { name: 'Dışa aktar', selected: true })).toBeVisible();

  // Tab turu: odaktaki ogenin gorunur bir odak gostergesi (outline ya da box-shadow) olmali
  await page.goto('/akademisyen/dersler/7?sekme=duyurular');
  await page.getByRole('link', { name: 'İçeriğe geç' }).focus();
  const bad: string[] = [];
  for (let i = 0; i < 25; i++) {
    await page.keyboard.press('Tab');
    const r = await page.evaluate(() => {
      const el = document.activeElement as HTMLElement | null;
      if (!el || el === document.body) return null;
      const cs = getComputedStyle(el);
      const ring = (cs.outlineStyle !== 'none' && parseFloat(cs.outlineWidth) > 0) || (cs.boxShadow !== 'none' && cs.boxShadow !== '');
      return { ring, label: (el.getAttribute('aria-label') || el.textContent || el.tagName).trim().slice(0, 30), tag: el.tagName, type: (el as HTMLInputElement).type };
    });
    if (r && !r.ring && r.type !== 'file') bad.push(`${r.tag} "${r.label}"`);
  }
  expect(bad, 'odak halkasi olmayan duraklar').toEqual([]);
  g.assertClean();
});

test('dosya secimi dugmesi klavyeyle (Enter) calisir; gizli input odak tuzagi degil', async ({ page }) => {
  const st = newState();
  await seedAcadSession(page);
  await installAcademicianFake(page, st);
  await page.goto('/akademisyen/dersler/7?sekme=duyurular');
  await page.getByLabel('Duyuru türü').selectOption({ label: 'Ödev' });
  const btn = page.getByRole('button', { name: 'Dosya seç' });
  await btn.focus();
  const [chooser] = await Promise.all([page.waitForEvent('filechooser'), page.keyboard.press('Enter')]);
  expect(chooser.isMultiple()).toBe(true);
});

test('ders silme onayi: Escape kapatir ve odak "Sil" dugmesine doner', async ({ page }) => {
  const st = newState();
  await seedAcadSession(page);
  await installAcademicianFake(page, st);
  await page.goto('/akademisyen/dersler/7');
  const del = page.getByRole('button', { name: 'Sil', exact: true });
  await del.focus();
  await page.keyboard.press('Enter');
  await expect(page.getByRole('alertdialog').or(page.getByRole('dialog')).first()).toBeVisible();
  await page.keyboard.press('Escape');
  await expect(page.getByRole('alertdialog').or(page.getByRole('dialog'))).toHaveCount(0);
  await expect(del).toBeFocused();
  expect(st.calls.filter((c) => c.startsWith('DELETE'))).toEqual([]);
});
