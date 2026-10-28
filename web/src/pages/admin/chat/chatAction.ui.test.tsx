// Sohbet müdahalesi (P08) arayüzü: işlem menüsü + sebep + yazarak onay, toplu gizleme, sohbet araçları, iki aşamalı dışa aktarma.
import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { AdminChatMessage } from '../../../api/types';
import { headerOf, jsonResponse, mockFetch } from '../../../test/fetchMock';
import { renderWithProviders } from '../../../test/utils';
import { ChatBubble } from './ChatBubble';
import { ConversationExportButton } from './ConversationExport';
import { ConversationTools } from './ConversationTools';
import { MessageActions } from './MessageActions';
import { MessageBulkBar, type MessageSelection } from './MessageBulkBar';
import { Route, Routes } from 'react-router-dom';
import UserMessagesPage from '../UserMessagesPage';
import { chatReasonKey, clearAllChatReasons, setChatReason } from './chatReason';

const msg = (over: Partial<AdminChatMessage> = {}): AdminChatMessage => ({
  id: 5,
  conversationId: 30,
  senderId: 1,
  senderName: 'Ayşe',
  mine: false,
  createdAt: '2026-10-28T10:00:00Z',
  text: 'merhaba',
  error: null,
  edited: false,
  editedAt: null,
  revisions: [],
  deleted: false,
  deletedAt: null,
  deletedBy: null,
  deletedByName: null,
  hidden: false,
  replyTo: null,
  reactions: [],
  attachments: [],
  ...over,
});

const REASON = 'Topluluk kurallarına aykırı içerik';

interface Call {
  url: string;
  method: string;
  reason: string | undefined;
  confirm: string | undefined;
  body: unknown;
}
let calls: Call[] = [];

function record(url: string, init: RequestInit): void {
  calls.push({
    url,
    method: init.method ?? 'GET',
    reason: headerOf(init, 'X-Admin-Reason'),
    confirm: headerOf(init, 'X-Admin-Confirm'),
    body: typeof init.body === 'string' ? JSON.parse(init.body) : undefined,
  });
}

beforeEach(() => {
  calls = [];
});
afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

async function openMenu(user: ReturnType<typeof userEvent.setup>) {
  await user.click(screen.getByRole('button', { name: 'Mesaj #5 işlemleri' }));
}

