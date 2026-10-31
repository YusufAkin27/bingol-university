import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import PostsAdminPage from './PostsAdminPage';
import { excerpt, mediaToLightbox, postStatus, postTextError } from './posts/postsLogic';

const author = { id: 7, displayName: 'Ayse Yilmaz', email: 'ayse@bingol.edu.tr', avatarUrl: null };
const post = (id: number, over: Record<string, unknown> = {}) => ({
  id,
  author,
  text: `gonderi-${id}`,
  media: [],
  likeCount: 3,
  mediaCount: 0,
  hidden: false,
  deleted: false,
  hiddenReason: null,
  createdAt: '2026-02-01T10:00:00Z',
  editedAt: null,
  hiddenAt: null,
  deletedAt: null,
  deletedBy: null,
  openReportCount: 0,
  ...over,
});
const withMedia = {
  media: [
    { id: 5, kind: 'IMAGE', url: '/api/admin/posts/media/5', thumbUrl: '/api/admin/posts/media/5?thumb=true', width: 10, height: 10, durationMs: null, hidden: false },
  ],
  mediaCount: 1,
};
const counts = { postCount: 12, likeCount: 99, mediaCount: 8, hiddenCount: 2, deletedCount: 1 };

interface Call {
  method: string;
  url: string;
  body?: unknown;
  headers?: Record<string, string>;
}

function setup(opts: { listError?: boolean } = {}) {
  const calls: Call[] = [];
  mockFetch((url, init) => {
    const method = init.method ?? 'GET';
    calls.push({
      method,
      url,
      body: init.body ? JSON.parse(String(init.body)) : undefined,
      headers: init.headers as Record<string, string> | undefined,
    });
    if (url.includes('/admin/posts/media/')) return new Response(new Blob(['x']), { status: 200, headers: { 'Content-Type': 'image/jpeg' } });
    if (url.includes('/admin/posts/stats')) return jsonResponse(200, { ...counts, openReportedCount: 3, last24h: { ...counts, postCount: 4 } });
    if (/\/admin\/posts\/1\/(hide|unhide)/.test(url)) return jsonResponse(200, post(1, { hidden: url.endsWith('/hide') }));
    if (method === 'PATCH' && /\/admin\/posts\/1$/.test(url)) return jsonResponse(200, post(1, { text: 'yeni', editedAt: '2026-02-04T10:00:00Z' }));
    if (method === 'DELETE') return new Response(null, { status: 204 });
    if (/\/admin\/posts\/1$/.test(url)) {
      return jsonResponse(200, {
        post: post(1, { ...withMedia, openReportCount: 1 }),
        reports: [{ id: 9, reason: 'SPAM', note: 'reklam', status: 'OPEN', createdAt: '2026-02-01T12:00:00Z' }],
      });
    }
    if (url.includes('/admin/posts')) {
      if (opts.listError) return jsonResponse(500, { code: 'X', message: 'x' });
      if (url.includes('cursor=1')) return jsonResponse(200, { items: [post(0 + 9)], nextCursor: null });
      return jsonResponse(200, {
        items: [post(1, withMedia), post(2, { hidden: true, hiddenReason: 'spam', hiddenAt: '2026-02-02T10:00:00Z', openReportCount: 2 }), post(3, { deleted: true, deletedAt: '2026-02-03T10:00:00Z' })],
        nextCursor: url.includes('status=HIDDEN') ? null : 1,
      });
    }
    return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
  });
  return calls;
}

beforeEach(() => {
  vi.stubGlobal('URL', Object.assign(URL, { createObjectURL: () => 'blob:test', revokeObjectURL: () => {} }));
});
afterEach(() => vi.unstubAllGlobals());

