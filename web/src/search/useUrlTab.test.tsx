import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { useLocation } from 'react-router-dom';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { renderWithProviders } from '../test/utils';
import { SearchAnchor, useSearchAnchorFocus } from './anchor';
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