describe('MessageActions', () => {
  it('görünür mesajda Gizle: sebep zorunlu, onaylanınca POST /hide ve sebep başlığı gider', async () => {
    mockFetch((url, init) => {
      record(url, init);
      return jsonResponse(200, { id: 5, conversationId: 30, state: 'HIDDEN', irreversible: false });
    });
    const user = userEvent.setup();
    renderWithProviders(<MessageActions m={msg()} />);
    await openMenu(user);
    await user.click(screen.getByRole('button', { name: 'Gizle' }));
    const dlg = screen.getByRole('dialog', { name: 'Mesajı gizle' });
    const confirm = within(dlg).getByRole('button', { name: 'Onayla' });
    expect(confirm).toBeDisabled();
    await user.type(within(dlg).getByRole('textbox'), REASON);
    expect(confirm).toBeEnabled();
    await user.click(confirm);
    await waitFor(() => expect(calls).toHaveLength(1));
    expect(calls[0].method).toBe('POST');
    expect(calls[0].url).toContain('/admin/messages/5/hide');
    expect(calls[0].reason).toBe(encodeURIComponent(REASON));
  });

  it('Kalıcı sil: geri alınamaz uyarısı, sebep + "SİL" yazdırma; DELETE gider', async () => {
    mockFetch((url, init) => {
      record(url, init);
      return jsonResponse(200, { id: 5, conversationId: 30, state: 'PURGED', irreversible: true });
    });
    const user = userEvent.setup();
    renderWithProviders(<MessageActions m={msg()} />);
    await openMenu(user);
    await user.click(screen.getByRole('button', { name: 'Kalıcı sil' }));
    const dlg = screen.getByRole('alertdialog', { name: 'Mesajı kalıcı sil' });
    expect(within(dlg).getByText('Bu işlem geri alınamaz.')).toBeInTheDocument();
    const confirm = within(dlg).getByRole('button', { name: 'Onayla' });
    await user.type(within(dlg).getByRole('textbox', { name: /İşlem sebebi/ }), REASON);
    expect(confirm).toBeDisabled(); // yazarak onay eksik
    await user.type(within(dlg).getByRole('textbox', { name: 'Onay metni' }), 'sil'); // Türkçe İ/ı katlaması
    expect(confirm).toBeEnabled();
    await user.click(confirm);
    await waitFor(() => expect(calls).toHaveLength(1));
    expect(calls[0].method).toBe('DELETE');
    expect(calls[0].url).toContain('/admin/messages/5');
    expect(calls[0].reason).toBe(encodeURIComponent(REASON));
  });

  it('yönetici gizlemesinde yalnız Geri göster + Kalıcı sil; Geri göster POST /unhide', async () => {
    mockFetch((url, init) => {
      record(url, init);
      return jsonResponse(200, { id: 5, conversationId: 30, state: 'VISIBLE', irreversible: false });
    });
    const user = userEvent.setup();
    renderWithProviders(<MessageActions m={msg({ hidden: true, adminHidden: true })} />);
    await openMenu(user);
    expect(screen.queryByRole('button', { name: 'Gizle' })).not.toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Geri göster' }));
    const dlg = screen.getByRole('dialog', { name: 'Mesajı geri göster' });
    await user.type(within(dlg).getByRole('textbox'), REASON);
    await user.click(within(dlg).getByRole('button', { name: 'Onayla' }));
    await waitFor(() => expect(calls).toHaveLength(1));
    expect(calls[0].url).toContain('/admin/messages/5/unhide');
  });

  it('moderasyon gizlemesinde yalnız Kalıcı sil; kalıcı silinmişte menü hiç çizilmez', async () => {
    const user = userEvent.setup();
    const { unmount } = renderWithProviders(<MessageActions m={msg({ hidden: true })} />);
    await openMenu(user);
    expect(screen.queryByRole('button', { name: 'Gizle' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Geri göster' })).not.toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Kalıcı sil' })).toBeInTheDocument();
    unmount();
    renderWithProviders(<MessageActions m={msg({ deleted: true, hidden: true, adminHidden: true, purged: true })} />);
    expect(screen.queryByTestId('msg-actions')).not.toBeInTheDocument();
  });

  it('sunucu hatası (409) diyaloğu açık bırakır ve Türkçe hata gösterir', async () => {
    mockFetch(() => jsonResponse(409, { code: 'MESSAGE_ALREADY_HIDDEN', message: 'x' }));
    const user = userEvent.setup();
    renderWithProviders(<MessageActions m={msg()} />);
    await openMenu(user);
    await user.click(screen.getByRole('button', { name: 'Gizle' }));
    const dlg = screen.getByRole('dialog', { name: 'Mesajı gizle' });
    await user.type(within(dlg).getByRole('textbox'), REASON);
    await user.click(within(dlg).getByRole('button', { name: 'Onayla' }));
    expect(await screen.findByText('Bu mesaj zaten gizlenmiş ya da silinmiş.')).toBeInTheDocument();
    expect(screen.getByRole('dialog', { name: 'Mesajı gizle' })).toBeInTheDocument();
  });
});

