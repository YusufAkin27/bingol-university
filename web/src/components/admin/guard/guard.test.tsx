import { act, fireEvent, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { useState } from 'react';
import { Link, Route, Routes } from 'react-router-dom';
import { describe, expect, it, vi } from 'vitest';
import { api, ApiError } from '../../../api/client';
import { translate } from '../../../i18n';
import { adminError, errorMessage } from '../../../lib/errors';
import { adminErrorMessage } from '../../../pages/admin/campaigns/shared';
import { jsonResponse, mockFetch, headerOf } from '../../../test/fetchMock';
import { renderWithProviders } from '../../../test/utils';
import {
  AuditTrail,
  BulkImpactNotice,
  GuardedAction,
  ReasonField,
  TypeToConfirm,
  foldForMatch,
  idempotencyHeaders,
  isBulkConfirmed,
  matchesTarget,
  newIdempotencyKey,
  reportTemplatesToOptions,
  useGuardedMutation,
  useUnsavedGuard,
} from './index';

const i18nTr = {
  t: (k: string, p?: Record<string, string | number>) => translate('tr', k, p),
  td: (k: string, f?: string) => (translate('tr', k) === k ? (f ?? k) : translate('tr', k)),
};

/** Çözülmesi dışarıdan kontrol edilen söz. */
function deferred<T = void>() {
  let resolve!: (v: T) => void;
  let reject!: (e: unknown) => void;
  const promise = new Promise<T>((res, rej) => {
    resolve = res;
    reject = rej;
  });
  return { promise, resolve, reject };
}

describe('yazarak onay karşılaştırması (match)', () => {
  it('Türkçe İ/ı ve büyük/küçük harfe duyarlı katlama yapar', () => {
    expect(matchesTarget('sil', 'SİL')).toBe(true);
    expect(matchesTarget('SİL', 'SİL')).toBe(true);
    expect(matchesTarget('SIL', 'SİL')).toBe(true);
    expect(matchesTarget('Sıl', 'SİL')).toBe(true);
    expect(matchesTarget('ılık', 'ILIK')).toBe(true);
    expect(foldForMatch('İSTANBUL')).toBe('istanbul');
  });
  it('boşlukları kırpar ve birleştirir, ş/ğ/ü/ö/ç ayrımını korur', () => {
    expect(matchesTarget('  YAYINLA   v3 ', 'YAYINLA v3')).toBe(true);
    expect(matchesTarget('sil', 'şil')).toBe(false);
    expect(matchesTarget('YAYINLA v4', 'YAYINLA v3')).toBe(false);
  });
  it('e-postayı büyük harfle de kabul eder; boş hedef asla eşleşmez', () => {
    expect(matchesTarget('ILKER@BINGOL.EDU.TR', 'ilker@bingol.edu.tr')).toBe(true);
    expect(matchesTarget('', '')).toBe(false);
  });
  it('toplu onay: eşik dahil değil, eşik üstünde sayı yazılmalı', () => {
    expect(isBulkConfirmed(50, 50, '')).toBe(true);
    expect(isBulkConfirmed(51, 50, '')).toBe(false);
    expect(isBulkConfirmed(51, 50, '51')).toBe(true);
  });
});

describe('TypeToConfirm', () => {
  function Host({ onMatch }: { onMatch?: (m: boolean) => void }) {
    const [v, setV] = useState('');
    return (
      <TypeToConfirm
        target="SİL"
        value={v}
        onChange={(x, m) => {
          setV(x);
          onMatch?.(m);
        }}
      />
    );
  }
  it('yanlış yazımda eşleşmez, doğru yazımda (İ/ı toleranslı) eşleşir; yapıştırma çalışır', async () => {
    const onMatch = vi.fn();
    const user = userEvent.setup();
    renderWithProviders(<Host onMatch={onMatch} />);
    const input = screen.getByRole('textbox', { name: 'Onay metni' });
    await user.type(input, 'sl');
    expect(onMatch).toHaveBeenLastCalledWith(false);
    expect(input).toHaveAttribute('aria-invalid', 'true');
    await user.clear(input);
    await user.click(input);
    await user.paste('sil');
    expect(onMatch).toHaveBeenLastCalledWith(true);
    expect(screen.getByText('Eşleşti.')).toBeInTheDocument();
  });
  it('hedefi kod olarak gösterir ve istemi alana bağlar', () => {
    renderWithProviders(<Host />);
    expect(screen.getByText('SİL').tagName).toBe('CODE');
    const input = screen.getByRole('textbox');
    expect(input.getAttribute('aria-describedby')).toBeTruthy();
  });
});

describe('ReasonField', () => {
  function Host({ min = 10, templates }: { min?: number; templates?: { id: string; label: string; text: string }[] }) {
    const [v, setV] = useState('');
    return <ReasonField value={v} onChange={setV} minLength={min} templates={templates} />;
  }
  it('sayaç gösterir, kısa sebepte uyarır, yeterince uzunsa uyarıyı kaldırır', async () => {
    const user = userEvent.setup();
    renderWithProviders(<Host min={10} />);
    const box = screen.getByRole('textbox', { name: /Sebep/ });
    expect(screen.getByText('0/300')).toBeInTheDocument();
    await user.type(box, 'kısa');
    fireEvent.blur(box);
    expect(await screen.findByRole('alert')).toHaveTextContent('en az 10 karakter');
    await user.type(box, ' ama artık yeterli');
    expect(screen.queryByRole('alert')).not.toBeInTheDocument();
    expect(screen.getByText(/^\d+\/300$/)).toBeInTheDocument();
  });
  it('maxLength 300 ile sınırlıdır', () => {
    renderWithProviders(<ReasonField value="" onChange={() => {}} maxLength={999} />);
    expect(screen.getByRole('textbox')).toHaveAttribute('maxlength', '300');
  });
  it('hazır sebep düğmesi metni doldurur', async () => {
    const user = userEvent.setup();
    renderWithProviders(
      <Host templates={[{ id: 'SPAM', label: 'Spam', text: 'Spam içerik nedeniyle işlem yapıldı.' }]} />,
    );
    await user.click(screen.getByRole('button', { name: 'Spam' }));
    expect(screen.getByRole('textbox')).toHaveValue('Spam içerik nedeniyle işlem yapıldı.');
  });
  it('rapor şablonlarını seçeneklere çevirir', () => {
    const opts = reportTemplatesToOptions(
      [{ code: 'SPAM', text: 'tr metin', texts: { tr: 'tr metin', en: 'en text', ar: 'ar' } }],
      { td: i18nTr.td, lang: 'en' },
    );
    expect(opts).toEqual([{ id: 'SPAM', label: expect.any(String), text: 'en text' }]);
  });
});

describe('BulkImpactNotice', () => {
  it('eşik altında yalnız bilgi gösterir; üstünde sayıyı yazdırır', async () => {
    const user = userEvent.setup();
    const onChange = vi.fn();
    const { rerender } = renderWithProviders(
      <BulkImpactNotice count={12} threshold={50} noun="alıcı" value="" onChange={onChange} />,
    );
    expect(screen.getByText('12 alıcı etkilenecek')).toBeInTheDocument();
    expect(screen.queryByRole('textbox')).not.toBeInTheDocument();
    rerender(<BulkImpactNotice count={120} threshold={50} value="" onChange={onChange} />);
    expect(screen.getByText('120 kayıt etkilenecek')).toBeInTheDocument();
    await user.type(screen.getByRole('textbox'), '1');
    expect(onChange).toHaveBeenLastCalledWith('1', false);
  });
});

describe('birleşik hata yardımcısı (adminError)', () => {
  it('admin.err.<KOD> önce, sonra ortak common.error.<KOD>, sonra sunucu mesajı, sonra genel', () => {
    const own = new ApiError(409, 'BAN_INVALID_VALUE', 'x');
    expect(adminError(i18nTr, own)).toBe('Değer geçersiz.');
    const common = new ApiError(404, 'NOT_FOUND', 'x');
    expect(adminError(i18nTr, common)).toBe(errorMessage(i18nTr, common));
    expect(adminError(i18nTr, new ApiError(422, 'BIR_KOD', 'Sunucu der ki'))).toBe('Sunucu der ki');
    expect(adminError(i18nTr, new Error('x'))).toBe(errorMessage(i18nTr, new Error('x')));
    expect(adminError(i18nTr, new ApiError(0, 'NETWORK_ERROR', 'n'))).toBe(
      errorMessage(i18nTr, new ApiError(0, 'NETWORK_ERROR', 'n')),
    );
  });
  it('eski adminErrorMessage aynı davranışı korur; ek kapsam verilebilir', () => {
    expect(adminErrorMessage(i18nTr, new ApiError(409, 'BAN_SELF_LOCKOUT', 'x'))).toBe(
      'Bu engel sizin kendi erişiminizi keser.',
    );
    expect(adminError(i18nTr, new ApiError(409, 'BAN_SELF_LOCKOUT', 'x'), 'admin.events.err', 'admin.err')).toBe(
      'Bu engel sizin kendi erişiminizi keser.',
    );
  });
});

describe('useGuardedMutation', () => {
  function Host({ fn, onKey }: { fn: (v: string, key: string) => Promise<unknown>; onKey?: (k: string) => void }) {
    const g = useGuardedMutation<unknown, string>({
      mutationFn: (v, ctx) => {
        onKey?.(ctx.idempotencyKey);
        return fn(v, ctx.idempotencyKey);
      },
      successMessage: 'Tamam',
    });
    return (
      <>
        <button type="button" onClick={() => void g.run('a')}>
          çalıştır
        </button>
        <button type="button" onClick={() => g.renewKey()}>
          yenile
        </button>
        <span>{g.isPending ? 'sürüyor' : 'boşta'}</span>
      </>
    );
  }
  it('iş sürerken ikinci çağrıyı yok sayar (ardışık tetikleme dahil)', async () => {
    const d = deferred();
    const fn = vi.fn(() => d.promise);
    renderWithProviders(<Host fn={fn} />);
    const btn = screen.getByRole('button', { name: 'çalıştır' });
    // Aynı senkron turda iki tetikleme: düğme kilidi henüz devrede değilken bile tek çağrı.
    act(() => {
      fireEvent.click(btn);
      fireEvent.click(btn);
    });
    await waitFor(() => expect(screen.getByText('sürüyor')).toBeInTheDocument());
    fireEvent.click(btn);
    expect(fn).toHaveBeenCalledTimes(1);
    await act(async () => d.resolve());
    expect(await screen.findByText('Tamam')).toBeInTheDocument();
    fireEvent.click(btn);
    await waitFor(() => expect(fn).toHaveBeenCalledTimes(2));
  });
  it('anahtar: hata sonrası aynı kalır, başarıdan ve renewKey sonrası değişir', async () => {
    const keys: string[] = [];
    let fail = true;
    const fn = vi.fn(async () => {
      if (fail) throw new ApiError(500, 'SERVER_ERROR', 'x');
    });
    renderWithProviders(<Host fn={fn} onKey={(k) => keys.push(k)} />);
    const btn = screen.getByRole('button', { name: 'çalıştır' });
    fireEvent.click(btn);
    await waitFor(() => expect(keys).toHaveLength(1));
    await screen.findByText('boşta');
    fireEvent.click(btn);
    await waitFor(() => expect(keys).toHaveLength(2));
    expect(keys[1]).toBe(keys[0]); // yeniden deneme = aynı niyet
    fail = false;
    await screen.findByText('boşta');
    fireEvent.click(btn);
    await waitFor(() => expect(keys).toHaveLength(3));
    expect(keys[2]).toBe(keys[0]);
    await screen.findByText('Tamam');
    fireEvent.click(btn); // başarıdan sonra yeni anahtar
    await waitFor(() => expect(keys).toHaveLength(4));
    expect(keys[3]).not.toBe(keys[2]);
  });
  it('hata toast metnini adminError ile üretir', async () => {
    const fn = vi.fn(async () => {
      throw new ApiError(409, 'BAN_INVALID_VALUE', 'x');
    });
    renderWithProviders(<Host fn={fn} />);
    fireEvent.click(screen.getByRole('button', { name: 'çalıştır' }));
    expect(await screen.findByText('Değer geçersiz.')).toBeInTheDocument();
  });
  it('anahtar isteğe Idempotency-Key başlığı olarak gider', async () => {
    const fetchMock = mockFetch(() => jsonResponse(200, { ok: true }));
    const key = newIdempotencyKey();
    expect(key).toMatch(/^[0-9a-f-]{36}$/);
    await api.post('/admin/x', { a: 1 }, idempotencyHeaders(key));
    const init = fetchMock.mock.calls[0][1] as RequestInit;
    expect(headerOf(init, 'Idempotency-Key')).toBe(key);
    expect(headerOf(init, 'Content-Type')).toBe('application/json');
  });
});

describe('GuardedAction', () => {
  function setup(props: Partial<React.ComponentProps<typeof GuardedAction>> = {}) {
    const onConfirm = props.onConfirm ?? vi.fn(async () => undefined);
    renderWithProviders(
      <GuardedAction
        title="Kullanıcıyı sil"
        consequence="Hesap anonimleştirilir."
        irreversible
        danger
        typeToConfirm="ali@bingol.edu.tr"
        requireReason
        successMessage="Silindi"
        {...props}
        onConfirm={onConfirm}
      >
        Sil
      </GuardedAction>,
    );
    return { onConfirm };
  }

  it('yıkıcı eylemde role=alertdialog, aria-describedby ve geri alınamaz satırı vardır', async () => {
    const user = userEvent.setup();
    setup();
    await user.click(screen.getByRole('button', { name: 'Sil' }));
    const dlg = screen.getByRole('alertdialog', { name: 'Kullanıcıyı sil' });
    const ids = (dlg.getAttribute('aria-describedby') ?? '').split(' ').filter(Boolean);
    expect(ids.length).toBeGreaterThan(0);
    expect(ids.every((id) => document.getElementById(id))).toBe(true);
    expect(screen.getByText('Bu işlem geri alınamaz.')).toBeInTheDocument();
    expect(screen.getByText('Hesap anonimleştirilir.')).toBeInTheDocument();
  });

  it('yıkıcı olmayan eylemde role=dialog kalır', async () => {
    const user = userEvent.setup();
    setup({ danger: false, irreversible: undefined, typeToConfirm: undefined, requireReason: false });
    await user.click(screen.getByRole('button', { name: 'Sil' }));
    expect(screen.getByRole('dialog')).toBeInTheDocument();
    expect(screen.queryByRole('alertdialog')).not.toBeInTheDocument();
  });

  it('odak ilk alana (sebep) gelir; onay düğmesi yanlış yazımda ve kısa sebepte kapalıdır', async () => {
    const user = userEvent.setup();
    const { onConfirm } = setup();
    await user.click(screen.getByRole('button', { name: 'Sil' }));
    const reason = screen.getByRole('textbox', { name: /Sebep/ });
    expect(reason).toHaveFocus();
    const confirm = screen.getAllByRole('button', { name: 'Onayla' })[0];
    expect(confirm).toBeDisabled();
    await user.type(reason, 'Kural ihlali tekrarlandı');
    expect(confirm).toBeDisabled(); // yazarak onay hâlâ eksik
    const typed = screen.getByRole('textbox', { name: 'Onay metni' });
    await user.type(typed, 'ali@bingol');
    expect(confirm).toBeDisabled();
    await user.type(typed, '.edu.tr');
    expect(confirm).toBeEnabled();
    await user.click(confirm);
    await waitFor(() => expect(onConfirm).toHaveBeenCalledTimes(1));
    expect(onConfirm).toHaveBeenCalledWith({
      reason: 'Kural ihlali tekrarlandı',
      idempotencyKey: expect.stringMatching(/^[0-9a-f-]{36}$/),
    });
    expect(await screen.findByText('Silindi')).toBeInTheDocument();
    await waitFor(() => expect(screen.queryByRole('alertdialog')).not.toBeInTheDocument());
  });

  it('sebep yalnız en az uzunlukta açılır (minimum 10)', async () => {
    const user = userEvent.setup();
    setup({ typeToConfirm: undefined });
    await user.click(screen.getByRole('button', { name: 'Sil' }));
    const confirm = screen.getAllByRole('button', { name: 'Onayla' })[0];
    const reason = screen.getByRole('textbox', { name: /Sebep/ });
    await user.type(reason, '123456789');
    expect(confirm).toBeDisabled();
    await user.type(reason, '0');
    expect(confirm).toBeEnabled();
  });

  it('çift tıklamada onConfirm yalnız 1 kez çalışır ve iş sürerken diyalog Esc ile kapanmaz', async () => {
    const d = deferred();
    const onConfirm = vi.fn(() => d.promise);
    setup({ onConfirm, typeToConfirm: undefined, requireReason: false, danger: false, irreversible: undefined });
    fireEvent.click(screen.getByRole('button', { name: 'Sil' }));
    const confirm = await screen.findByRole('button', { name: 'Onayla' });
    act(() => {
      fireEvent.click(confirm);
      fireEvent.click(confirm);
    });
    fireEvent.click(confirm);
    await waitFor(() => expect(confirm).toBeDisabled()); // loading
    fireEvent.keyDown(document.body, { key: 'Escape' });
    expect(screen.getByRole('dialog')).toBeInTheDocument();
    expect(onConfirm).toHaveBeenCalledTimes(1);
    await act(async () => d.resolve());
    await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument());
    expect(onConfirm).toHaveBeenCalledTimes(1);
  });

  it('Esc diyaloğu kapatır ve odak tetikleyiciye döner; iptalde onConfirm çağrılmaz', async () => {
    const user = userEvent.setup();
    const { onConfirm } = setup();
    const trigger = screen.getByRole('button', { name: 'Sil' });
    await user.click(trigger);
    expect(screen.getByRole('alertdialog')).toBeInTheDocument();
    await user.keyboard('{Escape}');
    expect(screen.queryByRole('alertdialog')).not.toBeInTheDocument();
    expect(trigger).toHaveFocus();
    expect(onConfirm).not.toHaveBeenCalled();
  });

  it('Enter, yazarak onay alanı eşleşmişse onaylar', async () => {
    const user = userEvent.setup();
    const { onConfirm } = setup({ requireReason: false });
    await user.click(screen.getByRole('button', { name: 'Sil' }));
    const typed = screen.getByRole('textbox', { name: 'Onay metni' });
    expect(typed).toHaveFocus();
    await user.type(typed, 'yanlış{Enter}');
    expect(onConfirm).not.toHaveBeenCalled();
    await user.clear(typed);
    await user.type(typed, 'ALI@bingol.edu.tr{Enter}');
    await waitFor(() => expect(onConfirm).toHaveBeenCalledTimes(1));
  });

  it('Idempotency anahtarı diyalog başına bir kez üretilir: yeniden denemede aynı, yeni açılışta farklı', async () => {
    const user = userEvent.setup();
    const keys: string[] = [];
    let fail = true;
    const onConfirm = vi.fn(async ({ idempotencyKey }: { idempotencyKey: string }) => {
      keys.push(idempotencyKey);
      if (fail) throw new ApiError(500, 'SERVER_ERROR', 'x');
    });
    setup({ onConfirm, typeToConfirm: undefined, requireReason: false, danger: false, irreversible: undefined });
    await user.click(screen.getByRole('button', { name: 'Sil' }));
    await user.click(screen.getByRole('button', { name: 'Onayla' }));
    await waitFor(() => expect(keys).toHaveLength(1));
    await waitFor(() => expect(screen.getByRole('button', { name: 'Onayla' })).toBeEnabled());
    expect(screen.getByRole('dialog')).toBeInTheDocument(); // hata: diyalog açık kalır
    await user.click(screen.getByRole('button', { name: 'Onayla' }));
    await waitFor(() => expect(keys).toHaveLength(2));
    expect(keys[1]).toBe(keys[0]);
    // Vazgeç, yeniden aç: yeni niyet = yeni anahtar
    await waitFor(() => expect(screen.getByRole('button', { name: 'Vazgeç' })).toBeEnabled());
    await user.click(screen.getByRole('button', { name: 'Vazgeç' }));
    fail = false;
    await user.click(screen.getByRole('button', { name: 'Sil' }));
    await user.click(screen.getByRole('button', { name: 'Onayla' }));
    await waitFor(() => expect(keys).toHaveLength(3));
    expect(keys[2]).not.toBe(keys[0]);
  });

  it('toplu etki eşiği aşıldığında sayıyı yazmadan onaylanmaz', async () => {
    const user = userEvent.setup();
    const { onConfirm } = setup({
      typeToConfirm: undefined,
      requireReason: false,
      danger: false,
      irreversible: undefined,
      impact: { count: 200, threshold: 50, noun: 'kullanıcı' },
    });
    await user.click(screen.getByRole('button', { name: 'Sil' }));
    expect(screen.getByText('200 kullanıcı etkilenecek')).toBeInTheDocument();
    const confirm = screen.getByRole('button', { name: 'Onayla' });
    expect(confirm).toBeDisabled();
    expect(screen.getByRole('textbox')).toHaveFocus();
    await user.type(screen.getByRole('textbox'), '200');
    expect(confirm).toBeEnabled();
    await user.click(confirm);
    await waitFor(() => expect(onConfirm).toHaveBeenCalledTimes(1));
  });

  it('hata olunca birleşik hata mesajı gösterilir', async () => {
    const user = userEvent.setup();
    setup({
      typeToConfirm: undefined,
      requireReason: false,
      danger: false,
      irreversible: undefined,
      onConfirm: async () => {
        throw new ApiError(409, 'BAN_SELF_LOCKOUT', 'x');
      },
    });
    await user.click(screen.getByRole('button', { name: 'Sil' }));
    await user.click(screen.getByRole('button', { name: 'Onayla' }));
    expect(await screen.findByText('Bu engel sizin kendi erişiminizi keser.')).toBeInTheDocument();
  });
});

