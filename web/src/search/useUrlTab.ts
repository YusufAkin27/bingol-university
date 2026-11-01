/**
 * Sekme durumunu URL'de (`?tab=...`) tutar: sayfa yenilenince/bağlantı paylaşılınca aynı sekme açılır ve arama
 * derin bağlantısı (`path#anchor`) sekmeyi açabilir (useSearchReveal içinden `setTab`).
 *  - Geçersiz/eksik değer varsayılan sekmeye düşer; varsayılan sekme URL'ye yazılmaz (temiz adres).
 *  - Değişim `replace` ile yapılır (geri düğmesi sekme geçmişiyle dolmaz) ve `#hash` KORUNUR (setSearchParams hash'i düşürür).
 *  - Kural: `tab-<değer>` biçimli anchor (örn. `tab-queues`) o sekmeyi açar (çoklu sekme grubunda `param` önekli: `<param>-<değer>`).
 *  - Aynı değeri tekrar atamak hiçbir şey yapmaz (açıcılar arama sırasında tekrar çağrılabilir).
 */
import { useCallback } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { useSearchReveal } from './anchor';

export function useUrlTab<T extends string>(
  values: readonly T[],
  initial: T,
  param = 'tab',
): [T, (next: T) => void] {
  const { pathname, search, hash } = useLocation();
  const navigate = useNavigate();
  const raw = new URLSearchParams(search).get(param);
  const tab = (values as readonly string[]).includes(raw ?? '') ? (raw as T) : initial;

  const setTab = useCallback(
    (next: T) => {
      if (next === tab) return;
      const params = new URLSearchParams(search);
      if (next === initial) params.delete(param);
      else params.set(param, next);
      const q = params.toString();
      navigate({ pathname, search: q ? `?${q}` : '', hash }, { replace: true });
    },
    [tab, search, pathname, hash, initial, param, navigate],
  );

  // `tab-queues` gibi anchor'lar ilgili sekmeyi açar (sekme içeriği o anchor'ı taşır)
  useSearchReveal((anchor) => {
    const prefix = `${param}-`;
    if (!anchor.startsWith(prefix)) return;
    const v = anchor.slice(prefix.length);
    if ((values as readonly string[]).includes(v)) setTab(v as T);
  });

  return [tab, setTab];
}
