// Kaydedilmemiş iş koruması: `active` iken sekme kapatma/yenileme (beforeunload) ve uygulama içi bağlantı tıklamaları onay ister.
// Router veri yönlendiricisi olmadığından `useBlocker` yoktur: bağlantılar belge düzeyinde yakalanır (React Router'dan önce).
import { useEffect } from 'react';

let guards = 0;
let message = '';

export function useUnsavedGuard(active: boolean, text: string): void {
  useEffect(() => {
    if (!active) return;
    guards++;
    message = text;
    return () => {
      guards--;
    };
  }, [active, text]);
}

function onBeforeUnload(e: BeforeUnloadEvent) {
  if (guards > 0) {
    e.preventDefault();
    e.returnValue = '';
  }
}

function onClick(e: MouseEvent) {
  if (guards === 0 || e.defaultPrevented || e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey) return;
  const a = (e.target as Element | null)?.closest?.('a[href]') as HTMLAnchorElement | null;
  if (!a || a.target === '_blank' || a.hasAttribute('download')) return;
  const url = new URL(a.href, window.location.href);
  if (url.origin !== window.location.origin) return;
  // aynı sayfa içi (yalnız sekme parametresi) gezinti kayıp değildir
  if (url.pathname === window.location.pathname) return;
  if (!window.confirm(message)) {
    e.preventDefault();
    e.stopPropagation();
  }
}

if (typeof window !== 'undefined') {
  window.addEventListener('beforeunload', onBeforeUnload);
  document.addEventListener('click', onClick, true);
}