describe('ChatBubble rozetleri ve seçim kutusu', () => {
  it('yönetici gizlemesi ve kalıcı silme rozeti; seçim kutusu onChange çağırır', async () => {
    const onChange = vi.fn();
    const user = userEvent.setup();
    const { rerender } = renderWithProviders(
      <ul>
        <ChatBubble m={msg({ hidden: true, adminHidden: true })} select={{ checked: false, onChange, label: 'Mesaj #5 seç' }} />
      </ul>,
    );
    expect(screen.getByTestId('admin-hidden-badge')).toHaveTextContent('Yönetici gizledi');
    await user.click(screen.getByRole('checkbox', { name: 'Mesaj #5 seç' }));
    expect(onChange).toHaveBeenCalledWith(true);
    rerender(
      <ul>
        <ChatBubble m={msg({ deleted: true, hidden: true, adminHidden: true, purged: true, text: null, error: 'NO_CIPHERTEXT' })} />
      </ul>,
    );
    expect(screen.getByTestId('purged-badge')).toHaveTextContent('Kalıcı silindi');
    expect(screen.queryByTestId('admin-hidden-badge')).not.toBeInTheDocument();
  });
});

describe('MessageBulkBar', () => {
  const selection = (ids: number[], clear = vi.fn()): MessageSelection => ({
    selected: new Set(ids),
    clear,
    bubbleSelect: () => null,
  });

  it('seçim yokken çizilmez; seçimde sayı + etki şeridi; onayda ids ve sebep gönderilir', async () => {
    mockFetch((url, init) => {
      record(url, init);
      return jsonResponse(200, {
        requested: 2,
        done: 1,
        failed: 1,
        items: [
          { id: 5, ok: true, status: 200, error: null },
          { id: 6, ok: false, status: 409, error: 'MESSAGE_ALREADY_HIDDEN' },
        ],
      });
    });
    const user = userEvent.setup();
    const clear = vi.fn();
    const { rerender } = renderWithProviders(<MessageBulkBar selection={selection([])} />);
    expect(screen.queryByRole('button', { name: 'Seçilenleri gizle' })).not.toBeInTheDocument();
    rerender(<MessageBulkBar selection={selection([5, 6], clear)} />);
    await user.click(screen.getByRole('button', { name: 'Seçilenleri gizle' }));
    const dlg = screen.getByRole('dialog', { name: 'Seçili mesajları gizle' });
    expect(within(dlg).getByRole('status')).toHaveTextContent('2');
    await user.type(within(dlg).getByRole('textbox'), REASON);
    await user.click(within(dlg).getByRole('button', { name: 'Onayla' }));
    await waitFor(() => expect(calls).toHaveLength(1));
    expect(calls[0].url).toContain('/admin/messages/bulk-hide');
    expect(calls[0].body).toEqual({ ids: [5, 6], reason: REASON });
    // kısmi başarı özeti
    expect(await screen.findByText(/1 mesaj gizlendi, 1 mesaj gizlenemedi \(MESSAGE_ALREADY_HIDDEN\)/)).toBeInTheDocument();
    await waitFor(() => expect(clear).toHaveBeenCalled());
  });

  it('50\'den fazla seçimde etkilenen sayıyı yazdırır', async () => {
    const user = userEvent.setup();
    mockFetch((url, init) => {
      record(url, init);
      return jsonResponse(200, { requested: 51, done: 51, failed: 0, items: [] });
    });
    const ids = Array.from({ length: 51 }, (_, i) => i + 1);
    renderWithProviders(<MessageBulkBar selection={selection(ids)} />);
    await user.click(screen.getByRole('button', { name: 'Seçilenleri gizle' }));
    const dlg = screen.getByRole('dialog', { name: 'Seçili mesajları gizle' });
    await user.type(within(dlg).getByRole('textbox', { name: /sebep/i }), REASON);
    const confirm = within(dlg).getByRole('button', { name: 'Onayla' });
    expect(confirm).toBeDisabled();
    await user.type(within(dlg).getByRole('textbox', { name: 'Onay metni' }), '51');
    expect(confirm).toBeEnabled();
  });
});