describe('postsLogic', () => {
  it('excerpt flattens and truncates', () => {
    expect(excerpt(null)).toBe('');
    expect(excerpt('a\n  b')).toBe('a b');
    expect(excerpt('x'.repeat(300), 10)).toBe(`${'x'.repeat(10)}…`);
  });
  it('postStatus prefers deleted over hidden', () => {
    expect(postStatus({ hidden: true, deleted: true })).toBe('deleted');
    expect(postStatus({ hidden: true, deleted: false })).toBe('hidden');
    expect(postStatus({ hidden: false, deleted: false })).toBe('visible');
  });
  it('postTextError mirrors the server format rule', () => {
    expect(postTextError('')).toBeNull();
    expect(postTextError('  guzel bir gun  ')).toBeNull();
    expect(postTextError('bir iki uc dort bes alti yedi')).toBeNull();
    expect(postTextError('bir iki uc dort bes alti yedi sekiz')).toBe('tooLong');
    expect(postTextError('x'.repeat(61))).toBe('tooLong');
    expect(postTextError('iki\nsatir')).toBe('newline');
  });
  it('mediaToLightbox maps admin media urls', () => {
    const items = mediaToLightbox(post(1, withMedia) as never);
    expect(items).toHaveLength(1);
    expect(items[0].previewUrl).toBe('/api/admin/posts/media/5');
    expect(items[0].senderName).toBe('Ayse Yilmaz');
  });
});

