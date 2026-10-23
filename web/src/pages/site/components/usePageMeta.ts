import { useEffect } from 'react';
import { useLocation } from 'react-router-dom';
import { useI18n } from '../../../i18n/I18nProvider';

export interface PageMetaOptions {
  /** Boşsa yalnızca uygulama adı kullanılır. */
  title: string;
  description?: string;
  /** Kanonik yol (varsayılan: geçerli yol). */
  path?: string;
  /** Yalnızca bilinen alanlarla JSON-LD nesne(ler)i. */
  jsonLd?: Record<string, unknown> | Record<string, unknown>[];
  noindex?: boolean;
}

const OG_LOCALE = { tr: 'tr_TR', en: 'en_US', ar: 'ar_AR' } as const;

type Undo = () => void;

/** `<head>` içinde etiketi bulur ya da oluşturur; temizlikte eski hâline döndürür. */
function upsert(tag: 'meta' | 'link', key: string, keyValue: string, attr: string, value: string): Undo {
  let el = document.head.querySelector<HTMLElement>(`${tag}[${key}="${keyValue}"]`);
  const created = !el;
  const prev = el?.getAttribute(attr) ?? null;
  if (!el) {
    el = document.createElement(tag);
    el.setAttribute(key, keyValue);
    document.head.appendChild(el);
  }
  el.setAttribute(attr, value);
  return () => {
    if (created) el?.remove();
    else if (prev !== null) el?.setAttribute(attr, prev);
  };
}

/**
 * Sayfa başına `<title>`, meta description, Open Graph, canonical, robots ve JSON-LD yazar;
 * sayfadan çıkınca önceki değerleri geri koyar. `lang`/`dir` I18nProvider tarafından yönetilir.
 */
export function usePageMeta({ title, description, path, jsonLd, noindex }: PageMetaOptions) {
  const { t, lang } = useI18n();
  const location = useLocation();
  const appName = t('common.appName');
  const canonicalPath = path ?? location.pathname;
  const ldText = jsonLd ? JSON.stringify(jsonLd) : '';

  useEffect(() => {
    const origin = window.location.origin;
    const full = title ? `${title} · ${appName}` : appName;
    const url = `${origin}${canonicalPath === '/' ? '/' : canonicalPath.replace(/\/$/, '')}`;
    const prevTitle = document.title;
    document.title = full;
    const undo: Undo[] = [() => (document.title = prevTitle)];
    if (description) {
      undo.push(upsert('meta', 'name', 'description', 'content', description));
      undo.push(upsert('meta', 'property', 'og:description', 'content', description));
    }
    undo.push(upsert('meta', 'property', 'og:title', 'content', full));
    undo.push(upsert('meta', 'property', 'og:type', 'content', 'website'));
    undo.push(upsert('meta', 'property', 'og:url', 'content', url));
    undo.push(upsert('meta', 'property', 'og:site_name', 'content', appName));
    undo.push(upsert('meta', 'property', 'og:locale', 'content', OG_LOCALE[lang]));
    undo.push(upsert('meta', 'property', 'og:image', 'content', `${origin}/og.png`));
    undo.push(upsert('meta', 'name', 'twitter:card', 'content', 'summary_large_image'));
    undo.push(upsert('link', 'rel', 'canonical', 'href', url));
    if (noindex) undo.push(upsert('meta', 'name', 'robots', 'content', 'noindex'));
    let script: HTMLScriptElement | null = null;
    if (ldText) {
      script = document.createElement('script');
      script.type = 'application/ld+json';
      script.dataset.pageMeta = 'true';
      script.textContent = ldText;
      document.head.appendChild(script);
    }
    return () => {
      undo.reverse().forEach((u) => u());
      script?.remove();
    };
  }, [title, description, canonicalPath, ldText, noindex, appName, lang]);
}
