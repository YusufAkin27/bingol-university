// Kuyruk sayfaları için klavye kısayolları: J/K (aşağı/yukarı), X (seç), A (birincil karar), R (ikincil karar), Esc (seçimi temizle).
// Yazı alanında, açık pencere varken ve Ctrl/Alt/Meta ile basıldığında çalışmaz (tarayıcı kısayollarını ezmez).
import { useCallback, useEffect, useRef, useState } from 'react';
import { clampIndex, shouldIgnoreShortcut } from './queueLogic';

export interface QueueKeysOptions {
  /** Listede görünen satır sayısı. */
  count: number;
  /** Kısayollar kapalıyken (örn. kapanmış sekme) hiçbir dinleyici eklenmez. */
  enabled: boolean;
  onToggle?: (index: number) => void;
  onPrimary?: (index: number) => void;
  onSecondary?: (index: number) => void;
  onClear?: () => void;
}

/** Etkin satır dizinini (yok = -1) ve kısayol dinleyicisini yönetir. Etkin satır görünür alana kaydırılır. */
export function useQueueKeys({ count, enabled, onToggle, onPrimary, onSecondary, onClear }: QueueKeysOptions) {
  const [active, setActive] = useState(-1);
  const handlers = useRef({ onToggle, onPrimary, onSecondary, onClear });
  handlers.current = { onToggle, onPrimary, onSecondary, onClear };
  const activeRef = useRef(active);
  activeRef.current = active;
  const countRef = useRef(count);
  countRef.current = count;

  // Liste kısalınca etkin dizin dışarıda kalmasın
  useEffect(() => {
    setActive((i) => (i < 0 ? i : clampIndex(i, count)));
  }, [count]);

  const move = useCallback((delta: number) => {
    setActive((i) => clampIndex(i < 0 ? (delta > 0 ? 0 : countRef.current - 1) : i + delta, countRef.current));
  }, []);

  useEffect(() => {
    if (!enabled) return;
    function onKey(e: KeyboardEvent) {
      if (shouldIgnoreShortcut(e)) return;
      const key = e.key.toLowerCase();
      const i = activeRef.current;
      const h = handlers.current;
      if (key === 'j') {
        e.preventDefault();
        move(1);
      } else if (key === 'k') {
        e.preventDefault();
        move(-1);
      } else if (key === 'x' && i >= 0 && h.onToggle) {
        e.preventDefault();
        h.onToggle(i);
      } else if (key === 'a' && i >= 0 && h.onPrimary) {
        e.preventDefault();
        h.onPrimary(i);
      } else if (key === 'r' && i >= 0 && h.onSecondary) {
        e.preventDefault();
        h.onSecondary(i);
      } else if (key === 'escape' && h.onClear) {
        h.onClear();
      }
    }
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [enabled, move]);

  return { active, setActive };
}
