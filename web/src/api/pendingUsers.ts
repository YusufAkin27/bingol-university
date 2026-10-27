// Doğrulanmamış (bekleyen) kayıtlar: yalnızca Redis'te durur, 72 saat sonra kendiliğinden silinir.
// Uçlar: /admin/pending-registrations* (backend: admin/AdminPendingRegistrationController, PendingRegistrationStore.Entry).
// Kimlik e-posta ya da okul numarasıdır; yola kodlanarak yazılır.
import { api } from './client';

export interface PendingUser {
  email: string;
  displayName: string | null;
  faculty: string | null;
  department: string | null;
  grade: string | null;
  createdAtEpochSec: number;
  remainingSeconds: number;
  resendCount: number;
}

export interface PendingPage {
  items: PendingUser[];
  nextCursor: string | null;
}

export interface VerifiedUser {
  id: number;
  email: string;
  displayName: string;
  createdAt?: string;
}

const BASE = '/admin/pending-registrations';
const seg = (email: string) => encodeURIComponent(email);

export async function listPending(p: { q?: string; cursor?: string | null; size?: number } = {}): Promise<PendingPage> {
  const r = await api.get<Partial<PendingPage>>(BASE, {
    q: p.q || undefined,
    cursor: p.cursor ?? undefined,
    size: p.size ?? 20,
  });
  return { items: r.items ?? [], nextCursor: r.nextCursor ?? null };
}

/** Hesabı koda gerek kalmadan oluşturur (409 EMAIL_ALREADY_REGISTERED, 404 PENDING_REGISTRATION_NOT_FOUND). */
export const verifyPending = (email: string) => api.post<VerifiedUser>(`${BASE}/${seg(email)}/verify`);
/** 202; 429 RESEND_COOLDOWN. */
export const resendPendingCode = (email: string) => api.post(`${BASE}/${seg(email)}/resend-code`);
export const cancelPending = (email: string) => api.del(`${BASE}/${seg(email)}`);

export const pendingKeys = {
  all: ['pending-users'] as const,
  list: (q: string) => ['pending-users', 'list', q] as const,
};
