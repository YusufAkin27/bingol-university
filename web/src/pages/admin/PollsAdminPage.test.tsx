import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import PollsAdminPage from './PollsAdminPage';
import PostsAdminPage from './PostsAdminPage';
import { EMPTY_POLL_FORM, toPollInput, validatePollForm } from './polls/pollsLogic';

const poll = (id: number, over: Record<string, unknown> = {}) => ({
  id,
  title: `anket-${id}`,
  type: 'SINGLE',
  status: 'ACTIVE',
  scope: 'GENERAL',
  scopeId: null,
  anonymous: false,
  audience: 'ALL',
  startsAt: null,
  endsAt: null,
  options: [
    { id: 1, text: 'A' },
    { id: 2, text: 'B' },
  ],
  voteCount: 4,
  createdAt: '2026-02-01T10:00:00Z',
  ...over,
});

describe('pollsLogic', () => {
  it('gecersiz formu yakalar', () => {
    expect(validatePollForm(EMPTY_POLL_FORM)).toBe('title');
    expect(validatePollForm({ ...EMPTY_POLL_FORM, title: 'x' })).toBe('optionEmpty');
    expect(validatePollForm({ ...EMPTY_POLL_FORM, title: 'x', options: ['a', 'A'] })).toBe('optionDup');
    expect(validatePollForm({ ...EMPTY_POLL_FORM, title: 'x', options: Array(13).fill('a') })).toBe('options');
    expect(validatePollForm({ ...EMPTY_POLL_FORM, title: 'x', options: ['a', 'b'], startsAt: '2026-02-02T10:00', endsAt: '2026-02-01T10:00' })).toBe('period');
    expect(validatePollForm({ ...EMPTY_POLL_FORM, title: 'x', options: ['a', 'b'] })).toBeNull();
  });
  it('puanlama anketinde sabit 1-5 secenek uretir', () => {
    const b = toPollInput({ ...EMPTY_POLL_FORM, title: ' q ', type: 'RATING' });
    expect(b.options).toEqual(['1', '2', '3', '4', '5']);
    expect(b.title).toBe('q');
  });
});

describe('PollsAdminPage', () => {
  beforeEach(() => vi.stubGlobal('scrollTo', () => undefined));
  afterEach(() => vi.unstubAllGlobals());

  it('listeler, durum suzgeci sorguya girer ve menu puanlarini gosterir', async () => {
    const fetchFn = mockFetch((url) => {
      if (url.includes('/admin/polls/menu-ratings'))
        return jsonResponse(200, { items: [{ date: '2026-02-03', meal: 'Ogle', average: 4.25, count: 12 }] });
      if (url.includes('/admin/polls')) return jsonResponse(200, { items: [poll(1), poll(2, { status: 'CLOSED' })], nextCursor: null });
      return jsonResponse(404, { code: 'X', message: 'x' });
    });
    renderWithProviders(<PollsAdminPage />);
    expect(await screen.findAllByTestId('poll-row')).toHaveLength(2);
    expect(await screen.findByTestId('menu-ratings')).toBeInTheDocument();
    await userEvent.selectOptions(screen.getByLabelText('Durum'), 'ACTIVE');
    await waitFor(() => expect(fetchFn.mock.calls.some(([u]) => String(u).includes('status=ACTIVE'))).toBe(true));
  });

  it('gizli ankette sonuc gorunumunde kimlik notu cikar', async () => {
    mockFetch((url) => {
      if (url.includes('/results'))
        return jsonResponse(200, {
          pollId: 1, type: 'SINGLE', anonymous: true, totalVotes: 4, eligibleCount: 10, participationRate: 0.4,
          options: [{ id: 1, text: 'A', votes: 3, percent: 75 }, { id: 2, text: 'B', votes: 1, percent: 25 }],
        });
      if (url.includes('menu-ratings')) return jsonResponse(200, { items: [] });
      return jsonResponse(200, { items: [poll(1, { anonymous: true })], nextCursor: null });
    });
    renderWithProviders(<PollsAdminPage />);
    await userEvent.click(await screen.findByRole('button', { name: 'Sonuçlar' }));
    expect(await screen.findByTestId('poll-results')).toBeInTheDocument();
    expect(screen.getByText(/yalnızca toplamlar/)).toBeInTheDocument();
    expect(screen.getByRole('img', { name: /^A:/ })).toBeInTheDocument();
  });

  it('bos baslikla kaydetmeyi engeller', async () => {
    const fetchFn = mockFetch((url) => (url.includes('menu-ratings') ? jsonResponse(200, { items: [] }) : jsonResponse(200, { items: [], nextCursor: null })));
    renderWithProviders(<PollsAdminPage />);
    await userEvent.click(await screen.findByTestId('poll-new'));
    await userEvent.click(screen.getByTestId('poll-save'));
    expect(await screen.findByText('Başlık zorunludur')).toBeInTheDocument();
    expect(fetchFn.mock.calls.some(([, i]) => (i as RequestInit)?.method === 'POST')).toBe(false);
  });
});

describe('PostsAdminPage sosyal sekmeler', () => {
  afterEach(() => vi.unstubAllGlobals());
  it('hikayeler sekmesi listeler', async () => {
    mockFetch((url) => {
      if (url.includes('/admin/stories'))
        return jsonResponse(200, {
          items: [{ id: 5, author: { id: 1, displayName: 'Ali', email: 'a@bingol.edu.tr' }, kind: 'TEXT', caption: null, bodyText: 'merhaba', viewCount: 3, hidden: false, createdAt: '2026-02-01T10:00:00Z', expiresAt: '2026-02-02T10:00:00Z' }],
          nextCursor: null,
        });
      if (url.includes('/admin/posts/stats')) {
        const c = { postCount: 0, commentCount: 0, likeCount: 0, mediaCount: 0, hiddenCount: 0, deletedCount: 0 };
        return jsonResponse(200, { ...c, last24h: c });
      }
      return jsonResponse(200, { items: [], nextCursor: null });
    });
    renderWithProviders(<PostsAdminPage />);
    await userEvent.click(await screen.findByRole('tab', { name: 'Hikâyeler' }));
    expect(await screen.findByTestId('story-row')).toHaveTextContent('merhaba');
  });
});
