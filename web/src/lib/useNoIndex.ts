import { useEffect } from 'react';

/** Yonetim sayfalari arama motorlarina kapali: robots meta etiketi sayfa acikken eklenir. */
export function useNoIndex() {
  useEffect(() => {
    const m = document.createElement('meta');
    m.name = 'robots';
    m.content = 'noindex, nofollow, noarchive';
    document.head.appendChild(m);
    return () => {
      m.remove();
    };
  }, []);
}