describe('AuditTrail', () => {
  it('uç yoksa (404) "Denetim kaydı henüz yok" gösterir ve hedef sorgu parametrelerini yollar', async () => {
    const fetchMock = mockFetch(() => jsonResponse(404, { code: 'NOT_FOUND', message: 'yok' }));
    renderWithProviders(<AuditTrail targetType="USER" targetId={42} />);
    expect(await screen.findByText('Denetim kaydı henüz yok')).toBeInTheDocument();
    const url = String(fetchMock.mock.calls[0][0]);
    expect(url).toContain('/admin/audit');
    expect(url).toContain('targetType=USER');
    expect(url).toContain('targetId=42');
  });
  it('satırları kim/ne zaman/sebep ile erişilebilir listede gösterir', async () => {
    mockFetch(() =>
      jsonResponse(200, {
        items: [
          { id: 1, adminEmail: 'yonetici@bingol.edu.tr', action: 'USER_ROLE_CHANGE', reason: 'Görev değişikliği', at: '2026-10-01T10:00:00Z' },
          { id: 2, adminEmail: null, method: 'DELETE', path: '/api/admin/users/42', at: '2026-10-02T10:00:00Z' },
        ],
        page: 0,
        totalPages: 1,
        totalItems: 2,
      }),
    );
    renderWithProviders(<AuditTrail targetType="USER" targetId="42" />);
    const list = await screen.findByRole('list');
    expect(list.querySelectorAll('li')).toHaveLength(2);
    expect(screen.getByText('yonetici@bingol.edu.tr')).toBeInTheDocument();
    expect(screen.getByText('Sebep: Görev değişikliği')).toBeInTheDocument();
    expect(screen.getByText('Bilinmeyen yönetici')).toBeInTheDocument();
    expect(screen.getByText('DELETE /api/admin/users/42')).toBeInTheDocument();
    expect(screen.getByRole('region', { name: 'Denetim kaydı' })).toBeInTheDocument();
  });
  it('sunucu hatasında hata durumu gösterir', async () => {
    mockFetch(() => jsonResponse(500, { code: 'SERVER_ERROR', message: 'x' }));
    renderWithProviders(<AuditTrail targetType="USER" targetId="42" />);
    expect(await screen.findByText('Denetim kaydı yüklenemedi')).toBeInTheDocument();
  });
});

