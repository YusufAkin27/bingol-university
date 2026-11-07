// Sohbet akışında güvenli ve hızlı gezinme: bulanık gösterim tercihi (tarayıcıda hatırlanır) ve J/K ile satır gezinmesi.
import { useCallback, useEffect, useState, type RefObject } from 'react';
import { readStorage, writeStorage } from '../../../lib/storage';

const SAFE_KEY = 'bu.admin.chatSafeView';

/** Güvenli gösterim varsayılan AÇIK: yönetici istemeden hassas görselle karşılaşmasın. Tercih bu tarayıcıda saklanır. */
export function useSafeView(): [boolean, (v: boolean) => void] {
  const [safe, setSafeState] = useState(() => readStorage('local', SAFE_KEY) !== '0');
  const setSafe = useCallback((v: boolean) => {
    setSafeState(v);
    writeStorage('local', SAFE_KEY, v ? '1' : '0');
  }, []);
  return [safe, setSafe];
}

/** J/K gezinmesinde bir sonraki satır: sınırda durur; satır yoksa -1; henüz hiçbiri seçili değilken J ilkine, K sonuncuya gider. */
export function nextRowIndex(current: number, delta: 1 | -1, length: number): number {
  if (length <= 0) return -1;
  if (current < 0) return delta === 1 ? 0 : length - 1;
  return Math.min(length - 1, Math.max(0, current + delta));
}

function isTyping(t: EventTarget | null): boolean {
  const el = t as HTMLElement | null;
  return !!el && !!el.tagName && (/^(INPUT|TEXTAREA|SELECT)$/.test(el.tagName) || el.isContentEditable);
}

/**
 * Kapsayıcı içindeki `rowSelector` satırlarında J (sonraki) / K (önceki) ile gezinir. Yazı alanında, değiştirici tuşla
 * ya da bir pencere (büyük görüntüleyici, diyalog) açıkken çalışmaz.
 */
export function useRowKeyNav(scope: RefObject<HTMLElement | null>, rowSelector: string) {
  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if ((e.key !== 'j' && e.key !== 'k') || e.ctrlKey || e.metaKey || e.altKey || isTyping(e.target)) return;
      if (document.querySelector('[role="dialog"]')) return;
      const root = scope.current;
      if (!root) return;
      const rows = Array.from(root.querySelectorAll<HTMLElement>(rowSelector));
      if (rows.length === 0) return;
      let cur = rows.findIndex((r) => r.contains(document.activeElement));
      if (cur < 0) {
        // Odak satırda değilse ekranda görünen ilk satırın bir öncesinden başla
        const firstVisible = rows.findIndex((r) => r.getBoundingClientRect().top >= 64);
        cur = firstVisible < 0 ? rows.length - 1 : firstVisible - 1;
        if (cur < 0) cur = -1;
      }
      const next = nextRowIndex(cur, e.key === 'j' ? 1 : -1, rows.length);
      if (next < 0) return;
      e.preventDefault();
      const row = rows[next];
      row.tabIndex = -1;
      row.focus({ preventScroll: true });
      row.scrollIntoView?.({ block: 'center' });
    }
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [scope, rowSelector]);
}

/** Sayfa yeterince aşağı kaydırıldıysa true ("Başa dön" düğmesi için). */
export function useScrolledPast(px: number): boolean {
  const [past, setPast] = useState(false);
  useEffect(() => {
    const on = () => setPast(window.scrollY > px);
    on();
    window.addEventListener('scroll', on, { passive: true });
    return () => window.removeEventListener('scroll', on);
  }, [px]);
  return past;
}
