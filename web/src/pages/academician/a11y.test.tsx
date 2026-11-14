// Erişilebilirlik (axe) ve kapsam yalıtımı: akademisyen ekranları; panel yolu site dil önekini almaz.
import { screen, waitFor } from '@testing-library/react';
import axe from 'axe-core';
import { afterEach, describe, expect, it } from 'vitest';
import { tokensFor } from '../../auth/tokens';
import { APPROVED_ME, course, mockApi, renderAcademician, setAcadTokens } from './testUtils';

async function violations(container: HTMLElement) {
  const res = await axe.run(container, { rules: { 'color-contrast': { enabled: false }, region: { enabled: false } } });
  return res.violations.map((v) => `${v.id}: ${v.nodes.map((n) => n.target.join(' ')).join(' | ')}`);
}
afterEach(() => tokensFor('acad').clearTokens());

const matrix = { sessions: [{ id: 5, lessonDate: '2026-11-10' }], students: [{ studentId: 11, displayName: 'Ayşe Örnek', studentNo: '2024000011', marks: { '5': 'PRESENT_QR' }, absentCount: 0, atRisk: false, overLimit: false }], limit: { type: null, value: null } };

describe('erisilebilirlik (akademisyen paneli)', () => {
  it('giris: ihlal yok', async () => {
    mockApi().install();
    const { container } = renderAcademician('/akademisyen/giris');
    await screen.findByRole('heading', { name: 'Akademisyen girişi' });
    expect(await violations(container)).toEqual([]);
  });

  it('kayit: ihlal yok', async () => {
    mockApi().install();
    const { container } = renderAcademician('/akademisyen/kayit');
    await screen.findByRole('heading', { name: 'Akademisyen kaydı' });
    expect(await violations(container)).toEqual([]);
  });

  it('pano ve ders listesi: ihlal yok; panel bağlantıları /tr önekini almaz', async () => {
    setAcadTokens();
    mockApi().get('/academician/me', APPROVED_ME).get('/academician/courses', [course()]).get('/academician/courses/7/sessions', []).get('/academician/courses/7/attendance', matrix).get('/academician/courses/7/notices', { items: [], nextCursor: null }).install();
    const { container } = renderAcademician('/akademisyen');
    await screen.findByRole('heading', { name: /Merhaba/ });
    await waitFor(() => expect(container.querySelector('a[href*="/dersler"]')).not.toBeNull());
    expect([...container.querySelectorAll('a')].every((a) => !a.getAttribute('href')?.startsWith('/tr/akademisyen'))).toBe(true);
    expect(await violations(container)).toEqual([]);
  });

  it('ders ayrıntısı (devamsızlık sekmesi): ihlal yok', async () => {
    setAcadTokens();
    mockApi().get('/academician/me', APPROVED_ME).get('/academician/courses/7', course()).get('/academician/courses/7/attendance', matrix).install();
    const { container } = renderAcademician('/akademisyen/dersler/7?sekme=devamsizlik');
    await screen.findAllByRole('table');
    expect(await violations(container)).toEqual([]);
  });
});
