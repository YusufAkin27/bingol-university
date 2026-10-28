// Sohbet içeriği sebep akışı (W-P02): sebep kapısı, hatırlama, 400 REASON_REQUIRED'de yeniden sorma, başlık kodlaması.
import { screen, waitFor, within, cleanup } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { Route, Routes } from 'react-router-dom';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { headerOf, jsonResponse, mockFetch } from '../../../test/fetchMock';
import { renderWithProviders } from '../../../test/utils';
import ChatFeedPage from '../ChatFeedPage';
import ReportsPage from '../ReportsPage';
import UserMessagesPage from '../UserMessagesPage';
import {
  chatReasonKey,
  clearAllChatReasons,
  getChatReason,
  reasonHeaders,
  setChatReason,
} from './chatReason';

const USER = { id: 7, displayName: 'Ayşe Demir', avatarUrl: null };
const person = (id: number, name: string) => ({ id, displayName: name, email: `${name.toLowerCase()}@bingol.edu.tr` });

interface Call {
  url: string;
  reason: string | undefined;
}

function setupUserChat(opts: { rejectFirst?: boolean } = {}) {
  const calls: Call[] = [];
  let rejected = false;
  mockFetch((url, init) => {
    calls.push({ url, reason: headerOf(init, 'X-Admin-Reason') });
    if (url.includes('/conversations')) {
      if (opts.rejectFirst && !rejected) {
        rejected = true;
        return jsonResponse(400, { code: 'REASON_REQUIRED', message: 'x' });
      }
      if (url.includes('/messages')) {
        return jsonResponse(200, { user: USER, conversation: { id: 30, type: 'DIRECT', title: null, peer: null, left: false }, items: [], nextBefore: null });
      }
      return jsonResponse(200, { user: USER, items: [], nextCursor: null });
    }
    return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
  });
  return calls;
}

function renderUserChat(route = '/admin/users/7/messages') {
  return renderWithProviders(
    <Routes>
      <Route path="/admin/users/:id/messages" element={<UserMessagesPage />} />
    </Routes>,
    { route },
  );
}

beforeEach(() => clearAllChatReasons());
afterEach(() => {
  cleanup(); // önce bileşenleri kaldır: sebep deposu temizlenince kapı yeniden render etmesin
  vi.unstubAllGlobals();
  clearAllChatReasons();
});

describe('reasonHeaders', () => {
  it('Türkçe/Arapça karakterleri yüzde-kodlar ve kenar boşluklarını kırpar', () => {
    const r = ' Şikayet #4521 incelemesi — çözüm ';
    expect(reasonHeaders(r).headers['X-Admin-Reason']).toBe(encodeURIComponent(r.trim()));
    expect(reasonHeaders('طلب قانوني رسمي').headers['X-Admin-Reason']).toBe(encodeURIComponent('طلب قانوني رسمي'));
    expect(reasonHeaders('abc').headers['X-Admin-Reason']).not.toMatch(/[^\x20-\x7e]/);
  });
});

