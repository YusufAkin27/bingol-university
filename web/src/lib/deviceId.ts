import { readStorage, writeStorage } from './storage';

/**
 * Tarayıcıya özgü kalıcı rastgele cihaz kimliği (`X-Device-Id`). İki faktörlü doğrulamada "güvenilen cihaz"
 * bu kimlikle tanınır; sunucu ham değeri saklamaz (HMAC özeti). Token'lar sessionStorage'da, kimlik
 * localStorage'dadır (sekme kapanınca kaybolmaz). Depolama kullanılamazsa `storage.ts` bellek yedeğine düşer.
 */
const KEY = 'bu.device.id';
const MIN_LEN = 32;

function randomHex(bytes: number): string {
  const buf = new Uint8Array(bytes);
  const c = typeof globalThis !== 'undefined' ? globalThis.crypto : undefined;
  if (c && typeof c.getRandomValues === 'function') {
    c.getRandomValues(buf);
  } else {
    for (let i = 0; i < bytes; i++) buf[i] = Math.floor(Math.random() * 256);
  }
  return Array.from(buf, (b) => b.toString(16).padStart(2, '0')).join('');
}

/** Varsa kayıtlı kimliği döndürür; yoksa (ya da çok kısaysa) 32 bayt rastgele (64 hex) yenisini üretip saklar. */
export function getDeviceId(): string {
  const existing = readStorage('local', KEY);
  if (existing && existing.length >= MIN_LEN) return existing;
  const id = randomHex(32);
  writeStorage('local', KEY, id);
  return id;
}
