// P13: bastırma listesi — maskeli liste, kullanıcının kendi çıkışını kaldırırken çift onay, elle ekleme.
import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import MailSuppressionPage from './MailSuppressionPage';

vi.setConfig({ testTimeout: 20000 });

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

interface Call {
  url: string;
  method: string;
  headers: Record<string, string>;
  body: unknown;
}

const FULL = 'ali.veli@bingol.edu.tr';
const row = (over: Record<string, unknown> = {}) => ({
  id: 7,
  emailMasked: 'a***@bingol.edu.tr',
  hashPrefix: 'abcdef1234',
  reason: 'UNSUBSCRIBED',
  category: 'ANNOUNCEMENT',
  note: null,
  createdAt: '2026-10-20T10:00:00Z',
  createdBy: null,
  userOptOut: true,
  ...over,
});
const detail = (over: Record<string, unknown> = {}) => ({
  ...row(),
  fullEmail: FULL,
  fullEmailResolved: true,
  userId: 42,
  removeMinReason: 20,
  removeNeedsConfirm: true,
  removeWarning: 'UNSUBSCRIBED',
  ...over,
});

function setup(items: ReturnType<typeof row>[], det: ReturnType<typeof detail>) {
  const calls: Call[] = [];
  mockFetch((url, init) => {
    const method = init.method ?? 'GET';
    calls.push({
      url,
      method,
      headers: (init.headers ?? {}) as Record<string, string>,
      body: init.body ? JSON.parse(String(init.body)) : undefined,
    });
    if (method === 'GET' && url.startsWith('/api/admin/mail/suppressions/')) return jsonResponse(200, det);
    if (method === 'GET' && url.startsWith('/api/admin/mail/suppressions')) {
      return jsonResponse(200, { items, page: 0, size: 20, total: items.length, totalPages: 1 });
    }
    if (method === 'DELETE') return jsonResponse(204);
    if (method === 'POST') return jsonResponse(201, row({ id: 99, reason: 'MANUAL', userOptOut: false }));
    return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
  });
  return calls;
}
const writes = (calls: Call[]) => calls.filter((c) => c.method !== 'GET');

describe('bastırma listesi', () => {
  it('adresleri maskeli gösterir, tam adresi hiç göstermez; özet satırını açıklar', async () => {
    setup([row(), row({ id: 8, emailMasked: null, reason: 'BOUNCED', userOptOut: false, hashPrefix: 'ffee001122' })], detail());
    renderWithProviders(<MailSuppressionPage />);
    expect(await screen.findByText('a***@bingol.edu.tr')).toBeInTheDocument();
    expect(screen.getByText('Kullanıcı kendisi çıktı')).toBeInTheDocument();
    expect(screen.getByText('Adres kayıtlı değil (özet ffee001122…)')).toBeInTheDocument();
    expect(screen.queryByText(FULL)).toBeNull();
    const table = within(screen.getByRole('table'));
    expect(table.getByText('Abonelikten çıktı')).toBeInTheDocument();
    expect(table.getByText('Teslim hatası')).toBeInTheDocument();
  });

  it('boş listede yönlendirir', async () => {
    setup([], detail());
    renderWithProviders(<MailSuppressionPage />);
    expect(await screen.findByText('Bastırılmış adres yok')).toBeInTheDocument();
  });
});