describe('useUnsavedGuard', () => {
  function Page({ dirty }: { dirty: boolean }) {
    const { dialog, confirmLeave } = useUnsavedGuard(dirty);
    return (
      <>
        <Link to="/baska">Başka sayfa</Link>
        <button type="button" onClick={() => confirmLeave(() => document.title = 'çıkıldı')}>
          Kapat
        </button>
        {dialog}
      </>
    );
  }
  function App({ dirty }: { dirty: boolean }) {
    return (
      <Routes>
        <Route path="/" element={<Page dirty={dirty} />} />
        <Route path="/baska" element={<p>Başka sayfa gövdesi</p>} />
      </Routes>
    );
  }

  it('temizken bağlantılar serbest, beforeunload engellenmez', async () => {
    const user = userEvent.setup();
    renderWithProviders(<App dirty={false} />);
    const ev = new Event('beforeunload', { cancelable: true });
    window.dispatchEvent(ev);
    expect(ev.defaultPrevented).toBe(false);
    await user.click(screen.getByRole('link', { name: 'Başka sayfa' }));
    expect(await screen.findByText('Başka sayfa gövdesi')).toBeInTheDocument();
  });
  it('kirliyken beforeunload engellenir; bağlantı onay diyaloğu açar, Sayfada kal gezinmez', async () => {
    const user = userEvent.setup();
    renderWithProviders(<App dirty />);
    const ev = new Event('beforeunload', { cancelable: true });
    window.dispatchEvent(ev);
    expect(ev.defaultPrevented).toBe(true);
    await user.click(screen.getByRole('link', { name: 'Başka sayfa' }));
    const dlg = await screen.findByRole('alertdialog', { name: 'Kaydedilmemiş değişiklikler var' });
    expect(dlg).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Sayfada kal' })).toHaveFocus();
    await user.click(screen.getByRole('button', { name: 'Sayfada kal' }));
    expect(screen.queryByText('Başka sayfa gövdesi')).not.toBeInTheDocument();
    expect(screen.queryByRole('alertdialog')).not.toBeInTheDocument();
  });
  it('Ayrıl: tıklama yeniden gönderilir ve gezinti gerçekleşir', async () => {
    const user = userEvent.setup();
    renderWithProviders(<App dirty />);
    await user.click(screen.getByRole('link', { name: 'Başka sayfa' }));
    await user.click(await screen.findByRole('button', { name: 'Ayrıl' }));
    expect(await screen.findByText('Başka sayfa gövdesi')).toBeInTheDocument();
  });
  it('confirmLeave: temizken hemen, kirliyken onayla çalışır', async () => {
    const user = userEvent.setup();
    document.title = 'x';
    const { unmount } = renderWithProviders(<App dirty={false} />);
    await user.click(screen.getByRole('button', { name: 'Kapat' }));
    expect(document.title).toBe('çıkıldı');
    unmount();
    document.title = 'x';
    renderWithProviders(<App dirty />);
    await user.click(screen.getByRole('button', { name: 'Kapat' }));
    expect(document.title).toBe('x');
    await user.click(await screen.findByRole('button', { name: 'Ayrıl' }));
    expect(document.title).toBe('çıkıldı');
  });
});
