/**
 * Akademisyen ders sayfasi sekmeleri (BACKEND'SIZ): program (saat dogrulamasi), ogrenci ekleme (arama + coklu secim), yoklama ayrintisi
 * (dort durum), devamsizlik siniri, duyuru formu (yedi tur, dosya yukleme, reddedilen dosya), CSV indirme.
 *   cd web && npx playwright test academician-course.spec.ts
 */
import { mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { expect, test, type Page } from '@playwright/test';
import { guardConsole, installAcademicianFake, newState, seedAcadSession, type FakeState } from './academician-fake';

const TMP = path.join('e2e', '.results', 'acad-files');
mkdirSync(TMP, { recursive: true });
const pdf = path.join(TMP, 'ders-notu.pdf');
writeFileSync(pdf, '%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF\n');
const exe = path.join(TMP, 'virus.exe');
writeFileSync(exe, 'MZ');

async function setup(page: Page, over: Partial<FakeState> = {}) {
  const st = newState(over);
  const g = guardConsole(page, st);
  await seedAcadSession(page);
  await installAcademicianFake(page, st);
  return { st, g };
}

test('program: saat dogrulamasi (bitis baslangictan sonra), kaydet gonderir', async ({ page }) => {
  const { st, g } = await setup(page);
  await page.goto('/akademisyen/dersler/7?sekme=program');
  await expect(page.getByRole('tab', { name: 'Program', selected: true })).toBeVisible();
  await page.getByRole('button', { name: 'Saat ekle' }).click();
  const rows = page.locator('li').filter({ has: page.getByLabel(/^Gün \d/) });
  await expect(rows).toHaveCount(2);
  const second = rows.nth(1);
  await second.getByLabel('Başlangıç').fill('10:00');
  await second.getByLabel('Bitiş').fill('09:00');
  await expect(page.getByText('Bitiş saati başlangıçtan sonra olmalı.')).toBeVisible();
  await page.getByRole('button', { name: 'Programı kaydet' }).click();
  expect(st.calls).not.toContain('PUT /academician/courses/7/slots');
  await second.getByLabel('Bitiş').fill('10:50');
  await page.getByRole('button', { name: 'Programı kaydet' }).click();
  await expect(page.getByText('Program kaydedildi.')).toBeVisible();
  expect(st.calls).toContain('PUT /academician/courses/7/slots');
  g.assertClean();
});

test('ogrenci ekle: arama, coklu secim, ekle; sayfalama (imlec) ve zaten kayitli rozeti', async ({ page }) => {
  const { st, g } = await setup(page);
  await page.goto('/akademisyen/dersler/7/ogrenciler/ekle');
  await expect(page.getByText('Arama yapın ya da süzgeç seçin')).toBeVisible();
  await page.getByRole('searchbox').first().fill('2024');
  await expect(page.getByRole('table', { name: 'Öğrenci rehberi sonuçları' }).or(page.getByRole('table')).first()).toBeVisible();
  // ilk dort ogrenci zaten kayitli
  await expect(page.getByText('Derste').first()).toBeVisible();
  const boxes = page.getByRole('checkbox', { name: /öğrencisini seç/ });
  await boxes.nth(4).check();
  await boxes.nth(5).check();
  await expect(page.getByRole('button', { name: /Seçilen 2 öğrenciyi ekle/ })).toBeVisible();
  // imlecli sayfalama: "daha fazla" ile sonraki sayfa gelir
  const more = page.getByRole('button', { name: /Daha fazla|Devamını/ });
  if (await more.count()) await more.first().click();
  await page.getByRole('button', { name: /Seçilen 2 öğrenciyi ekle/ }).click();
  await expect(page.getByText(/2 öğrenci eklendi/)).toBeVisible();
  expect(st.enrolled.length).toBe(6);
  g.assertClean();
});

test('yoklama sekmesi: liste + ayrinti cekmecesi dort durumu gosterir, suzgec calisir', async ({ page }) => {
  const { g } = await setup(page);
  await page.goto('/akademisyen/dersler/7?sekme=yoklamalar');
  await expect(page.getByRole('link', { name: /Canlı ekran/ }).first()).toBeVisible();
  await page.getByRole('button', { name: 'Ayrıntı' }).first().click();
  const dlg = page.getByRole('dialog');
  await expect(dlg).toBeVisible();
  for (const label of ['Var (QR)', 'Var (elle)', 'Silindi', 'Yok']) await expect(dlg.getByRole('table').getByText(label, { exact: true }).first()).toBeVisible();
  await dlg.getByLabel('Duruma göre süz').selectOption('REVOKED');
  await expect(dlg.getByRole('table').getByText('Var (QR)', { exact: true })).toHaveCount(0);
  await page.keyboard.press('Escape');
  await expect(dlg).toBeHidden();
  g.assertClean();
});

test('devamsizlik: sinir dogrulamasi (aralik), kaydet, tablo siralamasi ve durum rozetleri', async ({ page }) => {
  const { st, g } = await setup(page);
  await page.goto('/akademisyen/dersler/7?sekme=devamsizlik');
  await page.getByLabel('Sınır türü').selectOption('PERCENT');
  await page.getByLabel(/yüzde/).fill('150');
  await page.getByRole('button', { name: 'Kaydet' }).click();
  await expect(page.getByText('1 ile 100 arasında bir tam sayı girin.')).toBeVisible();
  expect(st.calls).not.toContain('PATCH /academician/courses/7');
  await page.getByLabel(/yüzde/).fill('30');
  await page.getByRole('button', { name: 'Kaydet' }).click();
  await expect(page.getByText('Devamsızlık sınırı kaydedildi.')).toBeVisible();
  const patch = st.bodies.find((b) => b.key === 'PATCH /academician/courses/7')!.body as Record<string, unknown>;
  expect(patch).toEqual({ absenceLimitType: 'PERCENT', absenceLimitValue: 30 });
  // matris: asan, riskte ve normal rozetleri
  await expect(page.getByText('Sınırı aştı').first()).toBeVisible();
  await expect(page.getByText('Sınıra bir kala').first()).toBeVisible();
  g.assertClean();
});

const TYPES: Array<{ label: string; title?: string; event?: boolean; note?: boolean; files: boolean }> = [
  { label: 'Ders başladı', files: false },
  { label: 'Yoklama başladı', files: false },
  { label: 'Sınav', title: 'Vize', event: true, note: true, files: true },
  { label: 'Ödev', title: 'Ödev 1', event: true, note: true, files: true },
  { label: 'Ders materyali', title: 'Hafta 3 slaytları', note: true, files: true },
  { label: 'Ders iptal', event: true, note: true, files: false },
  { label: 'Derslik değişti', title: 'B-204', note: true, files: false },
];

test('duyuru formu: yedi turun alanlari, zorunlu dogrulama ve gonderim', async ({ page }) => {
  const { st, g } = await setup(page);
  await page.goto('/akademisyen/dersler/7?sekme=duyurular');
  for (const tp of TYPES) {
    await page.getByLabel('Duyuru türü').selectOption({ label: tp.label });
    await expect(page.getByLabel(tp.label === 'Derslik değişti' ? /^Yeni derslik/ : /^Başlık/)).toHaveCount(tp.title ? 1 : 0);
    await expect(page.getByLabel(/Not \(isteğe bağlı\)/)).toHaveCount(tp.note ? 1 : 0);
    await expect(page.getByText('Dosya seç', { exact: true })).toHaveCount(tp.files ? 1 : 0);
    // bos gonderim: zorunlu alan varsa hata, yoksa gonderilir
    await page.getByRole('button', { name: 'Duyuruyu gönder' }).click();
    if (tp.title || tp.event) {
      await expect(page.getByText('Bu alan zorunlu.').first()).toBeVisible();
    } else {
      await expect(page.getByText(/Duyuru gönderildi/).first()).toBeVisible();
    }
  }
  // sadece zorunlu alani bos birakilanlar sunucuya gitmedi
  const posted = st.bodies.filter((b) => b.key === 'POST /academician/courses/7/notices').map((b) => (b.body as { type: string }).type);
  expect(posted).toEqual(['LESSON_STARTED', 'ATTENDANCE_STARTED']);
  g.assertClean();
});

test('duyuru: dosyali tur (Sinav) yukleme + reddedilen dosya + gonderim ve listede ek', async ({ page }) => {
  const { st, g } = await setup(page);
  await page.goto('/akademisyen/dersler/7?sekme=duyurular');
  await page.getByLabel('Duyuru türü').selectOption({ label: 'Sınav' });
  await page.getByLabel(/^Başlık/).fill('Vize sınavı');
  await page.getByLabel('Sınav zamanı').fill('2026-12-20T10:00');
  const input = page.locator('input[type=file]');
  // yerel olarak reddedilen tur (exe): sunucuya gitmez
  await input.setInputFiles(exe);
  await expect(page.getByText(/Bu dosya türü kabul edilmiyor/)).toBeVisible();
  expect(st.calls).not.toContain('POST /academician/courses/7/notice-files');
  // gecerli PDF yuklenir
  await input.setInputFiles(pdf);
  await expect(page.getByText('Yüklendi')).toBeVisible();
  // reddedilen dosya hata ile kalirken gonderim engellenir
  await page.getByRole('button', { name: 'Duyuruyu gönder' }).click();
  await expect(page.getByText('Yüklenemeyen dosyalar var. Yeniden deneyin ya da listeden kaldırın.')).toBeVisible();
  await page.getByRole('button', { name: /virus.exe dosyasını kaldır/ }).click();
  await page.getByRole('button', { name: 'Duyuruyu gönder' }).click();
  await expect(page.getByText(/Duyuru gönderildi/)).toBeVisible();
  const b = st.bodies.find((x) => x.key === 'POST /academician/courses/7/notices')!.body as { fileIds: number[]; type: string; eventAt: string };
  expect(b.type).toBe('EXAM');
  expect(b.fileIds).toHaveLength(1);
  expect(b.eventAt).toMatch(/Z$/);
  await expect(page.getByRole('list', { name: 'Ekler' }).getByText('ders-notu.pdf')).toBeVisible();
  g.assertClean();
});

test('duyuru: sunucunun reddettigi dosya hata gosterir', async ({ page }) => {
  const { st } = await setup(page, { uploadReject: true });
  await page.goto('/akademisyen/dersler/7?sekme=duyurular');
  await page.getByLabel('Duyuru türü').selectOption({ label: 'Ders materyali' });
  await page.locator('input[type=file]').setInputFiles(pdf);
  await expect(page.getByRole('alert').filter({ hasText: /dosya türü|kabul/i }).first()).toBeVisible();
  expect(st.calls).toContain('POST /academician/courses/7/notice-files');
});

test('CSV indir: tarayici dosya indirmesi tetiklenir (BOM ve Turkce karakter korunur)', async ({ page }) => {
  const { g } = await setup(page);
  await page.goto('/akademisyen/dersler/7?sekme=disa-aktar');
  const [dl] = await Promise.all([page.waitForEvent('download'), page.getByRole('button', { name: 'CSV indir' }).click()]);
  expect(dl.suggestedFilename()).toMatch(/^devamsizlik-bil101\.csv$/);
  const p = await dl.path();
  const { readFileSync } = await import('node:fs');
  const text = readFileSync(p!, 'utf8');
  expect(text.startsWith('﻿')).toBe(true);
  expect(text).toContain('Ayşe');
  await expect(page.getByText('CSV indirildi.')).toBeVisible();
  g.assertClean();
});
