import { api } from './client';
import type { CryptoStatus, DecryptRequest, DecryptResponse } from './types';

/** Yalnızca JWT'li ADMIN (Basic auth ile çalışmaz). Her çağrı değiştirilemez erişim denetim kaydına yazılır. */
export const decryptMessages = (r: DecryptRequest) => api.post<DecryptResponse>('/admin/messages/decrypt', r);
/** Anahtar kimlikleri ve ana anahtar başına sarılı DEK sayısı; gizli veri içermez. */
export const getCryptoStatus = () => api.get<CryptoStatus>('/admin/crypto/status');
