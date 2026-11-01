import { useAuth } from '../../../auth/AuthProvider';

/**
 * `content.write` izni. `/admin/me` izin listesi göndermiyorsa (eski sunucu) arayüz kısıtlamaz;
 * yetkiyi her durumda sunucu denetler (403 ADMIN_PERMISSION_DENIED).
 */
export function useCanWriteContent(): boolean {
  const { user } = useAuth();
  const perms = user?.permissions;
  return perms === undefined || perms.includes('content.write');
}
