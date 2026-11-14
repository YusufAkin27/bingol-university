// Düzeltme turu 1: ders formu (Enter/çift gönderim/planlanan ders), pano (12 ders sınırı, bekleyen rozeti), yoklama başlatma bildirimleri, CSV adı.
import { fireEvent, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it } from 'vitest';
import { tokensFor } from '../../auth/tokens';
import { asciiSlug, csvFileName } from './course/ExportTab';
import { APPROVED_ME, course, err, mockApi, renderAcademician, setAcadTokens } from './testUtils';

afterEach(() => tokensFor('acad').clearTokens());

const base = () => {
  setAcadTokens();
  return mockApi()
    .get('/academician/me', APPROVED_ME)
    .get('/catalog/academic', { version: 1, faculties: [{ id: 'f1', name: 'Mühendislik ve Mimarlık Fakültesi', departments: [{ id: 'd1', name: 'Bilgisayar Mühendisliği' }] }], grades: [{ id: '1', name: '1. Sınıf' }] });
};

describe('W8: ders formu', () => {
  it('Enter alan içindeyken gönderir; gönderim sürerken ikinci Enter/tıklama ikinci istek üretmez', async () => {
    let release!: () => void;
    const api = base()
      .get('/academician/courses', [])
      .post('/academician/courses', () => new Promise<Response>((r) => (release = () => r(new Response(JSON.stringify({ ...course({ id: 9 }) }), { status: 201, headers: { 'Content-Type': 'application/json' } })))))
      .get('/academician/courses/9', course({ id: 9 }));
    api.install();
    renderAcademician('/akademisyen/dersler?yeni=1');
    const user = userEvent.setup();
    const dlg = await screen.findByRole('dialog');
    await user.type(within(dlg).getByLabelText(/Ders adı/), 'Algoritmalar');
    await waitFor(() => expect(within(dlg).getByRole('option', { name: 'Bilgisayar Mühendisliği' })).toBeInTheDocument());
    await user.selectOptions(within(dlg).getByLabelText(/Bölüm/), 'Bilgisayar Mühendisliği');
    await user.click(within(dlg).getByLabelText(/Ders adı/));
    await user.keyboard('{Enter}'); // alt çubuktaki düğme forma `form=` ile bağlı; Enter gönderir
    await waitFor(() => expect(api.callsTo('POST', '/academician/courses')).toHaveLength(1));
    await user.keyboard('{Enter}');
    await user.click(within(dlg).getByRole('button', { name: 'Dersi oluştur' }));
    expect(api.callsTo('POST', '/academician/courses')).toHaveLength(1);
    release();
  });

  it('düğme forma bağlıdır (form özniteliği) ve planlanan ders sayısı 1-400 doğrulanır', async () => {
    const api = base().get('/academician/courses', []).post('/academician/courses', { ...course({ id: 9 }) }).get('/academician/courses/9', course({ id: 9 }));
    api.install();
    renderAcademician('/akademisyen/dersler?yeni=1');
    const user = userEvent.setup();
    const dlg = await screen.findByRole('dialog');
    const submit = within(dlg).getByRole('button', { name: 'Dersi oluştur' });
    expect(submit).toHaveAttribute('type', 'submit');
    expect(submit.getAttribute('form')).toBeTruthy();
    expect(document.getElementById(submit.getAttribute('form')!)?.tagName).toBe('FORM');
    await user.type(within(dlg).getByLabelText(/Ders adı/), 'X');
    await waitFor(() => expect(within(dlg).getByRole('option', { name: 'Bilgisayar Mühendisliği' })).toBeInTheDocument());
    await user.selectOptions(within(dlg).getByLabelText(/Bölüm/), 'Bilgisayar Mühendisliği');
    await user.type(within(dlg).getByLabelText('Dönemdeki toplam ders sayısı'), '401');
    await user.click(submit);
    expect(await within(dlg).findByText('1 ile 400 arasında bir tam sayı girin.')).toBeInTheDocument();
    expect(api.callsTo('POST', '/academician/courses')).toHaveLength(0);
    await user.clear(within(dlg).getByLabelText('Dönemdeki toplam ders sayısı'));
    await user.type(within(dlg).getByLabelText('Dönemdeki toplam ders sayısı'), '42');
    await user.click(submit);
    await waitFor(() => expect(api.callsTo('POST', '/academician/courses')).toHaveLength(1));
    expect(api.callsTo('POST', '/academician/courses')[0].body).toMatchObject({ plannedSessions: 42 });
  });

  it('AC_COURSE_LIMIT özel mesaj verir', async () => {
    base().get('/academician/courses', []).post('/academician/courses', () => err(422, 'AC_COURSE_LIMIT')).install();
    renderAcademician('/akademisyen/dersler?yeni=1');
    const user = userEvent.setup();
    const dlg = await screen.findByRole('dialog');
    await user.type(within(dlg).getByLabelText(/Ders adı/), 'X');
    await waitFor(() => expect(within(dlg).getByRole('option', { name: 'Bilgisayar Mühendisliği' })).toBeInTheDocument());
    await user.selectOptions(within(dlg).getByLabelText(/Bölüm/), 'Bilgisayar Mühendisliği');
    await user.click(within(dlg).getByRole('button', { name: 'Dersi oluştur' }));
    expect(await within(dlg).findByRole('alert')).toHaveTextContent('ders sayısı sınırına ulaşıldı');
  });
});

