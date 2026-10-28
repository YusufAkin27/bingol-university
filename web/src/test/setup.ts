import '@testing-library/jest-dom/vitest';
import { cleanup, configure } from '@testing-library/react';
import { afterEach, vi } from 'vitest';
import { clearTokens } from '../auth/tokens';
import '../i18n/all'; // tüm sözlükler eşzamanlı kayıtlı (uygulamada dil başına lazy yüklenir)
import { setCurrentLang } from '../i18n/lang';

// Paket paralel calisirken yavas makinelerde findBy* varsayilan 1 sn yetmeyebiliyor
configure({ asyncUtilTimeout: 5000 });

afterEach(() => {
  cleanup();
  setCurrentLang('tr');
  clearTokens(); // storage.ts bellek yedeğini de temizler
  window.sessionStorage.clear();
  window.localStorage.clear();
  document.documentElement.removeAttribute('data-theme');
  vi.restoreAllMocks();
});

// jsdom'da bulunmayan tarayıcı API'leri
class RO {
  observe() {}
  unobserve() {}
  disconnect() {}
}
(globalThis as unknown as { ResizeObserver: typeof RO }).ResizeObserver ??= RO;

if (!window.matchMedia) {
  window.matchMedia = ((query: string) => ({
    matches: false,
    media: query,
    onchange: null,
    addEventListener: () => {},
    removeEventListener: () => {},
    addListener: () => {},
    removeListener: () => {},
    dispatchEvent: () => false,
  })) as unknown as typeof window.matchMedia;
}
window.scrollTo = (() => {}) as typeof window.scrollTo;

// Kök yönlendirmesi tarayıcı diline bakar (detectPreferredLang); testlerde varsayılan Türkçe olsun
Object.defineProperty(window.navigator, 'language', { value: 'tr-TR', configurable: true });
Object.defineProperty(window.navigator, 'languages', { value: ['tr-TR', 'tr'], configurable: true });