const META = {
  id: 30,
  type: 'GROUP',
  kind: 'GROUP',
  communityId: null,
  eventId: null,
  title: 'Çalışma grubu',
  closed: false,
  closedAt: null,
  closedBy: null,
  closedReason: null,
  messageCount: 12,
  activeMemberCount: 2,
  openReportCount: 3,
  createdAt: '2026-10-01T10:00:00Z',
  lastMessageAt: null,
  membersManaged: false,
  membersTruncated: false,
  members: [
    { userId: 1, displayName: 'Ayşe', email: 'a***@bingol.edu.tr', role: 'ADMIN', joinedAt: null, leftAt: null, active: true },
    { userId: 2, displayName: 'Berk', email: 'b***@bingol.edu.tr', role: 'MEMBER', joinedAt: null, leftAt: null, active: true },
  ],
};

describe('ConversationTools', () => {
  function serve(meta: object) {
    mockFetch((url, init) => {
      record(url, init);
      if ((init.method ?? 'GET') === 'GET') return jsonResponse(200, meta);
      return jsonResponse(200, { id: 30, closed: true, closedAt: '2026-10-28T10:00:00Z', notified: 2 });
    });
  }

  it('rozetler: tür, mesaj/üye sayısı, açık rapor sayısı; üst veri e-postası maskeli seçeneklerde görünür', async () => {
    serve(META);
    renderWithProviders(<ConversationTools conversationId={30} />);
    expect(await screen.findByText('3 açık rapor')).toBeInTheDocument();
    expect(screen.getByText('Grup')).toBeInTheDocument();
    expect(screen.getByRole('option', { name: /Berk \(b\*\*\*@bingol\.edu\.tr\)/ })).toBeInTheDocument();
    expect(calls[0].url).toContain('/admin/conversations/30');
  });

  it('Sohbeti kapat: sebep zorunlu, POST /close', async () => {
    serve(META);
    const user = userEvent.setup();
    renderWithProviders(<ConversationTools conversationId={30} />);
    await user.click(await screen.findByRole('button', { name: 'Sohbeti kapat' }));
    const dlg = screen.getByRole('alertdialog', { name: 'Sohbeti kapat' });
    const confirm = within(dlg).getByRole('button', { name: 'Onayla' });
    expect(confirm).toBeDisabled();
    await user.type(within(dlg).getByRole('textbox'), REASON);
    await user.click(confirm);
    await waitFor(() => expect(calls.some((c) => c.method === 'POST')).toBe(true));
    const post = calls.find((c) => c.method === 'POST') as Call;
    expect(post.url).toContain('/admin/conversations/30/close');
    expect(post.reason).toBe(encodeURIComponent(REASON));
  });

  it('kapalı sohbette "Sohbeti aç" ve kapatma sebebi görünür', async () => {
    serve({ ...META, closed: true, closedReason: 'Taciz bildirimi' });
    renderWithProviders(<ConversationTools conversationId={30} />);
    expect(await screen.findByRole('button', { name: 'Sohbeti aç' })).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Sohbeti kapat' })).not.toBeInTheDocument();
    expect(screen.getByTestId('closed-badge')).toBeInTheDocument();
    expect(screen.getByText(/Taciz bildirimi/)).toBeInTheDocument();
  });

  it('Üyeyi çıkar: üye seçilmeden kapalı; seçilince DELETE /members/{id}', async () => {
    serve(META);
    const user = userEvent.setup();
    renderWithProviders(<ConversationTools conversationId={30} />);
    const btn = await screen.findByRole('button', { name: 'Üyeyi çıkar' });
    expect(btn).toBeDisabled();
    await user.selectOptions(screen.getByRole('combobox', { name: 'Üye' }), '2');
    await user.click(btn);
    const dlg = screen.getByRole('alertdialog', { name: 'Üyeyi gruptan çıkar' });
    expect(within(dlg).getByText(/Berk bu gruptan çıkarılır/)).toBeInTheDocument();
    await user.type(within(dlg).getByRole('textbox'), REASON);
    await user.click(within(dlg).getByRole('button', { name: 'Onayla' }));
    await waitFor(() => expect(calls.some((c) => c.method === 'DELETE')).toBe(true));
    expect((calls.find((c) => c.method === 'DELETE') as Call).url).toContain('/admin/conversations/30/members/2');
  });

  it('kulüp odasında ve birebirde üye çıkarma yok, açıklama var', async () => {
    serve({ ...META, kind: 'CLUB', membersManaged: true, communityId: 4 });
    const { unmount } = renderWithProviders(<ConversationTools conversationId={30} />);
    expect(await screen.findByText(/Kulüp\/etkinlik odası üyeliği kaynağa bağlıdır/)).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Üyeyi çıkar' })).not.toBeInTheDocument();
    unmount();
    serve({ ...META, type: 'DIRECT', kind: 'DIRECT' });
    renderWithProviders(<ConversationTools conversationId={30} />);
    expect(await screen.findByText('Birebir sohbette üye çıkarılamaz.')).toBeInTheDocument();
  });
});

