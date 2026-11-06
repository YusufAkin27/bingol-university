import { fireEvent, screen, within } from '@testing-library/react';
import { renderWithProviders } from '../../../test/utils';
import { ReadingToc, usePrintDoc } from './ReadingToc';

const items = [
  { id: 'a', title: 'Birinci' },
  { id: 'b', title: 'İkinci' },
];

const realMatchMedia = window.matchMedia;
function mockViewport(matches: boolean) {
  window.matchMedia = ((query: string) => ({
    matches,
    media: query,
    onchange: null,
    addEventListener: () => {},
    removeEventListener: () => {},
    addListener: () => {},
    removeListener: () => {},
    dispatchEvent: () => false,
  })) as unknown as typeof window.matchMedia;
}
afterEach(() => {
  window.matchMedia = realMatchMedia;
});

function Probe() {
  usePrintDoc();
  return null;
}

describe('ReadingToc', () => {
  it('geniş ekranda başlıklı bağlantı listesi; çapa bağlantıları id ile eşleşir', () => {
    renderWithProviders(
      <ReadingToc items={items} navLabel="İçindekiler" heading="Bu sayfada" buttonLabel="Bu sayfada" compactBelow={900} />,
    );
    const nav = screen.getByRole('navigation', { name: 'İçindekiler' });
    expect(within(nav).getAllByRole('link').map((a) => a.getAttribute('href'))).toEqual(['#a', '#b']);
    expect(screen.queryByRole('button')).toBeNull();
  });

  it('dar ekranda açılır düğme; bağlantıya tıklayınca kapanır', () => {
    mockViewport(true);
    renderWithProviders(
      <ReadingToc items={items} navLabel="İçindekiler" heading="Bu sayfada" buttonLabel="Bu sayfada" compactBelow={900} />,
    );
    const btn = screen.getByRole('button', { name: 'Bu sayfada' });
    expect(btn).toHaveAttribute('aria-expanded', 'false');
    fireEvent.click(btn);
    expect(btn).toHaveAttribute('aria-expanded', 'true');
    fireEvent.click(screen.getByRole('link', { name: 'İkinci' }));
    expect(btn).toHaveAttribute('aria-expanded', 'false');
  });

  it('usePrintDoc: html.print-doc sınıfını ekler, ayrılınca kaldırır', () => {
    const { unmount } = renderWithProviders(<Probe />);
    expect(document.documentElement.classList.contains('print-doc')).toBe(true);
    unmount();
    expect(document.documentElement.classList.contains('print-doc')).toBe(false);
  });
});