describe('Kullanıcı mesajları: sebep kapısı', () => {
  it('sebep yazılana dek hiçbir sohbet isteği atılmaz; kısa sebep kabul edilmez', async () => {
    const calls = setupUserChat();
    renderUserChat();
    const dialog = await screen.findByRole('dialog', { name: 'Bu özel yazışmaları neden görüntülüyorsunuz?' });
    expect(calls).toHaveLength(0);

    const confirm = within(dialog).getByRole('button', { name: 'Görüntüle' });
    expect(confirm).toBeDisabled();
    await userEvent.type(within(dialog).getByRole('textbox'), 'kısa');
    expect(confirm).toBeDisabled();
    expect(calls).toHaveLength(0);

    await userEvent.type(within(dialog).getByRole('textbox'), ' ama artık yeterince uzun');
    expect(confirm).toBeEnabled();
  });

  it('hazır sebep şablonları alana yazılır (Rapor, Destek, Hukuki talep, Diğer)', async () => {
    setupUserChat();
    renderUserChat();
    const dialog = await screen.findByRole('dialog');
    const group = within(dialog).getByRole('group', { name: /şablon|Hazır/i });
    expect(within(group).getAllByRole('button').map((b) => b.textContent)).toEqual([
      'Rapor incelemesi #…',
      'Destek talebi #…',
      'Hukuki talep',
      'Diğer',
    ]);
    await userEvent.click(within(group).getByRole('button', { name: 'Destek talebi #…' }));
    expect(within(dialog).getByRole('textbox')).toHaveValue('Destek talebi #');
  });

  it('sebep her istekte X-Admin-Reason (yüzde-kodlu) ile gider, hedef için hatırlanır ve sebep silinince yeniden sorulur', async () => {
    const calls = setupUserChat();
    const reason = 'Şikayet #4521 incelemesi: çözüm süreci';
    const first = renderUserChat('/admin/users/7/messages?c=30');
    const dialog = await screen.findByRole('dialog');
    await userEvent.type(within(dialog).getByRole('textbox'), reason);
    await userEvent.click(within(dialog).getByRole('button', { name: 'Görüntüle' }));

    await waitFor(() => expect(calls.some((c) => c.url.includes('/conversations/30/messages'))).toBe(true));
    expect(calls.length).toBeGreaterThanOrEqual(2);
    for (const c of calls) expect(c.reason).toBe(encodeURIComponent(reason));
    expect(getChatReason(chatReasonKey.user(7))).toBe(reason);
    expect(screen.getByTestId('reason-bar')).toHaveTextContent(reason);
    expect(screen.getByTestId('reason-bar')).toHaveTextContent('denetim kaydına yazılır');

    // Sayfa yeniden açılınca (aynı oturum) sebep sorulmaz
    first.unmount();
    calls.length = 0;
    renderUserChat('/admin/users/7/messages');
    await waitFor(() => expect(calls.length).toBeGreaterThan(0));
    expect(screen.queryByRole('dialog')).toBeNull();
    expect(calls[0].reason).toBe(encodeURIComponent(reason));
  });

  it('başka kullanıcı için sebep yeniden istenir (hedef başına hatırlanır)', async () => {
    setChatReason(chatReasonKey.user(7), 'Rapor incelemesi #1 için');
    setupUserChat();
    renderWithProviders(
      <Routes>
        <Route path="/admin/users/:id/messages" element={<UserMessagesPage />} />
      </Routes>,
      { route: '/admin/users/8/messages' },
    );
    expect(await screen.findByRole('dialog', { name: 'Bu özel yazışmaları neden görüntülüyorsunuz?' })).toBeInTheDocument();
  });

  it('sunucu 400 REASON_REQUIRED derse sebep silinir ve uyarıyla yeniden sorulur; yeni sebep yeniden dener', async () => {
    const calls = setupUserChat({ rejectFirst: true });
    setChatReason(chatReasonKey.user(7), 'eski geçerli sebep metni');
    renderUserChat();

    const alert = await screen.findByText('Sunucu sebebi kabul etmedi. En az 10 karakterlik açık bir sebep yazın.');
    expect(alert).toBeInTheDocument();
    expect(getChatReason(chatReasonKey.user(7))).toBeNull();

    const dialog = screen.getByRole('dialog');
    await userEvent.type(within(dialog).getByRole('textbox'), 'Hukuki talep dosya 12/2026');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Görüntüle' }));
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
    await waitFor(() => expect(calls.filter((c) => c.reason === encodeURIComponent('Hukuki talep dosya 12/2026')).length).toBeGreaterThan(0));
    expect(screen.queryByText('Sunucu sebebi kabul etmedi. En az 10 karakterlik açık bir sebep yazın.')).toBeNull();
  });

  it('"Sebebi değiştir" mevcut sebebi silip diyaloğu mevcut metinle açar', async () => {
    setChatReason(chatReasonKey.user(7), 'Destek talebi #88 yanıtı');
    setupUserChat();
    renderUserChat();
    await userEvent.click(await screen.findByRole('button', { name: 'Sebebi değiştir' }));
    const dialog = await screen.findByRole('dialog');
    expect(within(dialog).getByRole('textbox')).toHaveValue('Destek talebi #88 yanıtı');
    expect(getChatReason(chatReasonKey.user(7))).toBeNull();
  });
});