describe('ConversationExportButton (iki aşamalı onay)', () => {
  const LONG = 'Mahkeme kararı 2026/15 sayılı dosya talebi';

  beforeEach(() => {
    vi.stubGlobal('URL', Object.assign(URL, { createObjectURL: vi.fn(() => 'blob:x'), revokeObjectURL: vi.fn() }));
    vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(() => undefined);
  });

  it('1. aşama: sebep 20 karakterden kısaysa Devam kapalı; 2. aşama: uyarı + sohbet kimliği yazdırma', async () => {
    mockFetch(() => jsonResponse(200, {}));
    const user = userEvent.setup();
    renderWithProviders(<ConversationExportButton conversationId={30} />);
    await user.click(screen.getByRole('button', { name: 'Dışa aktar (yasal talep)' }));
    const dlg = screen.getByRole('alertdialog');
    expect(within(dlg).getByTestId('export-step-1')).toBeInTheDocument();
    const next = within(dlg).getByRole('button', { name: 'Devam' });
    await user.type(within(dlg).getByRole('textbox', { name: /Yasal gerekçe/ }), 'çok kısa sebep');
    expect(next).toBeDisabled();
    await user.type(within(dlg).getByRole('textbox', { name: /Yasal gerekçe/ }), ' ve şimdi yeterince uzun oldu');
    expect(next).toBeEnabled();
    await user.click(next);
    expect(within(dlg).getByTestId('export-step-2')).toBeInTheDocument();
    expect(within(dlg).getByRole('alert')).toHaveTextContent(
      'Bu işlem denetim kaydına yazılır ve mesaj içeriğini çözer.',
    );
    const go = within(dlg).getByRole('button', { name: 'Dışa aktar' });
    expect(go).toBeDisabled();
    await user.type(within(dlg).getByRole('textbox', { name: /sohbet kimliğini yazın: 30/ }), '31');
    expect(go).toBeDisabled();
  });

  it('kimlik doğru yazılınca GET export: sebep + X-Admin-Confirm başlıkları, JSON biçimi', async () => {
    const fetchFn = mockFetch((url, init) => {
      record(url, init);
      return jsonResponse(200, {
        conversationId: 30,
        type: 'GROUP',
        title: 'x',
        exportedAt: '2026-10-28T10:00:00Z',
        exportedBy: 1,
        reason: LONG,
        messageCount: 1,
        truncated: false,
        nextAfterId: null,
        messages: [],
      });
    });
    const user = userEvent.setup();
    renderWithProviders(<ConversationExportButton conversationId={30} />);
    await user.click(screen.getByRole('button', { name: 'Dışa aktar (yasal talep)' }));
    const dlg = screen.getByRole('alertdialog');
    await user.type(within(dlg).getByRole('textbox', { name: /Yasal gerekçe/ }), LONG);
    await user.click(within(dlg).getByRole('button', { name: 'Devam' }));
    await user.type(within(dlg).getByRole('textbox', { name: /sohbet kimliğini yazın/ }), '30');
    await user.click(within(dlg).getByRole('button', { name: 'Dışa aktar' }));
    await waitFor(() => expect(fetchFn).toHaveBeenCalledTimes(1));
    expect(calls[0].method).toBe('GET');
    expect(calls[0].url).toContain('/admin/conversations/30/export');
    expect(calls[0].url).toContain('format=json');
    expect(calls[0].reason).toBe(encodeURIComponent(LONG));
    expect(calls[0].confirm).toBe('30');
    expect(await screen.findByText('1 mesaj dışa aktarıldı')).toBeInTheDocument();
    await waitFor(() => expect(screen.queryByRole('alertdialog')).not.toBeInTheDocument());
  });

  it('sunucu 400 EXPORT_CONFIRM_REQUIRED derse hata gösterilir ve diyalog açık kalır', async () => {
    mockFetch(() => jsonResponse(400, { code: 'EXPORT_CONFIRM_REQUIRED', message: 'x' }));
    const user = userEvent.setup();
    renderWithProviders(<ConversationExportButton conversationId={30} />);
    await user.click(screen.getByRole('button', { name: 'Dışa aktar (yasal talep)' }));
    const dlg = screen.getByRole('alertdialog');
    await user.type(within(dlg).getByRole('textbox', { name: /Yasal gerekçe/ }), LONG);
    await user.click(within(dlg).getByRole('button', { name: 'Devam' }));
    await user.type(within(dlg).getByRole('textbox', { name: /sohbet kimliğini yazın/ }), '30');
    await user.click(within(dlg).getByRole('button', { name: 'Dışa aktar' }));
    expect(await screen.findByText('Dışa aktarma için sohbet kimliğiyle ikinci onay gerekir.')).toBeInTheDocument();
    expect(screen.getByRole('alertdialog')).toBeInTheDocument();
  });
});

