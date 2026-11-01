import { screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { useLocation } from 'react-router-dom';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { renderWithProviders } from '../test/utils';
import { resetPageMemory } from './pageMemory';
import { QuickNav } from './QuickNav';

// İzin kümesi testten testte değişir (null = hepsi serbest)
let allowed: Set<string> | null = null;
vi.mock('../auth/permissions', () => ({
  usePermissions: () => ({
    status: 'ready',
    me: null,
    can: (perm?: string | null) => !perm || allowed === null || allowed.has(perm),
  }),
}));

function Where() {
  const l = useLocation();
  return <output data-testid="where">{`${l.pathname}${l.hash}`}</output>;
}

function open(onClose = vi.fn()) {
  const r = renderWithProviders(
    <>
      <QuickNav open onClose={onClose} />
      <Where />
    </>,
    { route: '/admin' },
  );
  return { onClose, user: userEvent.setup(), unmount: r.unmount };
}

const box = () => screen.getByRole('combobox', { name: /Panelde sayfa, ayar ya da işlem ara/ });

beforeEach(() => {
  window.localStorage.clear();
  resetPageMemory();
  allowed = null;
  Element.prototype.scrollIntoView = vi.fn();
});

describe('QuickNav (panel araması)', () => {
  it('"bakım modu" ayarı bulur, gruplar, kırıntı gösterir; Enter derin bağlantıyı açar', async () => {
    const { onClose, user } = open();
    await user.type(box(), 'bakim modu');
    const list = screen.getByRole('listbox');
    const groups = within(list).getAllByRole('group');
    expect(groups[0]).toHaveAccessibleName(/Ayarlar ve alanlar/);
    const first = within(list).getAllByRole('option')[0];
    expect(first).toHaveTextContent('Bakım modu');
    expect(first).toHaveTextContent('Sistem › Ayarlar › Bakım modu');
    expect(first).toHaveAttribute('aria-selected', 'true');
    await user.keyboard('{Enter}');
    expect(screen.getByTestId('where')).toHaveTextContent('/admin/settings#maintenance_mode');
    expect(onClose).toHaveBeenCalled();
  });

  it('eşleşen sözcük vurgulanır (mark)', async () => {
    const { user } = open();
    await user.type(box(), 'bakım');
    const first = within(screen.getByRole('listbox')).getAllByRole('option')[0];
    expect(first.querySelector('mark')?.textContent?.toLocaleLowerCase('tr')).toContain('bakım');
  });

  it('küçük yazım hatasına rağmen bulur', async () => {
    const { user } = open();
    await user.type(box(), 'bakm mdou');
    expect(within(screen.getByRole('listbox')).getAllByRole('option')[0]).toHaveTextContent('Bakım modu');
  });

  it('ok tuşlarıyla gezinir ve Enter seçilen satırı açar', async () => {
    const { user } = open();
    await user.type(box(), 'ayar');
    const opts = within(screen.getByRole('listbox')).getAllByRole('option');
    expect(opts.length).toBeGreaterThan(2);
    await user.keyboard('{ArrowDown}');
    expect(within(screen.getByRole('listbox')).getAllByRole('option')[1]).toHaveAttribute('aria-selected', 'true');
    await user.keyboard('{ArrowUp}');
    expect(within(screen.getByRole('listbox')).getAllByRole('option')[0]).toHaveAttribute('aria-selected', 'true');
  });

  it('Esc pencereyi kapatır', async () => {
    const { onClose, user } = open();
    await user.keyboard('{Escape}');
    expect(onClose).toHaveBeenCalled();
  });

  it('RBAC: izni olmayan ayar ve sayfa sonuçlarda GÖRÜNMEZ', async () => {
    allowed = new Set(['dashboard.read', 'users.read', 'content.read']);
    const { user } = open();
    await user.type(box(), 'bakım modu');
    expect(screen.queryByRole('option', { name: /Bakım modu/ })).toBeNull();
    expect(screen.queryByText('Ayarlar ve alanlar')).toBeNull();
    await user.clear(box());
    await user.type(box(), 'kullanıcı');
    expect(within(screen.getByRole('listbox')).getAllByRole('option')[0]).toHaveTextContent('Kullanıcılar');
  });

  it('sonuç yoksa "Şunu mu aradınız?" önerir; tıklayınca uygular', async () => {
    const { user } = open();
    await user.type(box(), 'bakim mdu');
    // yazım hatası tolere edildiği için sonuç var: kesin sonuçsuz bir yanlış yazım deneyelim
    await user.clear(box());
    await user.type(box(), 'bakimm mdoo');
    const sug = await screen.findByText('Şunu mu aradınız?', { exact: false });
    expect(sug).toBeInTheDocument();
    await user.click(sug);
    expect(box()).toHaveValue('bakım modu');
    expect(within(screen.getByRole('listbox')).getAllByRole('option')[0]).toHaveTextContent('Bakım modu');
  });

  it('tamamen anlamsız sorguda boş sonuç mesajı ve sık aramalar çıkar', async () => {
    const { user } = open();
    await user.type(box(), 'qqqqqqqq');
    expect(screen.getAllByText(/için sonuç bulunamadı/).length).toBeGreaterThan(0); // görünür + ekran okuyucu
    expect(screen.getByText('En sık aranan')).toBeInTheDocument();
  });

  it('boş kutuda sık aramalar listelenir; seçilince kutuya yazılır', async () => {
    const { user } = open();
    expect(screen.getByText('En sık aranan')).toBeInTheDocument();
    await user.click(screen.getByRole('option', { name: 'bakım modu' }));
    expect(box()).toHaveValue('bakım modu');
  });

  it('son aramalar kaydedilir ve boş kutuda gösterilir, temizlenebilir', async () => {
    const first = open();
    await first.user.type(box(), 'bakim modu');
    await first.user.keyboard('{Enter}');
    expect(window.localStorage.getItem('bu.admin.search.recent')).toContain('bakim modu');

    // yeniden açılış
    first.unmount();
    const second = open();
    const recent = await screen.findByText('Son aramalar');
    expect(recent).toBeInTheDocument();
    expect(screen.getByRole('option', { name: 'bakim modu' })).toBeInTheDocument();
    await second.user.click(screen.getByRole('button', { name: 'Geçmişi temizle' }));
    expect(screen.queryByText('Son aramalar')).toBeNull();
  });

  it('localStorage hata verse bile çalışır', async () => {
    const spy = vi.spyOn(Storage.prototype, 'setItem').mockImplementation(() => {
      throw new Error('kota');
    });
    const { user } = open();
    await user.type(box(), 'bakim modu');
    await user.keyboard('{Enter}');
    expect(screen.getByTestId('where')).toHaveTextContent('#maintenance_mode');
    spy.mockRestore();
  });

  it('"mesaj" yazınca mesaj içeren sayfaları listeler: sohbet akışı, mesaj erişim kayıtları, sohbetler ve şifreleme', async () => {
    const { user } = open();
    await user.type(box(), 'mesaj');
    const text = within(screen.getByRole('listbox')).getAllByRole('option').map((o) => o.textContent ?? '');
    const joined = text.join(' | ');
    expect(joined).toContain('Mesaj erişim kayıtları');
    expect(joined).toContain('Sohbet medyası ve mesajlar');
    expect(joined).toContain('Sohbetler ve şifreleme');
  });

  it.each(['meaj', 'mesjalar', 'MESAJLAR'])('yazım hatası "%s" yine mesaj sayfalarını getirir; her sonuçta yol görünür', async (typo) => {
    const { user } = open();
    await user.type(box(), typo);
    const opts = within(screen.getByRole('listbox')).getAllByRole('option');
    expect(opts[0]).toHaveTextContent(/Mesaj erişim kayıtları|Sohbet medyası ve mesajlar/);
    expect(opts[0].textContent).toMatch(/Sistem|Moderasyon/); // grup/yol kırıntısı
  });

  it('başlıkta görünmeyen eşleşme "Eşleşen:" ile kaynağını söyler (eş anlamlı/anahtar kelime)', async () => {
    const { user } = open();
    await user.type(box(), 'dm');
    const texts = within(screen.getByRole('listbox')).getAllByRole('option').map((o) => o.textContent ?? '');
    expect(texts.some((x) => x.includes('Sohbet medyası ve mesajlar'))).toBe(true);
    expect(texts.some((x) => /Eşleşen: /.test(x))).toBe(true);
  });

  it('çok sonuçlu grupta "daha göster" kalan sonuçları açar, "Daha az göster" kapatır', async () => {
    const { user } = open();
    await user.type(box(), 'mesaj');
    const more = screen.getAllByRole('button', { name: /sonuç daha göster/ })[0];
    const before = within(screen.getByRole('listbox')).getAllByRole('option').length;
    await user.click(more);
    const after = within(screen.getByRole('listbox')).getAllByRole('option').length;
    expect(after).toBeGreaterThan(before);
    await user.click(screen.getAllByRole('button', { name: 'Daha az göster' })[0]);
    expect(within(screen.getByRole('listbox')).getAllByRole('option').length).toBe(before);
  });

  it('boş kutuda son ziyaret edilen sayfalar listelenir ve seçilince açılır', async () => {
    window.localStorage.setItem('bu.admin.pages.recent', JSON.stringify(['users', 'settings']));
    const { user } = open();
    expect(await screen.findByText('Son baktığınız sayfalar')).toBeInTheDocument();
    await user.click(screen.getByRole('option', { name: 'Ayarlar' }));
    expect(screen.getByTestId('where')).toHaveTextContent('/admin/settings');
  });
});
