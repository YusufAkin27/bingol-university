// P16: yönetici izinleri. `usePermissions()` oturumda bir kez `GET /admin/rbac/me` çeker (react-query önbelleği).
// UI gizlemesi GÜVENLİK DEĞİLDİR: asıl denetim sunucudadır (403 ADMIN_PERMISSION_DENIED). Bu yüzden izin bilgisi
// henüz yoksa ya da alınamadıysa arayüz serbesttir (bilinmeyen = izin var sayılır); sunucu reddederse hata gösterilir.
import { useQuery } from '@tanstack/react-query';
import { useMemo, type ReactNode } from 'react';
import { isApiError } from '../api/client';
import { getRbacMe, rbacKeys, type RbacMe } from '../api/rbac';
import { Spinner } from '../components/ui/Feedback';
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
    // Hatalı sorgu her yeni gözlemcide yeniden denenirse durum 'pending'e döner: RequirePerm sayfayı söküp yeniden takar ve
    // sonsuz istek döngüsü oluşur. Hata kalıcıdır ("bilinmiyor": arayüz serbest, sunucu denetler).
    retryOnMount: false,
    // 4xx (ör. 401/403/404) yeniden denemeyle düzelmez: "bilinmiyor" durumuna hemen düş (RequirePerm bekletmesin)
    retry: (count, err) => count < 1 && !(isApiError(err) && err.status >= 400 && err.status < 500),
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

/**
 * Bölüm kapısı: izin YÜKLENİRKEN 'loading' (çağıran istek atmaz/spinner gösterir), izin yoksa 'denied' (bölüm gizlenir),
 * aksi hâlde 'allowed'. Bilgi alınamazsa 'allowed' (arayüz serbest, sunucu asıl denetimi yapar). `useCan`dan farkı: yüklenirken
 * "izin var" saymaz, böylece izinsiz uçlara 403 gürültüsü üretilmez (A3-06).
 */
export function usePermGate(perm: string): 'loading' | 'allowed' | 'denied' {
  const { status, can } = usePermissions(true);
  if (status === 'loading') return 'loading';
  return can(perm) ? 'allowed' : 'denied';
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

/**
 * Rota koruması: izin yoksa çocuklar yerine "yetkiniz yok" sayfası gösterilir. İzin bilgisi YÜKLENİRKEN çocuklar
 * çizilmez (A3-06): aksi hâlde sayfa izinsiz uçlara istek atıp 403 gürültüsü/denetim kaydı üretirdi.
 */
export function RequirePerm({ perm, children }: { perm: string | undefined; children: ReactNode }) {
  const { can, status } = usePermissions(perm !== undefined);
  if (perm !== undefined && status === 'loading') {
    return (
      <div data-testid="perm-loading" aria-busy="true" style={{ display: 'grid', placeItems: 'center', minHeight: '40vh' }}>
        <Spinner />
      </div>
    );
  }
  if (!can(perm)) return <NoPermissionPage perm={perm} />;
  return <>{children}</>;
}
