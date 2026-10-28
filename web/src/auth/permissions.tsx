// P16: yönetici izinleri. `usePermissions()` oturumda bir kez `GET /admin/rbac/me` çeker (react-query önbelleği).
// UI gizlemesi GÜVENLİK DEĞİLDİR: asıl denetim sunucudadır (403 ADMIN_PERMISSION_DENIED). Bu yüzden izin bilgisi
// henüz yoksa ya da alınamadıysa arayüz serbesttir (bilinmeyen = izin var sayılır); sunucu reddederse hata gösterilir.
import { useQuery } from '@tanstack/react-query';
import { useMemo, type ReactNode } from 'react';
import { getRbacMe, rbacKeys, type RbacMe } from '../api/rbac';
import { PageHeader } from '../components/ui/PageHeader';
import { useI18n } from '../i18n/I18nProvider';

export interface PermissionsState {
  /** loading: ilk yanıt bekleniyor · ready: izinler biliniyor · unknown: alınamadı (arayüz serbest). */
  status: 'loading' | 'ready' | 'unknown';
  me: RbacMe | null;
  /** İzin var mı; bilinmiyorsa true (sunucu asıl denetimi yapar). Boş/undefined izin her zaman true. */
  can: (perm: string | undefined | null) => boolean;
}

/** `enabled=false` ise ağ isteği atmaz (yalnız önbelleği okur); izin gerektirmeyen bileşenler için. */
export function usePermissions(enabled = true): PermissionsState {
  const q = useQuery({
    queryKey: rbacKeys.me,
    queryFn: getRbacMe,
    enabled,
    staleTime: Infinity, // oturumda bir kez; profil değişince token yenilenir ve sayfa yenilenir
    retry: 1,
  });
  // Beklenen biçimde olmayan yanıt (eksik izin listesi) "bilinmiyor" sayılır: arayüz serbest, sunucu denetler
  const me = q.data && Array.isArray(q.data.permissions) ? q.data : null;
  const isError = q.isError || (q.isSuccess && me === null);
  // Kararlı nesne: menü/arama useMemo bağımlılığı olarak kullanır
  return useMemo<PermissionsState>(() => {
    const status: PermissionsState['status'] = me ? 'ready' : isError ? 'unknown' : enabled ? 'loading' : 'unknown';
    const perms = me ? new Set(me.permissions) : null;
    return { status, me, can: (perm) => !perm || perms === null || perms.has(perm) };
  }, [me, isError, enabled]);
}

/** Tek izin sorgusu. `perm` verilmezse (undefined) istek atılmaz ve sonuç true'dur. */
export function useCan(perm?: string): boolean {
  const { can } = usePermissions(perm !== undefined);
  return can(perm);
}

/** "Bu sayfa için yetkiniz yok" ekranı. */
export function NoPermissionPage({ perm }: { perm?: string }) {
  const { t } = useI18n();
  return (
    <div data-testid="no-permission">
      <PageHeader title={t('admin.p16.denied.title')} description={t('admin.p16.denied.body')} />
      {perm && <p>{t('admin.p16.denied.needs', { perm })}</p>}
    </div>
  );
}

/** Rota koruması: izin yoksa çocuklar yerine "yetkiniz yok" sayfası gösterilir. */
export function RequirePerm({ perm, children }: { perm: string | undefined; children: ReactNode }) {
  const { can } = usePermissions(perm !== undefined);
  if (!can(perm)) return <NoPermissionPage perm={perm} />;
  return <>{children}</>;
}
