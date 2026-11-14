// Ek birim testleri: yoklama başlatma gövdesi, ders listesi süzgeci, profil, arşivle/etkinleştir/sil, W20 erişilebilir ad, W19/W21.
import { fireEvent, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it } from 'vitest';
import { tokensFor } from '../../auth/tokens';
import { APPROVED_ME, course, err, mockApi, renderAcademician, setAcadTokens } from './testUtils';

afterEach(() => tokensFor('acad').clearTokens());
const base = () => {
  setAcadTokens();
  return mockApi().get('/academician/me', APPROVED_ME);
};

describe('yoklama başlatma penceresi', () => {
  it('POST gövdesi tarih + saat + notify içerir', async () => {
    const withSlot = course({ slots: [{ id: 3, dayOfWeek: 1, startTime: '09:00', endTime: '09:50', room: 'A1' }] });
    const api = base()
      .get('/academician/courses/7', withSlot)
      .post('/academician/courses/7/sessions', () => new Response(JSON.stringify({ id: 5, courseId: 7, status: 'OPEN', lessonDate: '2026-11-14' }), { status: 201, headers: { 'Content-Type': 'application/json' } }))
      .get('/academician/sessions/5', { id: 5, courseId: 7, status: 'OPEN', lessonDate: '2026-11-14' })
      .get('/academician/sessions/5/live', () => err(404, 'X'));
    api.install();
    renderAcademician('/akademisyen/dersler/7');
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: 'Yoklama başlat' }));
    const dlg = await screen.findByRole('dialog');
    fireEvent.change(within(dlg).getByLabelText('Ders tarihi'), { target: { value: '2026-11-12' } });
    await user.selectOptions(within(dlg).getByLabelText('Ders saati'), '3');
    await user.click(within(dlg).getByRole('checkbox', { name: /bildirim gönder/i }));
    await user.click(within(dlg).getByRole('button', { name: 'Yoklamayı başlat' }));
    await waitFor(() => expect(api.callsTo('POST', '/academician/courses/7/sessions')).toHaveLength(1));
    expect(api.callsTo('POST', '/academician/courses/7/sessions')[0].body).toEqual({ lessonDate: '2026-11-12', slotId: 3, notify: true });
  });
});

describe('ders listesi ve ders işlemleri', () => {
  it('arama ve arşiv süzgeci; eşleşme yoksa sonraki eylem sunulur', async () => {
    base().get('/academician/courses', [course({ id: 1, name: 'Veri Yapıları' }), course({ id: 2, name: 'Eski Ders', code: null, status: 'ARCHIVED' })]).install();
    renderAcademician('/akademisyen/dersler');
    const user = userEvent.setup();
    expect(await screen.findByText(/Veri Yapıları/)).toBeInTheDocument();
    expect(screen.queryByText('Eski Ders')).toBeNull();
    await user.click(screen.getByRole('checkbox', { name: /Arşivlenenleri göster/ }));
    expect(screen.getByText('Eski Ders')).toBeInTheDocument();
    await user.type(screen.getByRole('searchbox'), 'zzz');
    expect(await screen.findByText('Eşleşen ders yok')).toBeInTheDocument();
  });

  it('arşivle onay ister; sil açık sonuç yazar ve DELETE gönderir', async () => {
    const api = base()
      .get('/academician/courses/7', course())
      .patch('/academician/courses/7', course({ status: 'ARCHIVED' }))
      .del('/academician/courses/7', undefined)
      .get('/academician/courses', []);
    api.install();
    renderAcademician('/akademisyen/dersler/7');
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: 'Arşivle' }));
    await user.click(within(await screen.findByRole('dialog')).getByRole('button', { name: 'Arşivle' }));
    await waitFor(() => expect(api.callsTo('PATCH', '/academician/courses/7')).toHaveLength(1));
    expect(api.callsTo('PATCH', '/academician/courses/7')[0].body).toEqual({ status: 'ARCHIVED' });
    await user.click(await screen.findByRole('button', { name: 'Sil' }));
    const dlg = await screen.findByRole('alertdialog');
    expect(dlg).toHaveTextContent('geri alınamaz');
    await user.click(within(dlg).getByRole('button', { name: 'Dersi sil' }));
    await waitFor(() => expect(api.callsTo('DELETE', '/academician/courses/7')).toHaveLength(1));
  });
});

describe('profil', () => {
  it('bilgiler PUT /me ile kaydedilir; hata olunca girdi korunur', async () => {
    let fail = true;
    const api = base().put('/academician/me', () => (fail ? err(403, 'ACADEMICIAN_REVOKED') : APPROVED_ME)).get('/academician/courses', []);
    api.install();
    renderAcademician('/akademisyen/profil');
    const user = userEvent.setup();
    const last = await screen.findByLabelText(/Soyad/);
    await user.clear(last);
    await user.type(last, 'Yeni');
    await user.click(screen.getByRole('button', { name: 'Kaydet' }));
    expect(await screen.findByText(/yeniden başvuru yapılamaz/)).toBeInTheDocument();
    expect(last).toHaveValue('Yeni');
    fail = false;
    await user.click(screen.getByRole('button', { name: 'Kaydet' }));
    await waitFor(() => expect(api.callsTo('PUT', '/academician/me')).toHaveLength(2));
  });
});

describe('erişilebilir adlar (WCAG 2.5.3) ve yerleşim kuralları', () => {
  it('W20: marka bağlantısının adı görünür metni içerir', async () => {
    base().get('/academician/courses', []).install();
    const { container } = renderAcademician('/akademisyen');
    await screen.findByRole('heading', { name: /Merhaba/ });
    const brand = container.querySelector('a[class*="brandLink"]') as HTMLElement;
    expect(brand.getAttribute('aria-label')).toBeNull(); // ad = görünür içerik
    expect(brand).toHaveTextContent('Akademisyen');
  });

  it('W19: saat kaldırma düğmesi görünür metin ve erişilebilir ad taşır', async () => {
    base().get('/academician/courses/7', course({ slots: [{ id: 1, dayOfWeek: 1, startTime: '09:00', endTime: '09:50', room: null }] })).install();
    renderAcademician('/akademisyen/dersler/7');
    const btn = await screen.findByRole('button', { name: 'Saati kaldır (1. satır)' });
    expect(btn).toHaveTextContent('Saati kaldır');
  });

  it('W21: zaten derste olan öğrenci için ölü onay kutusu yok; nedeni notta yazılır', async () => {
    const api = base()
      .get('/academician/courses/7', course())
      .get('/academician/courses/7/enrollments', [{ studentId: 21, displayName: 'Ali Aday', studentNo: '1', faculty: null, department: null, grade: null, addedAt: '2026-09-21T08:00:00Z' }])
      .get('/academician/students', { items: [{ id: 21, displayName: 'Ali Aday', studentNo: '1', faculty: null, department: 'X', grade: '1' }, { id: 22, displayName: 'Veli Aday', studentNo: '2', faculty: null, department: 'X', grade: '1' }], nextCursor: null })
      .get('/catalog/academic', { version: 1, faculties: [], grades: [] });
    api.install();
    renderAcademician('/akademisyen/dersler/7/ogrenciler/ekle');
    await userEvent.setup().type(await screen.findByRole('searchbox'), 'aday');
    await screen.findByText('Veli Aday', {}, { timeout: 4000 });
    expect(screen.queryByRole('checkbox', { name: 'Ali Aday öğrencisini seç' })).toBeNull();
    expect(screen.getByRole('status')).toHaveTextContent('zaten derste olduğu için seçilemez: Ali Aday');
  });
});
