import { useEffect } from 'react';

/**
 * Kaydedilmemiş değişiklik koruması: sekme kapatma/yenileme (beforeunload) ve uygulama içi bağlantı tıklamaları.
 * (BrowserRouter kullanıldığı için useBlocker yok; iç bağlantılar yakalama aşamasında onaylatılır.)
 */
export function useUnsavedGuard(dirty: boolean, message: string): void {
  useEffect(() => {
    if (!dirty) return;
    const onBeforeUnload = (e: BeforeUnloadEvent) => {
      e.preventDefault();
      e.returnValue = '';
    };
    const onClick = (e: MouseEvent) => {
      if (e.defaultPrevented || e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
      const a = (e.target as Element | null)?.closest?.('a[href]') as HTMLAnchorElement | null;
      if (!a || a.target === '_blank' || a.origin !== window.location.origin) return;
      if (a.pathname === window.location.pathname) return;
      if (!window.confirm(message)) {
        e.preventDefault();
        e.stopPropagation();
      }
    };
    window.addEventListener('beforeunload', onBeforeUnload);
    document.addEventListener('click', onClick, true);
    return () => {
      window.removeEventListener('beforeunload', onBeforeUnload);
      document.removeEventListener('click', onClick, true);
    };
  }, [dirty, message]);
}