describe('kullanıcının kendi çıkışını kaldırma', () => {
  it('uyarı gösterir; e-posta yazılıp 20+ karakter sebep girilmeden onaylanmaz; başlıkla gider', async () => {
    const calls = setup([row()], detail());
    renderWithProviders(<MailSuppressionPage />);
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: /Ayrıntı/ }));
    const drawer = await screen.findByRole('dialog');
    expect(await within(drawer).findByText(FULL)).toBeInTheDocument();
    expect(within(drawer).getByText('Kullanıcı kendisi çıktı.')).toBeInTheDocument();
    await user.click(within(drawer).getByRole('button', { name: 'Listeden kaldır' }));

    const dialog = await screen.findByRole('alertdialog');
    const confirm = within(dialog).getByRole('button', { name: 'Listeden kaldır' });
    expect(confirm).toBeDisabled();
    // kısa sebep + doğru e-posta: yine kapalı
    await user.type(within(dialog).getByLabelText(/Sebep/), 'on dokuz karakter!!');
    await user.type(within(dialog).getByLabelText('Onay metni'), FULL);
    expect(confirm).toBeDisabled();
    // uzun sebep, yanlış e-posta: kapalı
    await user.type(within(dialog).getByLabelText(/Sebep/), ' ve devamı');
    await user.clear(within(dialog).getByLabelText('Onay metni'));
    await user.type(within(dialog).getByLabelText('Onay metni'), 'baska@bingol.edu.tr');
    expect(confirm).toBeDisabled();
    // doğru: açık
    await user.clear(within(dialog).getByLabelText('Onay metni'));
    await user.type(within(dialog).getByLabelText('Onay metni'), FULL);
    expect(confirm).toBeEnabled();
    expect(writes(calls)).toHaveLength(0);

    await user.click(confirm);
    await waitFor(() => expect(writes(calls)).toHaveLength(1));
    const del = writes(calls)[0];
    expect(del.method).toBe('DELETE');
    expect(del.url).toBe('/api/admin/mail/suppressions/7');
    expect(del.headers['X-Admin-Confirm']).toBe('7');
    expect(decodeURIComponent(del.headers['X-Admin-Reason'])).toBe('on dokuz karakter!! ve devamı');
  });

  it('adres çözülemezse özet ön ekini yazdırır', async () => {
    const calls = setup([row()], detail({ fullEmail: null, fullEmailResolved: false, userId: null }));
    renderWithProviders(<MailSuppressionPage />);
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: /Ayrıntı/ }));
    const drawer = await screen.findByRole('dialog');
    expect(await within(drawer).findByText(/Tam adres gösterilemiyor/)).toBeInTheDocument();
    await user.click(within(drawer).getByRole('button', { name: 'Listeden kaldır' }));
    const dialog = await screen.findByRole('alertdialog');
    await user.type(within(dialog).getByLabelText(/Sebep/), 'Kullanıcı yazılı olarak istedi');
    await user.type(within(dialog).getByLabelText('Onay metni'), 'abcdef1234');
    await user.click(within(dialog).getByRole('button', { name: 'Listeden kaldır' }));
    await waitFor(() => expect(writes(calls)).toHaveLength(1));
  });
});

describe('teslim hatası kaldırma', () => {
  it('yalnız kısa sebep ister; onay başlığı gitmez', async () => {
    const calls = setup(
      [row({ reason: 'BOUNCED', userOptOut: false })],
      detail({ reason: 'BOUNCED', userOptOut: false, removeMinReason: 5, removeNeedsConfirm: false, removeWarning: null }),
    );
    renderWithProviders(<MailSuppressionPage />);
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: /Ayrıntı/ }));
    const drawer = await screen.findByRole('dialog');
    await within(drawer).findByText(FULL);
    expect(within(drawer).queryByText('Kullanıcı kendisi çıktı.')).toBeNull();
    await user.click(within(drawer).getByRole('button', { name: 'Listeden kaldır' }));
    const dialog = await screen.findByRole('alertdialog');
    expect(within(dialog).queryByLabelText('Onay metni')).toBeNull();
    const confirm = within(dialog).getByRole('button', { name: 'Listeden kaldır' });
    expect(confirm).toBeDisabled();
    await user.type(within(dialog).getByLabelText(/Sebep/), 'adres düzeltildi');
    expect(confirm).toBeEnabled();
    await user.click(confirm);
    await waitFor(() => expect(writes(calls)).toHaveLength(1));
    expect(writes(calls)[0].headers['X-Admin-Confirm']).toBeUndefined();
  });
});

describe('elle ekleme', () => {
  it('geçersiz e-posta ya da kısa gerekçede gönderilmez; geçerliyse MANUAL olarak gider', async () => {
    const calls = setup([], detail());
    renderWithProviders(<MailSuppressionPage />);
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: 'Adres ekle' }));
    const modal = await screen.findByRole('dialog');
    const submit = within(modal).getByRole('button', { name: 'Bastır' });
    expect(submit).toBeDisabled();
    await user.type(within(modal).getByLabelText(/E-posta adresi/), 'yok');
    await user.type(within(modal).getByLabelText(/Gerekçe/), 'Kullanıcı telefonla istedi');
    expect(submit).toBeDisabled();
    await user.clear(within(modal).getByLabelText(/E-posta adresi/));
    await user.type(within(modal).getByLabelText(/E-posta adresi/), 'misafir@example.com');
    expect(submit).toBeEnabled();
    await user.click(submit);
    await waitFor(() => expect(writes(calls)).toHaveLength(1));
    expect(writes(calls)[0].body).toEqual({
      email: 'misafir@example.com',
      reason: 'MANUAL',
      note: 'Kullanıcı telefonla istedi',
    });
  });
});
