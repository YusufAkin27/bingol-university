import { useEffect, useState } from 'react';

export type DomTheme = 'light' | 'dark';

/** Sayfanın o anki görünen teması: <html data-theme> (elle seçim) yoksa sistem tercihi. ThemeProvider gerektirmez (testte de çalışır). */
export function readDomTheme(): DomTheme {
  try {
    const attr = document.documentElement.getAttribute('data-theme');
    if (attr === 'dark' || attr === 'light') return attr;
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  } catch {
    return 'light';
  }
}

/** Tema değişince (düğme ya da sistem) yeniden çizilir; görselin doğru tema dosyasını seçmek için kullanılır. */
export function useDomTheme(): DomTheme {
  const [theme, setTheme] = useState<DomTheme>(readDomTheme);
  useEffect(() => {
    const sync = () => setTheme(readDomTheme());
    sync();
    let mo: MutationObserver | undefined;
    let mq: MediaQueryList | undefined;
    try {
      mo = new MutationObserver(sync);
      mo.observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] });
      mq = window.matchMedia('(prefers-color-scheme: dark)');
      mq.addEventListener?.('change', sync);
    } catch {
      /* eski tarayıcı / test ortamı: ilk değer yeterli */
    }
    return () => {
      mo?.disconnect();
      mq?.removeEventListener?.('change', sync);
    };
  }, []);
  return theme;
}
