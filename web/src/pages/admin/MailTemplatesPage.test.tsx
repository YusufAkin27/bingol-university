import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { Route, Routes } from 'react-router-dom';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import MailTemplatesPage from './MailTemplatesPage';

vi.setConfig({ testTimeout: 20000 });

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

const row = (id: number, over: Record<string, unknown> = {}) => ({
  id,
  name: `Şablon ${id}`,
  description: null,
  category: 'ANNOUNCEMENT',
  status: 'PUBLISHED',
  version: 2,
  languages: ['tr', 'en'],
  updatedAt: '2026-10-28T10:00:00Z',
  ...over,
});
const view = (over: Record<string, unknown> = {}) => ({
  ...row(7),
  tr: { subject: 'Merhaba {{ad}}', html: '<p>Selam</p>', text: null },
  en: null,
  ar: null,
  variablesUsed: ['ad'],
  createdBy: 1,
  createdAt: '2026-10-28T10:00:00Z',
  ...over,
});
const VARS = {
  variables: [
    { name: 'ad', placeholder: '{{ad}}', description: 'Ad', automatic: false },
    { name: 'bolum', placeholder: '{{bolum}}', description: 'Bölüm', automatic: false },
  ],
  maxHtmlLength: 100000,
  maxSubjectLength: 200,
};

function renderPage(route: string) {
  return renderWithProviders(
    <Routes>
      <Route path="/admin/mail/templates" element={<MailTemplatesPage />} />
      <Route path="/admin/mail/templates/:id" element={<MailTemplatesPage />} />
    </Routes>,
    { route },
  );
}

