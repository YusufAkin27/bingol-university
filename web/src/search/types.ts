/**
 * Yönetim paneli arama kayıt defteri: tür sözleşmesi.
 * Sayfa ajanları yalnız `SearchEntry` yazar (bkz. README.md); çözümleme (yol, izin, kırıntı, simge) `build.ts` içindedir.
 */
import type { Permission } from '../api/rbac';
import type { IconName } from '../components/ui/Icon';

/**
 * page    : sayfa (menü sayfaları otomatik üretilir; yalnız menüde olmayan alt sayfalar elle yazılır)
 * section : sayfadaki bölüm/kart/sekme  ("Duyuru bandı")
 * setting : kaydedilebilir ayar          ("Bakım modu")
 * field   : form alanı / filtre / sütun  ("Android en düşük sürüm")
 * action  : düğme / eylem                ("Zorunlu güncellemeyi yayınla")
 */
export type SearchKind = 'page' | 'section' | 'setting' | 'field' | 'action';

/** Sonuç listesinde kullanılan üç sınıf. */
export type SearchClass = 'pages' | 'settings' | 'actions';

export function classOf(kind: SearchKind): SearchClass {
  if (kind === 'page' || kind === 'section') return 'pages';
  if (kind === 'action') return 'actions';
  return 'settings';
}

/** Sayfa ajanlarının yazdığı girdi. */
export interface SearchEntry {
  /** Tüm kayıt defterinde benzersiz: `<sayfa>.<öğe>` (örn. `settings.maintenance_mode`). */
  id: string;
  kind: SearchKind;
  /** Kullanıcının ekranda gördüğü ad (Türkçe, ekrandaki metinle aynı). */
  title: string;
  /** Sayfanın menü kimliği (`adminNav.ts` öğe `id`'si, örn. `settings`). Yol, izin, grup ve simge buradan gelir. */
  page: string;
  /** Günlük dil, eş anlamlılar, yaygın yazımlar: "bakım modu", "siteyi kapat". */
  keywords?: string[];
  /** Tek cümlelik düz Türkçe açıklama (sonuçta ikinci satır). */
  description?: string;
  /** Sayfadaki öğenin `data-search-anchor` değeri; yoksa yalnız sayfa açılır. */
  anchor?: string;
  /** Kırıntıdaki ara başlık (örn. sekme/kart adı: "Bakım"). */
  section?: string;
  /** Menü öğesinin yolundan farklıysa (örn. `paths.admin.campaignNew`). Mutlaka `paths.admin.*` kullanın. */
  path?: string;
  /** Menü öğesinin izninden farklıysa (örn. yazma gerektiren eylem için `settings.write`). */
  perm?: Permission;
}

/** `build.ts` çıktısı: motorun ve arayüzün kullandığı çözümlenmiş girdi. */
export interface ResolvedEntry {
  id: string;
  kind: SearchKind;
  title: string;
  keywords: string[];
  description: string;
  /** Kendi başlığı hariç üst başlıklar: ["Sistem", "Ayarlar", "Bakım"]. */
  crumbs: string[];
  pageId: string;
  groupId: string;
  path: string;
  anchor?: string;
  /** `path#anchor` (anchor yoksa `path`). */
  to: string;
  perm?: Permission;
  icon: IconName;
}
