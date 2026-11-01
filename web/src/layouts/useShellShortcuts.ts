import { useEffect, useRef, useState } from 'react';
import { GO_SHORTCUTS, GO_TIMEOUT_MS, isTypingTarget } from './shortcuts';

export interface ShellShortcutHandlers {
  onSearch: () => void;
  onHelp: () => void;
  onToggleSidebar: () => void;
  onToggleFavorite: () => void;
  /** Menü sayfası kimliğine git (izin denetimi çağıranda). */
  onGo: (page: string) => void;
}

/**
 * Panel klavye kısayolları. Yazı alanındayken, değiştirici tuş basılıyken ya da bir pencere (aria-modal) açıkken
 * tek tuşlu kısayollar çalışmaz; Ctrl/Cmd+K her yerde çalışır. Dönüş: "g" basıldı mı (ikinci tuş bekleniyor).
 */
export function useShellShortcuts(h: ShellShortcutHandlers): boolean {
  const ref = useRef(h);
  ref.current = h;
  const [goPending, setGoPending] = useState(false);

  useEffect(() => {
    let timer: ReturnType<typeof setTimeout> | undefined;
    let pending = false;
    const clear = () => {
      pending = false;
      setGoPending(false);
      if (timer) clearTimeout(timer);
    };

    const onKey = (e: KeyboardEvent) => {
      if (e.defaultPrevented) return;
      const key = e.key;
      if ((e.ctrlKey || e.metaKey) && key.toLowerCase() === 'k') {
        e.preventDefault();
        clear();
        ref.current.onSearch();
        return;
      }
      if (e.ctrlKey || e.metaKey || e.altKey) return;
      if (isTypingTarget(e.target)) return;
      if (document.querySelector('[aria-modal="true"]')) return;

      if (pending) {
        const hit = GO_SHORTCUTS.find((s) => s.key === key.toLowerCase());
        clear();
        if (hit) {
          e.preventDefault();
          ref.current.onGo(hit.page);
        }
        return;
      }
      if (key === 'g') {
        pending = true;
        setGoPending(true);
        timer = setTimeout(clear, GO_TIMEOUT_MS);
      } else if (key === '/') {
        e.preventDefault();
        ref.current.onSearch();
      } else if (key === '?') {
        e.preventDefault();
        ref.current.onHelp();
      } else if (key === '[') {
        ref.current.onToggleSidebar();
      } else if (key === 'f') {
        ref.current.onToggleFavorite();
      }
    };
    document.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('keydown', onKey);
      if (timer) clearTimeout(timer);
    };
  }, []);

  return goPending;
}