describe('şablon listesi', () => {
  it('satırları ve durumu gösterir; süzgeç sorguya gider', async () => {
    const calls: string[] = [];
    mockFetch((url) => {
      calls.push(url);
      if (url.includes('/admin/mail/templates')) {
        return jsonResponse(200, {
          items: [row(1), row(2, { status: 'DRAFT', languages: ['tr'], name: 'Taslak şablon' })],
          page: 0,
          totalPages: 1,
          totalItems: 2,
        });
      }
      return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
    });
    const user = userEvent.setup();
    renderPage('/admin/mail/templates');
    expect(await screen.findByText('Taslak şablon')).toBeInTheDocument();
    expect(screen.getAllByText('Yayında').length).toBeGreaterThan(0);
    await user.selectOptions(screen.getByLabelText('Durum'), 'DRAFT');
    await waitFor(() => expect(calls.some((u) => u.includes('status=DRAFT'))).toBe(true));
  });

  it('boş listede yönlendirici boş durum gösterir', async () => {
    mockFetch(() => jsonResponse(200, { items: [], page: 0, totalPages: 0, totalItems: 0 }));
    renderPage('/admin/mail/templates');
    expect(await screen.findByText('Henüz şablon yok')).toBeInTheDocument();
  });

  it('hatada çevrilmiş hata ve tekrar dene gösterir', async () => {
    mockFetch(() => jsonResponse(503, { code: 'MAIL_UNAVAILABLE', message: 'x' }));
    renderPage('/admin/mail/templates');
    expect(await screen.findByText(/E-posta sistemi şu an kullanılamıyor/)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Tekrar dene' })).toBeInTheDocument();
  });
});

describe('şablon editörü', () => {
  function setup(extra?: (url: string, init: RequestInit) => Response | undefined) {
    const calls: { url: string; init: RequestInit }[] = [];
    mockFetch((url, init) => {
      calls.push({ url, init });
      const x = extra?.(url, init);
      if (x) return x;
      if (url.endsWith('/admin/mail/variables')) return jsonResponse(200, VARS);
      if (url.endsWith('/templates/preview'))
        return jsonResponse(200, {
          lang: 'tr',
          usedLang: 'tr',
          fallback: false,
          subject: 'Merhaba Ayşe',
          html: '<!DOCTYPE html><p>tam belge</p>',
          text: 't',
          sampleVariables: {},
        });
      if (url.endsWith('/templates/7')) return jsonResponse(200, view());
      if (url.endsWith('/templates/7/versions'))
        return jsonResponse(200, [{ version: 1, createdBy: 1, createdAt: '2026-10-28T10:00:00Z' }]);
      return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
    });
    return calls;
  }
  const isCreate = (c: { url: string; init: RequestInit }) =>
    c.init.method === 'POST' && c.url.endsWith('/admin/mail/templates');

  it('boş formda kaydetmeyi engeller ve zorunlu alan hatalarını gösterir', async () => {
    const calls = setup();
    const user = userEvent.setup();
    renderPage('/admin/mail/templates/new');
    await user.click(screen.getByRole('button', { name: 'Şablonu oluştur' }));
    expect((await screen.findAllByText('Bu alan zorunlu.')).length).toBeGreaterThanOrEqual(2);
    expect(calls.some(isCreate)).toBe(false);
  });

  it('değişken ekler, önizlemeyi sandbox iframe içinde gösterir', async () => {
    setup();
    const user = userEvent.setup();
    renderPage('/admin/mail/templates/new');
    await user.type(screen.getByLabelText(/^Konu/), 'Selam');
    const html = screen.getByLabelText(/^HTML içerik/);
    await user.click(html);
    await user.type(html, 'Merhaba ');
    await user.click(await screen.findByRole('button', { name: '{{ad}}' }));
    expect(html).toHaveValue('Merhaba {{ad}}');
    const frame = await screen.findByTitle('E-posta önizlemesi', undefined, { timeout: 4000 });
    expect(frame).toHaveAttribute('sandbox', '');
    expect(frame).toHaveAttribute('srcdoc', expect.stringContaining('tam belge'));
    expect(await screen.findByText('Merhaba Ayşe')).toBeInTheDocument();
  });

  it('en/ar boşken Türkçe gönderilir uyarısı gösterir', async () => {
    setup();
    renderPage('/admin/mail/templates/7');
    expect(await screen.findByText(/EN, AR içeriği boş/)).toBeInTheDocument();
  });

  it('oluşturur: geçerli form POST eder, boş diller null gider', async () => {
    const calls = setup((url, init) =>
      init.method === 'POST' && url.endsWith('/admin/mail/templates') ? jsonResponse(201, view({ id: 9 })) : undefined,
    );
    const user = userEvent.setup();
    renderPage('/admin/mail/templates/new');
    await user.type(screen.getByLabelText(/^Şablon adı/), 'Yeni');
    await user.type(screen.getByLabelText(/^Konu/), 'Konu');
    await user.click(screen.getByLabelText(/^HTML içerik/));
    await user.paste('<p>x</p>');
    await user.click(screen.getByRole('button', { name: 'Şablonu oluştur' }));
    await waitFor(() => expect(calls.some(isCreate)).toBe(true));
    const post = calls.find(isCreate);
    const body = JSON.parse(String(post?.init.body)) as { name: string; en: unknown; tr: { subject: string } };
    expect(body.name).toBe('Yeni');
    expect(body.en).toBeNull();
    expect(body.tr.subject).toBe('Konu');
  });

  it('yayınla onay ister; sunucu hata kodu çevrilmiş gösterilir', async () => {
    setup((url, init) => {
      if (init.method === 'POST' && url.endsWith('/templates/7/publish'))
        return jsonResponse(400, { code: 'MAIL_TEMPLATE_INVALID', message: 'Geçersiz alan: html' });
      if (url.endsWith('/templates/7') && (init.method ?? 'GET') === 'GET') return jsonResponse(200, view({ status: 'DRAFT' }));
      return undefined;
    });
    const user = userEvent.setup();
    renderPage('/admin/mail/templates/7');
    const publish = await screen.findByRole('button', { name: 'Yayınla' });
    await waitFor(() => expect(publish).toBeEnabled());
    await user.click(publish);
    const dlg = await screen.findByRole('dialog');
    expect(within(dlg).getByText('Şablon yayınlansın mı?')).toBeInTheDocument();
    await user.click(within(dlg).getByRole('button', { name: 'Yayınla' }));
    expect((await screen.findAllByText(/Şablon içeriği geçersiz: Geçersiz alan: html/)).length).toBeGreaterThan(0);
  });

  it('silme çakışmasında (kullanımda) çevrilmiş mesaj gösterir', async () => {
    setup((_url, init) =>
      init.method === 'DELETE' ? jsonResponse(409, { code: 'MAIL_TEMPLATE_IN_USE', message: 'x' }) : undefined,
    );
    const user = userEvent.setup();
    renderPage('/admin/mail/templates/7');
    await user.click(await screen.findByRole('button', { name: 'Sil' }));
    const dlg = await screen.findByRole('dialog');
    await user.click(within(dlg).getByRole('button', { name: 'Sil' }));
    expect((await screen.findAllByText(/arşivleyin/)).length).toBeGreaterThan(0);
  });
});
