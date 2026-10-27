import { api } from './client';
import type { CryptoStatus } from './types';

/** Anahtar kimlikleri ve ana anahtar başına sarılı DEK sayısı; gizli veri içermez. */
export const getCryptoStatus = () => api.get<CryptoStatus>('/admin/crypto/status');