describe('PostsAdminPage', () => {
  it('shows stats, rows, status badges and loads more', async () => {
    const calls = setup();
    renderWithProviders(<PostsAdminPage />);
    const rows = await screen.findAllByTestId('post-row');
    expect(rows).toHaveLength(3);
    expect(within(screen.getByTestId('post-stats')).getByText('12')).toBeInTheDocument();
    expect(within(rows[1]).getByText('Gizli')).toBeInTheDocument();
    expect(within(rows[2]).getByText('Silinmiş')).toBeInTheDocument();
    expect(within(rows[1]).getByText(/spam/)).toBeInTheDocument();
    // silinmiş gönderide eylem yok
    expect(within(rows[2]).queryByText('Gizle')).toBeNull();
    // medya küçük resmi yetkili uçtan alınır
    await waitFor(() => expect(calls.some((c) => c.url.includes('/admin/posts/media/5'))).toBe(true));

    await userEvent.click(screen.getByRole('button', { name: /Daha fazla|Load more|common/i }));
    await waitFor(() => expect(calls.some((c) => c.url.includes('cursor=1'))).toBe(true));
  });

  it('passes filters to the API', async () => {
    const calls = setup();
    renderWithProviders(<PostsAdminPage />);
    await screen.findAllByTestId('post-row');
    await userEvent.selectOptions(screen.getByLabelText('Durum'), 'HIDDEN');
    await waitFor(() => expect(calls.some((c) => c.url.includes('status=HIDDEN'))).toBe(true));
    await userEvent.type(screen.getByLabelText('Metin veya yazar (ad / e-posta)'), 'ayse');
    await waitFor(() => expect(calls.some((c) => c.url.includes('q=ayse'))).toBe(true));
    await userEvent.type(screen.getByLabelText('Yazar numarası'), '7');
    await waitFor(() => expect(calls.some((c) => c.url.includes('authorId=7'))).toBe(true));
    await userEvent.type(screen.getByLabelText('En az açık şikâyet'), '2');
    await waitFor(() => expect(calls.some((c) => c.url.includes('minReports=2'))).toBe(true));
  });

  it('hides with a reason, unhides, and deletes after confirmation', async () => {
    const calls = setup();
    renderWithProviders(<PostsAdminPage />);
    const rows = await screen.findAllByTestId('post-row');

    // W1-B (T-013): gizle / geri aç / sil gerekçe ister (>= 5 karakter) ve X-Admin-Reason başlığıyla gönderir
    await userEvent.click(within(rows[0]).getByRole('button', { name: 'Gizle' }));
    let dialog = await screen.findByRole('dialog');
    const hideConfirm = within(dialog).getByRole('button', { name: 'Gizle' });
    expect(hideConfirm).toBeDisabled(); // gerekçesiz gizlenmez
    await userEvent.type(within(dialog).getByLabelText(/^Gerekçe/), 'abc');
    expect(hideConfirm).toBeDisabled(); // 5 karakterden kısa
    await userEvent.type(within(dialog).getByLabelText(/^Gerekçe/), 'de uygunsuz');
    await userEvent.click(hideConfirm);
    await waitFor(() => {
      const c = calls.find((x) => x.method === 'POST' && x.url.includes('/admin/posts/1/hide'));
      expect(c?.body).toEqual({ reason: 'abcde uygunsuz' });
      expect(decodeURIComponent(c?.headers?.['X-Admin-Reason'] ?? '')).toBe('abcde uygunsuz');
    });

    await userEvent.click(within(rows[1]).getByRole('button', { name: 'Geri aç' }));
    dialog = await screen.findByRole('dialog');
    expect(calls.some((c) => c.url.includes('/admin/posts/2/unhide'))).toBe(false); // gerekçesiz geri açılmaz
    expect(within(dialog).getByRole('button', { name: 'Geri aç' })).toBeDisabled();
    await userEvent.type(within(dialog).getByLabelText(/^Gerekçe/), 'yanlış karar');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Geri aç' }));
    await waitFor(() => {
      const c = calls.find((x) => x.url.includes('/admin/posts/2/unhide'));
      expect(decodeURIComponent(c?.headers?.['X-Admin-Reason'] ?? '')).toBe('yanlış karar');
    });

    await userEvent.click(within(rows[0]).getByRole('button', { name: 'Sil' }));
    expect(calls.some((c) => c.method === 'DELETE')).toBe(false); // onaysız silinmez
    dialog = await screen.findByRole('alertdialog');
    await userEvent.type(within(dialog).getByLabelText(/^Gerekçe/), 'reklam içerik');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Sil' }));
    await waitFor(() => {
      const c = calls.find((x) => x.method === 'DELETE' && x.url.endsWith('/admin/posts/1'));
      expect(c?.body).toEqual({ reason: 'reklam içerik' });
      expect(decodeURIComponent(c?.headers?.['X-Admin-Reason'] ?? '')).toBe('reklam içerik');
    });
  });

  it('edits the text of a post (PATCH) and validates the format rule', async () => {
    const calls = setup();
    renderWithProviders(<PostsAdminPage />);
    const rows = await screen.findAllByTestId('post-row');
    await userEvent.click(within(rows[0]).getByRole('button', { name: 'Düzenle' }));
    const input = await screen.findByLabelText('Gönderi metni');
    expect(input).toHaveValue('gonderi-1');
    await userEvent.clear(input);
    await userEvent.type(input, 'bir iki uc dort bes alti yedi sekiz');
    expect(await screen.findByText('En çok 7 kelime ve 60 karakter.')).toBeInTheDocument();
    expect(screen.getByTestId('edit-confirm')).toBeDisabled();
    await userEvent.clear(input);
    await userEvent.type(input, 'yeni');
    await userEvent.click(screen.getByTestId('edit-confirm'));
    await waitFor(() => {
      const c = calls.find((x) => x.method === 'PATCH' && x.url.endsWith('/admin/posts/1'));
      expect(c?.body).toEqual({ text: 'yeni' });
    });
  });

  it('opens the detail panel with the reports of the post', async () => {
    setup();
    renderWithProviders(<PostsAdminPage />);
    const rows = await screen.findAllByTestId('post-row');
    await userEvent.click(within(rows[0]).getByRole('button', { name: 'Ayrıntı' }));
    expect(await screen.findByTestId('post-detail')).toBeInTheDocument();
    expect(screen.getByTestId('post-detail-text')).toHaveTextContent('gonderi-1');
    const reports = await screen.findByTestId('post-reports');
    expect(within(reports).getByText('reklam')).toBeInTheDocument();
    expect(within(reports).getByText('Açık')).toBeInTheDocument();
  });

  it('shows an error state with retry when the list fails', async () => {
    setup({ listError: true });
    renderWithProviders(<PostsAdminPage />);
    expect(await screen.findByRole('button', { name: /Tekrar|Retry|Yeniden/i })).toBeInTheDocument();
  });
});
