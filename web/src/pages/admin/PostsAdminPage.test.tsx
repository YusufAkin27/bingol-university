import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import PostsAdminPage from './PostsAdminPage';
import { excerpt, mediaToLightbox, postStatus } from './posts/postsLogic';

const author = { id: 7, displayName: 'Ayse Yilmaz', email: 'ayse@bingol.edu.tr', avatarUrl: null };
const post = (id: number, over: Record<string, unknown> = {}) => ({
  id,
  author,
  text: `gonderi-${id}`,
  media: [],
  likeCount: 3,
  commentCount: 2,
  mediaCount: 0,
  hidden: false,
  deleted: false,
  hiddenReason: null,
  createdAt: '2026-02-01T10:00:00Z',
  editedAt: null,
  hiddenAt: null,
  deletedAt: null,
  deletedBy: null,
  ...over,
});
const withMedia = {
  media: [
    { id: 5, kind: 'IMAGE', url: '/api/admin/posts/media/5', thumbUrl: '/api/admin/posts/media/5?thumb=true', width: 10, height: 10, durationMs: null, hidden: false },
  ],
  mediaCount: 1,
};
const comment = (id: number, over: Record<string, unknown> = {}) => ({
  id,
  postId: 1,
  parentId: null,
  rootId: id,
  depth: 0,
  author,
  replyToUserId: null,
  text: `yorum-${id}`,
  replyCount: 0,
  hidden: false,
  deleted: false,
  createdAt: '2026-02-01T11:00:00Z',
  deletedAt: null,
  ...over,
});
const counts = { postCount: 12, commentCount: 30, likeCount: 99, mediaCount: 8, hiddenCount: 2, deletedCount: 1 };

interface Call {
  method: string;
  url: string;
  body?: unknown;
}

function setup(opts: { listError?: boolean } = {}) {
  const calls: Call[] = [];
  mockFetch((url, init) => {
    const method = init.method ?? 'GET';
    calls.push({ method, url, body: init.body ? JSON.parse(String(init.body)) : undefined });
    if (url.includes('/admin/posts/media/')) return new Response(new Blob(['x']), { status: 200, headers: { 'Content-Type': 'image/jpeg' } });
    if (url.includes('/admin/posts/stats')) return jsonResponse(200, { ...counts, last24h: { ...counts, postCount: 4 } });
    if (/\/admin\/posts\/1\/comments/.test(url)) return jsonResponse(200, { items: [comment(11), comment(12, { depth: 1, parentId: 11 })], nextCursor: null });
    if (/\/admin\/posts\/1\/(hide|unhide)/.test(url)) return jsonResponse(200, post(1, { hidden: url.endsWith('/hide') }));
    if (/\/admin\/comments\/\d+\/(hide|unhide)/.test(url)) return jsonResponse(200, comment(11, { hidden: true }));
    if (method === 'DELETE') return new Response(null, { status: 204 });
    if (/\/admin\/posts\/1$/.test(url)) {
      return jsonResponse(200, { post: post(1, withMedia), comments: { items: [], nextCursor: null } });
    }
    if (url.includes('/admin/posts')) {
      if (opts.listError) return jsonResponse(500, { code: 'X', message: 'x' });
      if (url.includes('cursor=1')) return jsonResponse(200, { items: [post(0 + 9)], nextCursor: null });
      return jsonResponse(200, {
        items: [post(1, withMedia), post(2, { hidden: true, hiddenReason: 'spam', hiddenAt: '2026-02-02T10:00:00Z' }), post(3, { deleted: true, deletedAt: '2026-02-03T10:00:00Z' })],
        nextCursor: url.includes('hidden=true') ? null : 1,
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
    await userEvent.click(screen.getByLabelText('Yalnız gizli'));
    await waitFor(() => expect(calls.some((c) => c.url.includes('hidden=true'))).toBe(true));
    await userEvent.type(screen.getByLabelText('Yazar (ad veya e-posta)'), 'ayse');
    await waitFor(() => expect(calls.some((c) => c.url.includes('q=ayse'))).toBe(true));
  });

  it('hides with a reason, unhides, and deletes after confirmation', async () => {
    const calls = setup();
    renderWithProviders(<PostsAdminPage />);
    const rows = await screen.findAllByTestId('post-row');

    await userEvent.click(within(rows[0]).getByRole('button', { name: 'Gizle' }));
    await userEvent.type(await screen.findByLabelText('Gerekçe (isteğe bağlı)'), 'uygunsuz');
    await userEvent.click(screen.getByTestId('hide-confirm'));
    await waitFor(() => {
      const c = calls.find((x) => x.method === 'POST' && x.url.includes('/admin/posts/1/hide'));
      expect(c?.body).toEqual({ reason: 'uygunsuz' });
    });

    await userEvent.click(within(rows[1]).getByRole('button', { name: 'Geri aç' }));
    await waitFor(() => expect(calls.some((c) => c.url.includes('/admin/posts/2/unhide'))).toBe(true));

    await userEvent.click(within(rows[0]).getByRole('button', { name: 'Sil' }));
    expect(calls.some((c) => c.method === 'DELETE')).toBe(false); // onaysız silinmez
    const dialog = await screen.findByRole('dialog');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Sil' }));
    await waitFor(() => expect(calls.some((c) => c.method === 'DELETE' && c.url.endsWith('/admin/posts/1'))).toBe(true));
  });

  it('opens the detail panel with comments and moderates a comment', async () => {
    const calls = setup();
    renderWithProviders(<PostsAdminPage />);
    const rows = await screen.findAllByTestId('post-row');
    await userEvent.click(within(rows[0]).getByRole('button', { name: 'Ayrıntı' }));
    expect(await screen.findByTestId('post-detail')).toBeInTheDocument();
    expect(screen.getByTestId('post-detail-text')).toHaveTextContent('gonderi-1');
    const comments = await screen.findAllByTestId('post-comment');
    expect(comments).toHaveLength(2);
    await userEvent.click(within(comments[0]).getByRole('button', { name: 'Gizle' }));
    await waitFor(() => expect(calls.some((c) => c.method === 'POST' && c.url.includes('/admin/comments/11/hide'))).toBe(true));
  });

  it('shows an error state with retry when the list fails', async () => {
    setup({ listError: true });
    renderWithProviders(<PostsAdminPage />);
    expect(await screen.findByRole('button', { name: /Tekrar|Retry|Yeniden/i })).toBeInTheDocument();
  });
});
