import { readStorage, removeStorage, writeStorage } from '../lib/storage';

/**
 * Token'lar yalnızca sessionStorage'da tutulur (sekme kapanınca biter); yönetici paneli için localStorage
 * kullanılmaz. Depolama kullanılamazsa bellek yedeği devreye girer.
 *
 * İki ayrı oturum alanı vardır ve anahtarları ayrıdır: yönetim paneli (`bu.admin.*`) ve akademisyen paneli
 * (`bu.acad.*`). Biri ötekinin token'ını okumaz, yazmaz, silmez; birinde oturum açmak ötekini açmaz.
 */
export type TokenArea = 'admin' | 'acad';

const KEYS: Record<TokenArea, { access: string; refresh: string }> = {
  admin: { access: 'bu.admin.access', refresh: 'bu.admin.refresh' },
  acad: { access: 'bu.acad.access', refresh: 'bu.acad.refresh' },
};

export interface AreaTokens {
  getAccessToken(): string | null;
  getRefreshToken(): string | null;
  setTokens(access: string, refresh: string): void;
  clearTokens(): void;
}

/** Bir oturum alanının token deposu. */
export function tokensFor(area: TokenArea): AreaTokens {
  const k = KEYS[area];
  return {
    getAccessToken: () => readStorage('session', k.access),
    getRefreshToken: () => readStorage('session', k.refresh),
    setTokens(access, refresh) {
      writeStorage('session', k.access, access);
      writeStorage('session', k.refresh, refresh);
    },
    clearTokens() {
      removeStorage('session', k.access);
      removeStorage('session', k.refresh);
    },
  };
}

// Yönetim paneli (varsayılan alan): mevcut çağıranlar değişmeden çalışır.
const admin = tokensFor('admin');
export const getAccessToken = admin.getAccessToken;
export const getRefreshToken = admin.getRefreshToken;
export const setTokens = admin.setTokens;
export const clearTokens = admin.clearTokens;
