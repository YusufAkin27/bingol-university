import { useCallback, useEffect, useState, type RefObject } from 'react';

export interface ScrollEdges {
  /** Başlangıç kenarında gizli içerik var (kaydırılmış). */
  start: boolean;
  /** Bitiş kenarında gizli içerik var (daha fazlası yana kaydırılarak görünür). */
  end: boolean;
  /** Kullanıcı en az bir kez yana kaydırdı (ipucunu gizlemek için). */
  scrolled: boolean;
}

/**
 * Yatay kaydırılan kabın hangi kenarında gizli içerik olduğunu izler (ScrollShadow, Table, Tabs ortak kullanır).
 * RTL'de scrollLeft negatiftir: mutlak değer, başlangıç kenarından uzaklıktır. `onScroll` kabın onScroll'una bağlanır.
 */
export function useScrollEdges(
  ref: RefObject<HTMLElement>,
  /** Kap sonradan (hata/kart görünümünden tabloya dönünce) oluşuyorsa değişen bir anahtar verin: izleme yeniden kurulur. */
  watch?: unknown,
): { edges: ScrollEdges; onScroll: () => void } {
  const [edges, setEdges] = useState<ScrollEdges>({ start: false, end: false, scrolled: false });

  const update = useCallback(() => {
    const el = ref.current;
    if (!el) return;
    const max = el.scrollWidth - el.clientWidth;
    const pos = Math.abs(el.scrollLeft);
    setEdges((prev) => {
      const next = { start: pos > 1, end: max > 1 && pos < max - 1, scrolled: prev.scrolled || pos > 8 };
      return next.start === prev.start && next.end === prev.end && next.scrolled === prev.scrolled ? prev : next;
    });
  }, [ref]);

  useEffect(() => {
    update();
    const el = ref.current;
    if (!el) return undefined;
    const RO = (globalThis as { ResizeObserver?: typeof ResizeObserver }).ResizeObserver;
    const ro = RO ? new RO(update) : null;
    ro?.observe(el);
    if (el.firstElementChild) ro?.observe(el.firstElementChild);
    window.addEventListener('resize', update);
    return () => {
      ro?.disconnect();
      window.removeEventListener('resize', update);
    };
  }, [ref, update, watch]);

  return { edges, onScroll: update };
}