describe('UserMessagesPage entegrasyonu', () => {
  afterEach(() => clearAllChatReasons());

  it('sohbet açılınca araç çubuğu, mesaj işlem menüsü ve seçim kutusu gelir; seçim BulkBar açar', async () => {
    setChatReason(chatReasonKey.user(7), 'Şikayet incelemesi #4521');
    mockFetch((url, init) => {
      record(url, init);
      if (url.endsWith('/admin/conversations/30')) return jsonResponse(200, META);
      if (url.includes('/users/7/conversations/30/messages')) {
        return jsonResponse(200, {
          user: { id: 7, displayName: 'Ayşe Demir', avatarUrl: null },
          conversation: { id: 30, type: 'GROUP', title: 'Çalışma grubu', peer: null, left: false, members: [] },
          items: [msg({ id: 5 }), msg({ id: 6, hidden: true, adminHidden: true }), msg({ id: 7, deleted: true })],
          nextBefore: null,
        });
      }
      if (url.includes('/users/7/conversations')) {
        return jsonResponse(200, { user: { id: 7, displayName: 'Ayşe Demir', avatarUrl: null }, items: [], nextCursor: null });
      }
      return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
    });
    const user = userEvent.setup();
    renderWithProviders(
      <Routes>
        <Route path="/admin/users/:id/messages" element={<UserMessagesPage />} />
      </Routes>,
      { route: '/admin/users/7/messages?c=30' },
    );
    expect(await screen.findByTestId('conv-tools')).toBeInTheDocument();
    expect(await screen.findAllByTestId('msg-actions')).toHaveLength(3);
    // yalnız görünür mesaj (5) seçilebilir: yönetici gizlemesi ve kullanıcı silmesi için kutu yok
    const boxes = screen.getAllByTestId('bubble-select');
    expect(boxes).toHaveLength(1);
    expect(screen.queryByRole('button', { name: 'Seçilenleri gizle' })).not.toBeInTheDocument();
    await user.click(boxes[0]);
    expect(await screen.findByRole('button', { name: 'Seçilenleri gizle' })).toBeInTheDocument();
    // üst veri okuması açık görüntüleme sebebiyle denetime bağlanır (işlem sebebi ayrı alan)
    const metaCall = calls.find((c) => c.url.endsWith('/admin/conversations/30'));
    expect(metaCall?.reason).toBe(encodeURIComponent('Şikayet incelemesi #4521'));
  });
});