describe('W10: pano', () => {
  it('12\'den fazla aktif ders varsa kısaltıldığı söylenir ve tam listeye bağlantı verilir; bekleyen istek rozeti görünür', async () => {
    const many = Array.from({ length: 14 }, (_, i) => course({ id: 100 + i, name: `Ders ${i}`, code: null }));
    const api = base().get('/academician/courses', many);
    api.get('/academician/courses/:id/sessions', ({ url }) =>
      url.pathname.includes('/100/') ? [{ id: 5, courseId: 100, lessonDate: '2026-11-14', status: 'OPEN', presentCount: 1, enrolledCount: 3, pendingCount: 2, counted: true }] : [],
    );
    api.get('/academician/courses/:id/attendance', { sessions: [], students: [], limit: { type: null, value: null } });
    api.get('/academician/courses/:id/notices', { items: [], nextCursor: null });
    api.install();
    renderAcademician('/akademisyen');
    expect(await screen.findByText(/ilk 12 aktif dersi özetler \(14 aktif dersiniz var\)/)).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Tüm dersleri gör' })).toHaveAttribute('href', '/akademisyen/dersler');
    expect(await screen.findByText(/2 kayıtsız/)).toBeInTheDocument();
    // yalnız ilk 12 dersin ayrıntısı istenir
    expect(api.calls.filter((c) => /\/courses\/\d+\/sessions$/.test(c.path))).toHaveLength(12);
  });
});

describe('yoklama başlatma yanıtı', () => {
  async function start(resp: Record<string, unknown>, notifyChecked: boolean) {
    const api = base()
      .get('/academician/courses/7', course())
      .post('/academician/courses/7/sessions', () => new Response(JSON.stringify({ id: 5, courseId: 7, lessonDate: '2026-11-14', status: 'OPEN', presentCount: 0, enrolledCount: 3, ...resp }), { status: 201, headers: { 'Content-Type': 'application/json' } }))
      .get('/academician/sessions/5', { id: 5, courseId: 7, status: 'OPEN', lessonDate: '2026-11-14' })
      .get('/academician/sessions/5/live', () => err(404, 'X'));
    api.install();
    renderAcademician('/akademisyen/dersler/7');
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: 'Yoklama başlat' }));
    const dlg = await screen.findByRole('dialog');
    if (notifyChecked) await user.click(within(dlg).getByRole('checkbox', { name: /Öğrencilere bildirim gönder/ }));
    await user.click(within(dlg).getByRole('button', { name: 'Yoklamayı başlat' }));
    return api;
  }

  it('reused: var olan oturumun yeniden açıldığı söylenir', async () => {
    await start({ reused: true, notified: false }, false);
    expect(await screen.findByText(/var olan yoklama yeniden açıldı/)).toBeInTheDocument();
  });

  it('bildirim işaretli ama gitmediyse (notified:false) nedeni söylenir', async () => {
    const api = await start({ reused: false, notified: false }, true);
    expect(await screen.findByText(/Bildirim yeniden gönderilmedi/)).toBeInTheDocument();
    expect(api.callsTo('POST', '/academician/courses/7/sessions')[0].body).toMatchObject({ notify: true });
  });
});

describe('W12: CSV dosya adı', () => {
  it('Türkçe harfler ASCII\'ye çevrilir (ğ, ı, İ, ö, ş, ü, ç)', () => {
    expect(asciiSlug('Öğretim İlkeleri ve Yöntemleri')).toBe('ogretim-ilkeleri-ve-yontemleri');
    expect(asciiSlug('ÇAĞDAŞ Işık')).toBe('cagdas-isik');
    expect(csvFileName({ id: 3, code: null, name: 'Öğretim İlkeleri' })).toBe('devamsizlik-ogretim-ilkeleri.csv');
    expect(csvFileName({ id: 3, code: 'BİL 101', name: 'x' })).toBe('devamsizlik-bil-101.csv');
    expect(csvFileName({ id: 3, code: null, name: '???' })).toBe('devamsizlik-3.csv');
  });
});

describe('W5: sekmeler', () => {
  it('Program sekmesindeki kaydedilmemiş saat düzenlemesi sekme değişince kaybolmaz', async () => {
    base().get('/academician/courses/7', course()).get('/academician/courses/7/attendance', { sessions: [], students: [], limit: { type: null, value: null } }).install();
    renderAcademician('/akademisyen/dersler/7');
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: 'Saat ekle' }));
    fireEvent.change(screen.getByLabelText('Başlangıç'), { target: { value: '13:15' } });
    await user.click(screen.getByRole('tab', { name: 'Devamsızlık' }));
    await user.click(screen.getByRole('tab', { name: 'Program' }));
    expect(screen.getByLabelText('Başlangıç')).toHaveValue('13:15');
  });
});
