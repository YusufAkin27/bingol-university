import { readStorage, removeStorage, writeStorage } from '../lib/storage';

/**
 * Token'lar yalnızca sessionStorage'da tutulur (sekme kapanınca biter); yönetici paneli için localStorage
 * kullanılmaz. Depolama kullanılamazsa bellek yedeği devreye girer.
 */
const ACCESS = 'bu.admin.access';
const REFRESH = 'bu.admin.refresh';

export function getAccessToken(): string | null {
  return readStorage('session', ACCESS);
}
export function getRefreshToken(): string | null {
  return readStorage('session', REFRESH);
}
export function setTokens(access: string, refresh: string): void {
  writeStorage('session', ACCESS, access);
  writeStorage('session', REFRESH, refresh);
}
export function clearTokens(): void {
  removeStorage('session', ACCESS);
  removeStorage('session', REFRESH);
}