describe('Sohbet akışı: sebep kapısı', () => {
  it('istatistik sebepsiz yüklenir; medya ve mesaj uçları sebeple çağrılır', async () => {
    const calls: Call[] = [];
    mockFetch((url, init) => {
      calls.push({ url, reason: headerOf(init, 'X-Admin-Reason') });
      if (url.includes('/chat-media/stats')) {
        const c = { imageCount: 1, videoCount: 0, viewOnceCount: 0, deletedMessageMediaCount: 0, hiddenCount: 0, suppressedCount: 0, purgedCount: 0, totalBytes: 10 };
        return jsonResponse(200, { ...c, last24h: c });
      }
      if (url.includes('/chat-media') || url.includes('/chat-messages')) return jsonResponse(200, { items: [], nextCursor: null });
      return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
    });
    renderWithProviders(<ChatFeedPage />);
    await waitFor(() => expect(calls.some((c) => c.url.includes('/chat-media/stats'))).toBe(true));
    expect(calls.find((c) => c.url.includes('/chat-media/stats'))?.reason).toBeUndefined();
    expect(calls.some((c) => c.url.includes('/chat-media?'))).toBe(false);

    const dialog = await screen.findByRole('dialog');
    await userEvent.type(within(dialog).getByRole('textbox'), 'Rapor incelemesi #9 toplu bakış');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Görüntüle' }));

    await waitFor(() => expect(calls.some((c) => c.url.includes('/chat-media?'))).toBe(true));
    expect(calls.find((c) => c.url.includes('/chat-media?'))?.reason).toBe(encodeURIComponent('Rapor incelemesi #9 toplu bakış'));

    await userEvent.click(await screen.findByRole('tab', { name: 'Mesajlar' }));
    await waitFor(() => expect(calls.some((c) => c.url.includes('/chat-messages'))).toBe(true));
    expect(calls.find((c) => c.url.includes('/chat-messages'))?.reason).toBe(encodeURIComponent('Rapor incelemesi #9 toplu bakış'));
  });
});

describe('Şikâyet bağlamı: sebep kapısı', () => {
  const queueRow = (targetType: string) => ({
    id: 11,
    reporterId: 4,
    targetType,
    targetId: 502,
    reason: 'HARASSMENT',
    note: null,
    status: 'OPEN',
    resolution: null,
    createdAt: '2026-02-01T10:00:00Z',
    priority: 10,
    reasonCode: 'HARASSMENT',
    preview: null,
    hidden: false,
    hiddenBy: null,
    openReporters: 1,
    reporter: person(4, 'Zeynep'),
    reportedUser: person(7, 'Ayse'),
    viewerPath: null,
  });
  const detail = {
    id: 11,
    targetType: 'MESSAGE',
    targetId: 502,
    reason: 'HARASSMENT',
    reasonCode: 'HARASSMENT',
    note: null,
    status: 'OPEN',
    resolution: null,
    priority: 10,
    createdAt: '2026-02-01T10:00:00Z',
    resolvedAt: null,
    reporter: person(4, 'Zeynep'),
    reportedUser: person(7, 'Ayse'),
    context: { type: 'NONE', targetExists: true, conversation: null, reportedMessageId: null, reportedAttachmentId: null, messages: [], content: null, userStats: null },
    relatedReports: null,
    viewerPath: null,
  };

  function setup(targetType: string) {
    const calls: Call[] = [];
    mockFetch((url, init) => {
      calls.push({ url, reason: headerOf(init, 'X-Admin-Reason') });
      if (url.includes('/admin/reports/11')) return jsonResponse(200, detail);
      if (url.includes('/admin/reports/reason-templates')) return jsonResponse(200, []);
      if (url.includes('/admin/reports')) return jsonResponse(200, { items: [queueRow(targetType)], nextCursor: null });
      return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
    });
    return calls;
  }

  it('sohbet mesajı şikâyetinde sebep istenir (ön tanımlı "Rapor incelemesi #11") ve başlıkla gider', async () => {
    const calls = setup('MESSAGE');
    renderWithProviders(<ReportsPage />, { route: '/admin/reports' });
    const dialog = await screen.findByRole('dialog', { name: 'Bu özel yazışmaları neden görüntülüyorsunuz?' });
    expect(within(dialog).getByRole('textbox')).toHaveValue('Rapor incelemesi #11');
    expect(calls.some((c) => c.url.includes('/admin/reports/11'))).toBe(false);

    await userEvent.click(within(dialog).getByRole('button', { name: 'Görüntüle' }));
    await waitFor(() => expect(calls.some((c) => c.url.includes('/admin/reports/11'))).toBe(true));
    expect(calls.find((c) => c.url.includes('/admin/reports/11'))?.reason).toBe(encodeURIComponent('Rapor incelemesi #11'));
  });

  it('sohbet dışı hedeflerde (örn. gönderi) sebep istenmez ve başlık gönderilmez', async () => {
    const calls = setup('POST');
    renderWithProviders(<ReportsPage />, { route: '/admin/reports' });
    await waitFor(() => expect(calls.some((c) => c.url.includes('/admin/reports/11'))).toBe(true));
    expect(screen.queryByRole('dialog', { name: 'Bu özel yazışmaları neden görüntülüyorsunuz?' })).toBeNull();
    expect(calls.find((c) => c.url.includes('/admin/reports/11'))?.reason).toBeUndefined();
  });
});
