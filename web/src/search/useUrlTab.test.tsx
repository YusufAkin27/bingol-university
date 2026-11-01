import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { useLocation, useNavigate } from 'react-router-dom';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { renderWithProviders } from '../test/utils';
import { SearchAnchor, useSearchAnchorFocus, useSearchReveal } from './anchor';
import { useUrlTab } from './useUrlTab';

const TABS = ['a', 'b', 'c'] as const;
type Tab = (typeof TABS)[number];

function Page() {
  useSearchAnchorFocus();
  const [tab, setTab] = useUrlTab<Tab>(TABS, 'a');
  const loc = useLocation();
  return (
    <div>
      <output data-testid="loc">{`${loc.pathname}${loc.search}${loc.hash}`}</output>
      <output data-testid="tab">{tab}</output>
      <button onClick={() => setTab('b')}>b</button>
      <button onClick={() => setTab('a')}>a</button>
      {tab === 'c' && <SearchAnchor id="tab-c">c içeriği</SearchAnchor>}
      {tab === 'b' && <SearchAnchor id="alan-b">b alanı</SearchAnchor>}
    </div>
  );
}

beforeEach(() => {
  Element.prototype.scrollIntoView = vi.fn();
});

describe('useUrlTab', () => {
  it('?tab= değerini okur; geçersiz değerde varsayılana düşer', () => {
    renderWithProviders(<Page />, { route: '/admin/x?tab=c' });
    expect(screen.getByTestId('tab')).toHaveTextContent('c');
  });
  it('geçersiz değer varsayılan sekmedir', () => {
    renderWithProviders(<Page />, { route: '/admin/x?tab=zzz' });
    expect(screen.getByTestId('tab')).toHaveTextContent('a');
  });
  it('sekme değişince adrese yazar, varsayılana dönünce siler; diğer parametreleri korur', async () => {
    const user = userEvent.setup();
    renderWithProviders(<Page />, { route: '/admin/x?q=1' });
    await user.click(screen.getByText('b', { selector: 'button' }));
    expect(screen.getByTestId('loc')).toHaveTextContent('/admin/x?q=1&tab=b');
    await user.click(screen.getByText('a', { selector: 'button' }));
    expect(screen.getByTestId('loc')).toHaveTextContent('/admin/x?q=1');
  });
  it('#anchor korunur ve hedef bulunup vurgulanır (sekme değişse bile)', async () => {
    renderWithProviders(<Page />, { route: '/admin/x?tab=b#alan-b' });
    const el = await screen.findByText('b alanı');
    await waitFor(() => expect(el).toHaveAttribute('data-search-hit', 'true'));
    expect(screen.getByTestId('loc')).toHaveTextContent('#alan-b');
  });
  it('tab-<değer> anchor\'ı ilgili sekmeyi açar', async () => {
    renderWithProviders(<Page />, { route: '/admin/x#tab-c' });
    const el = await screen.findByText('c içeriği');
    await waitFor(() => expect(el).toHaveAttribute('data-search-hit', 'true'));
    expect(screen.getByTestId('loc')).toHaveTextContent('/admin/x?tab=c#tab-c');
  });
});

function PageWithReveal() {
  useSearchAnchorFocus();
  const [tab, setTab] = useUrlTab<Tab>(TABS, 'a');
  const loc = useLocation();
  const navigate = useNavigate();
  // Sayfaların kendi açıcısı: alan-b anchor'ı b sekmesinde (Ayarlar/Operasyon/Kullanıcı ayrıntısı deseni)
  useSearchReveal((anchor) => {
    if (anchor === 'alan-b') setTab('b');
  });
  return (
    <div>
      <output data-testid="loc">{`${loc.pathname}${loc.search}${loc.hash}`}</output>
      <output data-testid="tab">{tab}</output>
      <button onClick={() => setTab('a')}>a</button>
      <button onClick={() => setTab('c')}>c</button>
      <button onClick={() => navigate('/admin/x#alan-b')}>tekrar-ac</button>
      {tab === 'b' && <SearchAnchor id="alan-b">b alanı</SearchAnchor>}
    </div>
  );
}

describe('derin bağlantıdan sonra sekme değiştirme (regresyon)', () => {
  it('derin bağlantı aç, başka sekmeye tıkla: sekme DEĞİŞİR ve geri dönmez, karma silinir', async () => {
    const user = userEvent.setup();
    renderWithProviders(<PageWithReveal />, { route: '/admin/x#alan-b' });
    const el = await screen.findByText('b alanı');
    await waitFor(() => expect(el).toHaveAttribute('data-search-hit', 'true'));
    expect(screen.getByTestId('tab')).toHaveTextContent('b');

    await user.click(screen.getByText('a', { selector: 'button' }));
    expect(screen.getByTestId('tab')).toHaveTextContent('a');
    expect(screen.getByTestId('loc')).toHaveTextContent(/^\/admin\/x$/);
    // Odak efektinin (yoklama aralığı 100 ms) sekmeyi geri almadığını bekleyerek doğrula
    await new Promise((r) => setTimeout(r, 450));
    expect(screen.getByTestId('tab')).toHaveTextContent('a');

    await user.click(screen.getByText('c', { selector: 'button' }));
    await new Promise((r) => setTimeout(r, 300));
    expect(screen.getByTestId('tab')).toHaveTextContent('c');
  });

  it('aynı sonuca tekrar tıklamak yine açar ve vurgular', async () => {
    const user = userEvent.setup();
    renderWithProviders(<PageWithReveal />, { route: '/admin/x#alan-b' });
    await waitFor(() => expect(screen.getByText('b alanı')).toHaveAttribute('data-search-hit', 'true'));
    await user.click(screen.getByText('a', { selector: 'button' }));
    expect(screen.getByTestId('tab')).toHaveTextContent('a');
    await user.click(screen.getByText('tekrar-ac'));
    const el = await screen.findByText('b alanı');
    await waitFor(() => expect(el).toHaveAttribute('data-search-hit', 'true'));
    expect(screen.getByTestId('tab')).toHaveTextContent('b');
  });
});
