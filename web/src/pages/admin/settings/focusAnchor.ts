// Sayfa içi atlama: data-search-anchor hedefini (sekme değişimi sonrası geç çizilebilir) bulur, kaydırır ve ~2 sn vurgular.
const ATTR = 'data-search-anchor';

function find(id: string): HTMLElement | null {
  for (const el of document.querySelectorAll<HTMLElement>(`[${ATTR}]`)) {
    if (el.getAttribute(ATTR) === id) return el;
  }
  return null;
}

/** Hedef çizilene dek (en çok ~3 sn) dener; bulunamazsa sessizce vazgeçer. */
export function focusAnchor(id: string, tries = 30): void {
  let n = 0;
  const step = () => {
    const el = find(id);
    if (el) {
      let reduce = false;
      try {
        reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
      } catch {
        /* eski tarayıcı */
      }
      el.scrollIntoView?.({ block: 'center', behavior: reduce ? 'auto' : 'smooth' });
      el.setAttribute('data-search-hit', 'true');
      window.setTimeout(() => el.removeAttribute('data-search-hit'), 2200);
      return;
    }
    if (++n < tries) window.setTimeout(step, 100);
  };
  step();
}
