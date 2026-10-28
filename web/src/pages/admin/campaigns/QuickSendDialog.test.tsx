import { cleanup, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../../test/fetchMock';
import { renderWithProviders } from '../../../test/utils';
import { QuickSendDialog } from './QuickSendDialog';

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

describe('QuickSendDialog (kullanıcı ayrıntısından tek kullanıcıya bildirim)', () => {
  it('içerik eksikken göndermez; doluysa /users/{id}/send uç noktasına POST eder', async () => {
    const calls: { url: string; body: unknown }[] = [];
    mockFetch((url, init) => {
      calls.push({ url, body: init.body ? JSON.parse(String(init.body)) : undefined });
      return jsonResponse(202, { id: 3 });
    });
    const onClose = vi.fn();
    renderWithProviders(<QuickSendDialog open onClose={onClose} userId={42} userName="Ayse Yilmaz" />);
    const user = userEvent.setup();
    expect(screen.getByText('Ayse Yilmaz kişisine bildirim gönder')).toBeInTheDocument();

    await user.click(screen.getByTestId('quick-send'));
    expect(calls).toHaveLength(0);

    await user.type(screen.getByLabelText('Başlık'), 'Merhaba');
    await user.type(screen.getByLabelText('Metin', { exact: true }), 'Duyuru metni');
    await user.click(screen.getByTestId('quick-send'));
    await waitFor(() => expect(calls).toHaveLength(1));
    expect(calls[0].url).toMatch(/\/admin\/push\/users\/42\/send$/);
    expect(calls[0].body).toMatchObject({ type: 'ANNOUNCEMENT', tr: { title: 'Merhaba', body: 'Duyuru metni' } });
    await waitFor(() => expect(onClose).toHaveBeenCalled());
  });

  it('429 RATE_LIMITED hata mesajı pencerede gösterilir', async () => {
    mockFetch(() => jsonResponse(429, { code: 'RATE_LIMITED', message: 'x' }));
    renderWithProviders(<QuickSendDialog open onClose={() => undefined} userId={1} userName="X" />);
    const user = userEvent.setup();
    await user.type(screen.getByLabelText('Başlık'), 'A');
    await user.type(screen.getByLabelText('Metin', { exact: true }), 'B');
    await user.click(screen.getByTestId('quick-send'));
    expect((await screen.findAllByText(/en fazla 20 kampanya/)).length).toBeGreaterThan(0);
  });
});
