import { act, render, screen } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { Reveal } from './Reveal';

afterEach(() => {
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

describe('Reveal', () => {
  it('IntersectionObserver yoksa içerik görünür kalır (gizleme sınıfı yok)', () => {
    vi.stubGlobal('IntersectionObserver', undefined);
    render(<Reveal>içerik</Reveal>);
    expect(screen.getByText('içerik').className).not.toMatch(/hidden/);
  });

  it('ilk ekrandaki öğe gizlenmez', () => {
    vi.stubGlobal('IntersectionObserver', class { observe() {} disconnect() {} });
    vi.spyOn(HTMLElement.prototype, 'getBoundingClientRect').mockReturnValue({ top: 100 } as DOMRect);
    render(<Reveal>üst</Reveal>);
    expect(screen.getByText('üst').className).not.toMatch(/hidden/);
  });

  it('ekran altındaki öğe gizlenir; gözlemci sessiz kalsa bile kaydırma yedeği açar', () => {
    vi.stubGlobal('IntersectionObserver', class { observe() {} disconnect() {} });
    const rect = vi.spyOn(HTMLElement.prototype, 'getBoundingClientRect').mockReturnValue({ top: 5000 } as DOMRect);
    render(<Reveal>alt</Reveal>);
    expect(screen.getByText('alt').className).toMatch(/hidden/);
    rect.mockReturnValue({ top: 200 } as DOMRect);
    act(() => {
      window.dispatchEvent(new Event('scroll'));
    });
    expect(screen.getByText('alt').className).not.toMatch(/hidden/);
  });
});
