// Örnek tip güvenli modül: yönetici ayarları ve rapor kuyruğu (liste).
import { typedGet } from './typedApi';

export const getSettingsTyped = () => typedGet('/api/admin/settings');
export const getReportsTyped = () => typedGet('/api/admin/reports');
