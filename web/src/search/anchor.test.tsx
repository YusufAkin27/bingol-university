import { act, screen, waitFor } from '@testing-library/react';
import { useState } from 'react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { renderWithProviders } from '../test/utils';
import { SearchAnchor, useSearchAnchorFocus, useSearchReveal } from './anchor';

function Shell({ children }: { children?: React.ReactNode }) {
  useSearchAnchorFocus();
  return (
    <main id="admin-main">
      {children}
    </main>
  );
}

/** Sekmeli sayfa: hedef yalnız "b" sekmesinde çizilir; arama açıcısı sekmeyi değiştirir. */
function Tabbed() {
  const [tab, setTab] = useState<'a' | 'b'>('a');
  useSearchReveal((anchor) => {
    if (anchor === 'deep-field') setTab('b');
  });
  return (
    <div>
      <p>sekme {tab}</p>
      {tab === 'b' && <SearchAnchor id="deep-field">Derindeki alan</SearchAnchor>}
    </div>
  );
}

const scrollIntoView = vi.fn();

beforeEach(() => {
  scrollIntoView.mockReset();
  Element.prototype.scrollIntoView = scrollIntoView;
});
afterEach(() => {
  vi.useRealTimers();
});

describe('derin bağlantı (SearchAnchor + useSearchAnchorFocus)', () => {
  it('hedef sayfada hazırsa kaydırır, vurgular ve odaklar; 2 sn sonra vurguyu kaldırır', async () => {
    renderWithProviders(
      <Shell>
        <SearchAnchor id="hedef">İçerik</SearchAnchor>
      </Shell>,
      { route: '/admin/x#hedef' },
    );
    const el = await screen.findByText('İçerik');
    await waitFor(() => expect(el).toHaveAttribute('data-search-hit', 'true'));
    await waitFor(() => expect(scrollIntoView).toHaveBeenCalled());
    expect(scrollIntoView.mock.calls[0][0]).toMatchObject({ block: 'center' });
    await waitFor(() => expect(el).not.toHaveAttribute('data-search-hit'), { timeout: 4000 });
  });

  it('sekme/açıklayıcı gerekiyorsa sayfanın açıcısını çağırır ve sonra bulur', async () => {
    renderWithProviders(
      <Shell>
        <Tabbed />
      </Shell>,
      { route: '/admin/x#deep-field' },
    );
    const el = await screen.findByText('Derindeki alan');
    await waitFor(() => expect(el).toHaveAttribute('data-search-hit', 'true'));
  });

  it('kapalı <details> içindeki hedefi açar', async () => {
    renderWithProviders(
      <Shell>
        <details data-testid="d">
          <summary>Gelişmiş</summary>
          <SearchAnchor id="icerde">Gizli alan</SearchAnchor>
        </details>
      </Shell>,
      { route: '/admin/x#icerde' },
    );
    await waitFor(() => expect(screen.getByTestId('d')).toHaveAttribute('open'));
  });

  it('hedef hiç çizilmezse nazik bir bilgi gösterir', async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true });
    renderWithProviders(<Shell />, { route: '/admin/x#yok-boyle-alan' });
    await act(async () => {
      await vi.advanceTimersByTimeAsync(4200);
    });
    expect(await screen.findByText('Bu alan şu an bu sayfada görünmüyor.')).toBeInTheDocument();
  });

  it('sayfa içi kimlikler (İçeriğe geç → #admin-main) arama bağlantısı sayılmaz: uyarı yok', async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true });
    renderWithProviders(<Shell />, { route: '/admin/x#admin-main' });
    await act(async () => {
      await vi.advanceTimersByTimeAsync(4200);
    });
    expect(screen.queryByText('Bu alan şu an bu sayfada görünmüyor.')).toBeNull();
    expect(scrollIntoView).not.toHaveBeenCalled();
  });
});
