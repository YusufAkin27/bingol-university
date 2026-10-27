// Örnek tip güvenli modül: herkese açık uygulama bilgisi ve bakım durumu.
import { typedGet } from './typedApi';

export const getAppInfoTyped = () => typedGet('/api/app/info');
export const getStatusTyped = () => typedGet('/api/status');
