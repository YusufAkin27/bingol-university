/**
 * Derin bağlantı: arama sonucu `path#anchor` açar; hedef sayfa (lazy olabilir) yüklenince öğeyi bulur, gerekirse
 * sekme/açıklayıcıyı açtırır (useSearchReveal), görüntüye kaydırır ve ~2 sn vurgular.
 *
 * Sayfa tarafı:  <SearchAnchor id="x"> ...  </SearchAnchor>   ya da   <div data-search-anchor="x">
 * Sayfa sekmeli/açılırlıysa:  useSearchReveal((anchor) => { if (anchor ...) setTab('...') });
 * Kabuk tarafı:  AdminLayout içinde bir kez useSearchAnchorFocus() çağrılır.
 */
import { createElement, useEffect, useRef, type HTMLAttributes, type ReactNode } from 'react';
import { useLocation } from 'react-router-dom';
import { useToast } from '../components/ui/Toast';
import { useI18n } from '../i18n/I18nProvider';
import './search.module.css'; // vurgu stilleri (genel seçiciler)

const WAIT_MS = 3500;
const POLL_MS = 100;
const HIGHLIGHT_MS = 2200;
const ATTR = 'data-search-anchor';

/** Sayfaya özgü açma işlemleri (sekme seç, açıklayıcı aç). Aynı anchor için tekrar çağrılabilir: yan etkisiz olmalı. */
const revealers = new Set<(anchor: string) => void>();

/** Açıcılar çalışırken true: o sırada yapılan sekme değişimi aramadandır (karma korunur), kullanıcıdan gelen değildir. */
let revealing = false;

/** Şu an arama açıcısı mı çalışıyor? (useUrlTab: kullanıcı kaynaklı sekme değişiminde karmayı siler, arama kaynaklıda korur.) */
export function isSearchRevealing(): boolean {
  return revealing;
}

/** Sayfa, anchor'ı görünür kılmak için gereken durumu (sekme, accordion) ayarlayan işleyiciyi kaydeder. */
export function useSearchReveal(handler: (anchor: string) => void): void {
  const ref = useRef(handler);
  ref.current = handler;
  useEffect(() => {
    const fn = (a: string) => ref.current(a);
    revealers.add(fn);
    return () => {
      revealers.delete(fn);
    };
  }, []);
}

type AnchorTag = 'div' | 'section' | 'span' | 'li' | 'p';

/** Arama hedefi işaretleyicisi. Vurgulama kenarlık + gölge ile yapılır (yalnız renk/animasyon değil). */
export function SearchAnchor({
  id,
  as = 'div',
  children,
  ...rest
}: { id: string; as?: AnchorTag; children?: ReactNode } & Omit<HTMLAttributes<HTMLElement>, 'id'>) {
  return createElement(as, { ...rest, [ATTR]: id }, children);
}

function safeDecode(s: string): string {
  try {
    return decodeURIComponent(s);
  } catch {
    return s;
  }
}

function findAnchor(id: string): HTMLElement | null {
  const all = document.querySelectorAll<HTMLElement>(`[${ATTR}]`);
  for (const el of all) if (el.getAttribute(ATTR) === id) return el;
  return null;
}

const FOCUSABLE = 'a[href], button, input, select, textarea, [tabindex]';

function reduceMotion(): boolean {
  try {
    return window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  } catch {
    return false;
  }
}

/** Öğeyi açar/kaydırır/vurgular/odaklar; temizleme işlevi döner. */
function reveal(el: HTMLElement): () => void {
  for (let p = el.parentElement; p; p = p.parentElement) {
    if (p instanceof HTMLDetailsElement && !p.open) p.open = true;
  }
  document.querySelectorAll(`[data-search-hit]`).forEach((x) => x.removeAttribute('data-search-hit'));
  el.setAttribute('data-search-hit', 'true');
  const raf = requestAnimationFrame(() => {
    el.scrollIntoView?.({ block: 'center', behavior: reduceMotion() ? 'auto' : 'smooth' });
    // Ekran okuyucu ve klavye odağı hedefe taşınır; klavye açtırmamak için alana odaklanmaz
    const needsTabindex = !el.matches(FOCUSABLE) && !el.hasAttribute('tabindex');
    if (needsTabindex) el.setAttribute('tabindex', '-1');
    el.focus?.({ preventScroll: true });
  });
  const timer = window.setTimeout(() => el.removeAttribute('data-search-hit'), HIGHLIGHT_MS);
  return () => {
    cancelAnimationFrame(raf);
    window.clearTimeout(timer);
    el.removeAttribute('data-search-hit');
  };
}

/** Kabuk kancası: konum karması (`#anchor`) değişince hedefi bulup vurgular; bulunamazsa nazik uyarı verir. */
export function useSearchAnchorFocus(): void {
  const { hash, pathname, key } = useLocation();
  const toast = useToast();
  const { t } = useI18n();
  const toastRef = useRef(toast);
  toastRef.current = toast;
  const tRef = useRef(t);
  tRef.current = t;

  useEffect(() => {
    const id = safeDecode(hash.replace(/^#/, ''));
    if (!id) return;
    // "İçeriğe geç" gibi sayfa içi kimlikler arama bağlantısı değildir
    if (document.getElementById(id) && !findAnchor(id)) return;

    let done = false;
    let cleanup: (() => void) | null = null;
    const started = Date.now();

    const attempt = () => {
      if (done) return;
      revealing = true;
      try {
        revealers.forEach((fn) => fn(id));
      } finally {
        revealing = false;
      }
      const el = findAnchor(id);
      if (el) {
        done = true;
        stop();
        cleanup = reveal(el);
      } else if (Date.now() - started > WAIT_MS) {
        done = true;
        stop();
        toastRef.current.info(tRef.current('admin.search.notVisible'));
      }
    };

    const interval = window.setInterval(attempt, POLL_MS);
    let observer: MutationObserver | null = null;
    try {
      observer = new MutationObserver(attempt);
      observer.observe(document.body, { childList: true, subtree: true });
    } catch {
      observer = null;
    }
    function stop() {
      window.clearInterval(interval);
      observer?.disconnect();
    }
    attempt();
    return () => {
      done = true;
      stop();
      cleanup?.();
    };
  }, [hash, pathname, key]);
}
