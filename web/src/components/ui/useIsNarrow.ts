import { useMediaQuery } from '../../lib/useMediaQuery';

/**
 * Ekran `breakpoint` pikselden dar mı (varsayılan 640: telefon)? matchMedia yoksa (sunucu, bazı testler) false döner.
 * İlk değer eşzamanlı okunur; böylece ilk boyamada tablo-kart sıçraması olmaz.
 */
export function useIsNarrow(breakpoint = 640): boolean {
  return useMediaQuery(`(max-width: ${breakpoint - 0.02}px)`);
}
