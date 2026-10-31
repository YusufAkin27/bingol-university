import { publicApi } from './client';
import type { TicketCategory, TicketDetail } from './types';

/** Herkese açık destek talebi (T27): hesapsız, e-posta doğrulamalı. Bearer yok. */
export interface PublicSupportSubmit {
  name: string;
  email: string;
  category: TicketCategory;
  message: string;
  /** Bal kabağı alanı: gerçek kullanıcıda her zaman boş. */
  website: string;
  /** Eski süre alanı: sunucu artık yok sayar (T-062), geriye dönük uyum için gönderilir. */
  elapsedMs: number;
  /** Formu açarken `GET /public/support/form-token` ile alınan imzalı jeton; yoksa sunucu gönderimi sessizce düşürür. */
  formToken: string;
}

/** `GET /public/support/form-token` yanıtı: imzalı, zaman damgalı jeton + gönderim için en az bekleme. */
export interface PublicFormToken {
  formToken: string;
  minFillSeconds: number;
}

/** Sunucu jetonu 2 saatte eskitir; güvenli pay için 100 dk sonra yenilenir. */
export const FORM_TOKEN_MAX_AGE_MS = 100 * 60 * 1000;
/** minFillSeconds bilinmiyorsa varsayılan bekleme (sunucu varsayılanı 3 sn). */
export const DEFAULT_MIN_FILL_SECONDS = 3;

/** Jeton alınmamış ya da çok eskiyse yenilenmelidir. */
export function formTokenStale(issuedAt: number | null, now: number): boolean {
  return issuedAt === null || now - issuedAt >= FORM_TOKEN_MAX_AGE_MS;
}

/** Jeton verildiğinden beri gönderim için kalan zorunlu bekleme (ms, en az 0): çok hızlı gönderim sessizce düşürülür. */
export function msUntilFillAllowed(issuedAt: number, minFillSeconds: number, now: number): number {
  return Math.max(0, issuedAt + Math.max(0, minFillSeconds) * 1000 + 250 - now);
}

export interface PublicSupportCodeSent {
  status: 'CODE_SENT';
  expiresInMinutes: number;
}

export interface PublicSupportVerified {
  ticketId: number;
  trackToken: string;
}

export const MESSAGE_MIN = 10;
export const MESSAGE_MAX = 2000;
export const NAME_MAX = 80;
export const EMAIL_MAX = 254;

export const getPublicFormToken = () => publicApi.get<PublicFormToken>('/public/support/form-token');

export const submitPublicTicket = (body: PublicSupportSubmit) =>
  publicApi.post<PublicSupportCodeSent>('/public/support/tickets', body);

export const verifyPublicTicket = (email: string, code: string) =>
  publicApi.post<PublicSupportVerified>('/public/support/tickets/verify', { email, code });

export const trackPublicTicket = (token: string) =>
  publicApi.post<TicketDetail>('/public/support/track', { token });

export const replyPublicTicket = (token: string, text: string) =>
  publicApi.post<TicketDetail>('/public/support/track/messages', { token, text });

const EMAIL_RE = /^[^\s@<>,;]+@[^\s@<>,;]+\.[^\s@<>,;]{2,}$/;

export interface PublicFormErrors {
  name?: 'required' | 'tooLong';
  email?: 'required' | 'invalid';
  message?: 'required' | 'tooShort' | 'tooLong';
}

/** İstemci doğrulaması (sunucu yine doğrular). Hatasız ise boş nesne döner. */
export function validatePublicForm(v: { name: string; email: string; message: string }): PublicFormErrors {
  const e: PublicFormErrors = {};
  const name = v.name.trim();
  const email = v.email.trim();
  const msg = v.message.trim();
  if (!name) e.name = 'required';
  else if (name.length > NAME_MAX) e.name = 'tooLong';
  if (!email) e.email = 'required';
  else if (email.length > EMAIL_MAX || !EMAIL_RE.test(email)) e.email = 'invalid';
  if (!msg) e.message = 'required';
  else if (msg.length < MESSAGE_MIN) e.message = 'tooShort';
  else if (msg.length > MESSAGE_MAX) e.message = 'tooLong';
  return e;
}
