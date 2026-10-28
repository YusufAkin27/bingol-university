import { fireEvent, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { useState } from 'react';
import { Route, Routes } from 'react-router-dom';
import { describe, expect, it } from 'vitest';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import LegalAdminPage from './LegalAdminPage';
import ReportsPage from './ReportsPage';
import TicketDetailPage from './TicketDetailPage';
import { MarkdownEditor } from './content/MarkdownEditor';
import { TEMPLATES_KEY } from './support/supportLogic';

function Harness({ initial = '' }: { initial?: string }) {
  const [v, setV] = useState(initial);
  return (
    <>
      <MarkdownEditor id="ed" value={v} onChange={setV} aria-label="editor" />
      <output data-testid="out">{v}</output>
    </>
  );
}

describe('MarkdownEditor araç çubuğu', () => {
  it('seçimi kalın yapar, başlık ve liste öneki ekler', async () => {
    renderWithProviders(<Harness initial="merhaba" />);
    const area = screen.getByLabelText('editor') as HTMLTextAreaElement;
    area.focus();
    area.setSelectionRange(0, 7);
    await userEvent.click(screen.getByRole('button', { name: 'Kalın' }));
    expect(screen.getByTestId('out')).toHaveTextContent('**merhaba**');
    await userEvent.click(screen.getByRole('button', { name: 'Başlık' }));
    expect(screen.getByTestId('out').textContent).toBe('## **merhaba**');
    await userEvent.click(screen.getByRole('button', { name: 'Liste' }));
    expect(screen.getByTestId('out').textContent).toBe('- ## **merhaba**');
  });
  it('Ctrl+B kısayolu çalışır', () => {
    renderWithProviders(<Harness initial="ab" />);
    const area = screen.getByLabelText('editor') as HTMLTextAreaElement;
    area.setSelectionRange(0, 2);
    fireEvent.keyDown(area, { key: 'b', ctrlKey: true });
    expect(screen.getByTestId('out').textContent).toBe('**ab**');
  });
});

describe('Raporlar sayfası', () => {
  it('askıya almada neden ister, onay penceresinden sonra kararı gönderir', async () => {
    let open = true;
    const calls: { url: string; init: RequestInit }[] = [];
    mockFetch((url, init) => {
      calls.push({ url, init });
      if (url.includes('/admin/reports/') && init.method === 'POST') {
        open = false;
        return jsonResponse(204);
      }
      if (url.includes('/admin/reports')) {
        return jsonResponse(200, {
          items: open
            ? [
                { id: 11, reporterId: 3, targetType: 'USER', targetId: 7, reason: 'SPAM', note: 'reklam', status: 'OPEN', resolution: null, createdAt: '2026-01-01T10:00:00Z' },
              ]
            : [],
          nextCursor: null,
        });
      }
      if (url.includes('/admin/users/7')) {
        return jsonResponse(200, {
          id: 7, email: 'x@bingol.edu.tr', displayName: 'Ali Veli', status: 'ACTIVE', counts: { reportsAgainst: 2 },
        });
      }
      return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
    });
    renderWithProviders(<ReportsPage />, { route: '/admin/reports' });

    await screen.findByText('reklam', { selector: 'span' });
    await screen.findByText('Ali Veli');
    await userEvent.click(screen.getByRole('radio', { name: /Kullanıcıyı askıya al/ }));
    await userEvent.click(screen.getByRole('button', { name: 'Kararı uygula' }));
    expect(await screen.findByText('Askıya almak için bir neden yazın.')).toBeInTheDocument();
    expect(screen.queryByRole('dialog')).toBeNull();

    await userEvent.type(screen.getByRole('textbox', { name: /Askıya alma nedeni/ }), 'spam hesabı');
    await userEvent.click(screen.getByRole('button', { name: 'Kararı uygula' }));
    const dialog = await screen.findByRole('dialog');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Kullanıcıyı askıya al' }));

    await waitFor(() => {
      const post = calls.find((c) => c.init.method === 'POST');
      expect(post?.url).toContain('/admin/reports/11/resolve');
      expect(JSON.parse(String(post?.init.body))).toEqual({ action: 'SUSPEND_USER', message: 'spam hesabı' });
    });
    expect(await screen.findByText('Bekleyen rapor yok')).toBeInTheDocument();
  });

  it('j/k ile raporlar arasında gezilir', async () => {
    const mk = (id: number, targetId: number) => ({
      id, reporterId: 1, targetType: 'POST', targetId, reason: 'OTHER', note: `not-${id}`, status: 'OPEN', resolution: null, createdAt: '2026-01-01T10:00:00Z',
    });
    mockFetch(() => jsonResponse(200, { items: [mk(1, 100), mk(2, 200)], nextCursor: null }));
    renderWithProviders(<ReportsPage />);
    await screen.findAllByText('not-1');
    const first = document.getElementById('report-1');
    const second = document.getElementById('report-2');
    await waitFor(() => expect(first).toHaveAttribute('aria-current', 'true'));
    await userEvent.keyboard('j');
    expect(second).toHaveAttribute('aria-current', 'true');
    await userEvent.keyboard('k');
    expect(first).toHaveAttribute('aria-current', 'true');
  });
});

describe('Talep ayrıntısı', () => {
  const detail = (status: 'OPEN' | 'ANSWERED', extra: unknown[] = []) => ({
    ticket: { id: 5, category: 'TECHNICAL', subject: 'Giriş sorunu', status, createdAt: '2026-01-01T10:00:00Z', updatedAt: '2026-01-01T10:00:00Z' },
    messages: [{ id: 1, fromStaff: false, text: 'Giremiyorum', createdAt: '2026-01-01T10:00:00Z' }, ...extra],
  });

  function renderDetail() {
    return renderWithProviders(
      <Routes>
        <Route path="/admin/support/tickets/:id" element={<TicketDetailPage />} />
      </Routes>,
      { route: '/admin/support/tickets/5' },
    );
  }

  it('yanıtı Ctrl+Enter ile gönderir ve sohbete ekler', async () => {
    const calls: { url: string; init: RequestInit }[] = [];
    mockFetch((url, init) => {
      calls.push({ url, init });
      if (url.endsWith('/reply')) {
        return jsonResponse(200, detail('ANSWERED', [{ id: 2, fromStaff: true, text: 'Deneyin', createdAt: '2026-01-01T11:00:00Z' }]));
      }
      return jsonResponse(200, detail('OPEN'));
    });
    renderDetail();
    await screen.findByText('Giremiyorum');
    const box = screen.getByLabelText('Yanıtınız');
    await userEvent.type(box, 'Deneyin');
    expect(screen.getByText('7 / 2000')).toBeInTheDocument();
    await userEvent.keyboard('{Control>}{Enter}{/Control}');
    expect(await screen.findByText('Yanıtlandı')).toBeInTheDocument();
    const post = calls.find((c) => c.url.endsWith('/reply'));
    expect(JSON.parse(String(post?.init.body))).toEqual({ text: 'Deneyin' });
    expect(screen.getAllByText('Deneyin').length).toBeGreaterThan(0);
  });

  it('hazır yanıtı ekler, saklar, yanıta yerleştirir ve siler', async () => {
    mockFetch(() => jsonResponse(200, detail('OPEN')));
    renderDetail();
    await screen.findByText('Giremiyorum');
    await userEvent.type(screen.getByPlaceholderText('Yeni hazır yanıt metni…'), 'Merhaba, inceliyoruz.');
    await userEvent.click(screen.getByRole('button', { name: 'Şablon ekle' }));
    expect(window.localStorage.getItem(TEMPLATES_KEY)).toContain('Merhaba, inceliyoruz.');
    await userEvent.click(screen.getByRole('button', { name: /Yanıta ekle/ }));
    expect((screen.getByLabelText('Yanıtınız') as HTMLTextAreaElement).value).toBe('Merhaba, inceliyoruz.');
    await userEvent.click(screen.getByRole('button', { name: 'Şablonu sil' }));
    expect(JSON.parse(window.localStorage.getItem(TEMPLATES_KEY) ?? '[]')).toEqual([]);
  });
});

describe('Sözleşme editörü', () => {
  it('özet penceresinden sonra yalnızca dolu dilleri yayınlar', async () => {
    const calls: { url: string; init: RequestInit }[] = [];
    mockFetch((url, init) => {
      calls.push({ url, init });
      if (init.method === 'POST') return jsonResponse(200, { version: 3 });
      if (url.includes('/versions')) return jsonResponse(200, [{ version: 2, lang: 'tr', title: 'Eski', content: 'eski metin', requireReaccept: true, active: true, publishedAt: '2026-01-01T00:00:00Z' }]);
      if (url.includes('acceptance-stats')) return jsonResponse(200, [{ type: 'TERMS', version: 2, accepted: 1, totalActiveUsers: 4 }]);
      return jsonResponse(200, []);
    });
    renderWithProviders(<LegalAdminPage />);
    await screen.findByText('Eski');
    await userEvent.click(screen.getByRole('tab', { name: /Yeni sürüm/ }));

    await userEvent.type(screen.getByRole('textbox', { name: /^Başlık/ }), 'Yeni başlık');
    fireEvent.change(document.getElementById('legal-content') as HTMLTextAreaElement, {
      target: { value: '## Madde\nTASLAK metin' },
    });

    await userEvent.click(screen.getByRole('switch', { name: /yeniden onay/i }));
    await userEvent.click(screen.getAllByRole('button', { name: 'Yayınla' })[0]);
    const dialog = await screen.findByRole('alertdialog');
    expect(within(dialog).getByText(/geri alınamaz/)).toBeInTheDocument();
    expect(within(dialog).getByText('İstenmeyecek')).toBeInTheDocument();
    expect(within(dialog).getByTestId('legal-impact')).toHaveTextContent('mevcut onaylar geçerli kalır');
    // yazılı onay: "YAYINLA v3" yazılmadan yayın düğmesi kapalı, istek gitmez
    const publish = within(dialog).getByRole('button', { name: 'Yayınla' });
    expect(publish).toBeDisabled();
    const typeBox = within(dialog).getAllByRole('textbox')[1];
    await userEvent.type(typeBox, 'yayınla v2');
    expect(publish).toBeDisabled();
    expect(calls.some((c) => c.init.method === 'POST')).toBe(false);
    await userEvent.clear(typeBox);
    await userEvent.type(typeBox, 'YAYINLA v3');
    expect(publish).toBeDisabled(); // yazılı onay tamam ama sebep yok
    await userEvent.type(within(dialog).getAllByRole('textbox')[0], 'Hukuk incelemesi sonrası');
    expect(publish).toBeEnabled();
    await userEvent.click(publish);

    await waitFor(() => expect(calls.some((c) => c.init.method === 'POST')).toBe(true));
    const post = calls.find((c) => c.init.method === 'POST')!;
    expect(post.url).toContain('/admin/legal/TERMS');
    expect(JSON.parse(String(post.init.body))).toEqual({
      tr: { title: 'Yeni başlık', content: '## Madde\nTASLAK metin' },
      requireReaccept: false,
    });
    expect(decodeURIComponent((post.init.headers as Record<string, string>)['X-Admin-Reason'])).toBe(
      'Hukuk incelemesi sonrası',
    );
    expect((post.init.headers as Record<string, string>)['Idempotency-Key']).toBeTruthy();
  });

  it('yeniden onay açıkken kaç kullanıcının etkileneceğini gösterir', async () => {
    mockFetch((url) => {
      if (url.includes('/versions')) return jsonResponse(200, []);
      if (url.includes('acceptance-stats')) return jsonResponse(200, [{ type: 'TERMS', version: 1, accepted: 1, totalActiveUsers: 4 }]);
      return jsonResponse(200, []);
    });
    renderWithProviders(<LegalAdminPage />);
    await userEvent.click(screen.getByRole('tab', { name: /Yeni sürüm/ }));
    await userEvent.type(screen.getByRole('textbox', { name: /^Başlık/ }), 'Başlık');
    fireEvent.change(document.getElementById('legal-content') as HTMLTextAreaElement, { target: { value: 'metin' } });
    await userEvent.click(screen.getAllByRole('button', { name: 'Yayınla' })[0]);
    const dialog = await screen.findByRole('alertdialog');
    await waitFor(() => expect(within(dialog).getByTestId('legal-impact')).toHaveTextContent('4 etkin kullanıcının'));
    expect(within(dialog).getByTestId('legal-impact')).toHaveTextContent('1 kullanıcı');
  });

  it('yarım doldurulmuş dilde yayın penceresi açılmaz', async () => {
    mockFetch(() => jsonResponse(200, []));
    renderWithProviders(<LegalAdminPage />);
    await userEvent.click(screen.getByRole('tab', { name: /Yeni sürüm/ }));
    await userEvent.type(screen.getByRole('textbox', { name: /^Başlık/ }), 'Başlık');
    fireEvent.change(document.getElementById('legal-content') as HTMLTextAreaElement, { target: { value: 'metin' } });
    await userEvent.click(screen.getByRole('tab', { name: /İngilizce/ }));
    await userEvent.type(screen.getByRole('textbox', { name: /^Başlık/ }), 'Only title');
    await userEvent.click(screen.getAllByRole('button', { name: 'Yayınla' })[0]);
    expect(await screen.findByText(/İngilizce için başlık ve içeriği birlikte/)).toBeInTheDocument();
    expect(screen.queryByRole('dialog')).toBeNull();
  });
});
