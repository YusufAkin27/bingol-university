import type { Tone } from '../../../components/ui';

/** HTTP durum kodunu rozet tonuna çevirir: 2xx başarılı, 3xx bilgi, 4xx uyarı, 5xx hata. */
export function statusTone(status: number): Tone {
  if (status >= 500) return 'danger';
  if (status >= 400) return 'warning';
  if (status >= 300) return 'info';
  if (status >= 200) return 'success';
  return 'neutral';
}

/** 403 (yetkisiz deneme) ayrıca vurgulanır. */
export const isDenied = (status: number) => status === 403;
