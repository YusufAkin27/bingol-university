import { useEffect, useMemo } from 'react';
import { useLocation } from 'react-router-dom';
import { useI18n } from '../../../i18n/I18nProvider';
import { splitLangPath } from '../../../i18n/langPath';
import { buildHeadModel, pageUrl } from '../../../seo/headModel';
import { resolveMeta, routeById, type RouteId } from '../../../seo/routeMeta';
import { siteOrigin } from '../../../seo/siteUrl';
import { breadcrumbLd } from './jsonLd';

export interface PageMetaOptions {
  /**
   * seo/routeMeta.ts'teki rota kimliği: başlık, açıklama ve kanonik yol buradan gelir (tek kaynak).
   * Verilmezse `title`/`description` doğrudan kullanılır.
   */
  route?: RouteId;
  /** Rota başlığını (uygulama adı eki olmadan) ezer; API'den gelen başlıklar için. Boşsa yalnızca uygulama adı. */
  title?: string;
  description?: string;
  /** Kanonik MANTIKSAL yol (dil öneksiz). Varsayılan: rota yolu, yoksa geçerli yol. */
  path?: string;
  /** Yalnızca bilinen alanlarla JSON-LD nesne(ler)i. Rota sayfalarına BreadcrumbList otomatik eklenir. */
  jsonLd?: Record<string, unknown> | Record<string, unknown>[];
  noindex?: boolean;
}

/** Önrender çıktısındaki ve bu kancanın yazdığı yönetilen etiketler. */
const MANAGED = [
  'meta[name="description"]',
  'meta[name="robots"]',
  'meta[property^="og:"]',
  'meta[name^="twitter:"]',
  'link[rel="canonical"]',
  'link[rel="alternate"][hreflang]',
  'script[type="application/ld+json"][data-pre]',
].join(',');

/**
 * Sayfa başına `<title>`, meta description, Open Graph, Twitter kartı, canonical, hreflang, robots ve JSON-LD yazar;
 * sayfadan çıkınca önceki (önrender dışı) değerleri geri koyar. `lang`/`dir` I18nProvider tarafından yönetilir.
 * Derleme zamanında aynı değerleri `scripts/prerender.mjs` HTML'e gömer (aynı headModel + routeMeta).
 */
export function usePageMeta({ route, title, description, path, jsonLd, noindex }: PageMetaOptions) {
  const { lang, t } = useI18n();
  const location = useLocation();
  const meta = route ? routeById(route) : undefined;
  const origin = siteOrigin();
  const logicalPath = path ?? meta?.path ?? splitLangPath(location.pathname).rest;

  const { head, ldText } = useMemo(() => {
    const resolved = meta ? resolveMeta(meta, lang) : undefined;
    const appName = t('common.appName');
    const shownTitle = title ?? resolved?.title ?? '';
    const full = title === undefined && resolved ? resolved.fullTitle : shownTitle ? `${shownTitle} · ${appName}` : appName;
    const desc = description ?? resolved?.description;
    const model = buildHeadModel({ lang, origin, path: logicalPath, title: full, description: desc, appName, noindex });
    const blocks = jsonLd ? [...(Array.isArray(jsonLd) ? jsonLd : [jsonLd])] : [];
    if (meta && !meta.home) {
      blocks.push(
        breadcrumbLd([
          { name: t('site.nav.home'), url: pageUrl(origin, lang, '/') },
          { name: shownTitle, url: model.canonical },
        ]),
      );
    }
    return { head: model, ldText: blocks.map((b) => JSON.stringify(b)) };
  }, [meta, lang, t, title, description, jsonLd, logicalPath, noindex, origin]);

  const headKey = JSON.stringify(head);
  const ldKey = ldText.join('\n');

  useEffect(() => {
    const prevTitle = document.title;
    document.title = head.title;
    // Önceki yönetilen etiketleri kaldır; önrender çıktısı (data-pre) bayat sayılır, geri konmaz
    const prev = Array.from(document.head.querySelectorAll<HTMLElement>(MANAGED));
    prev.forEach((el) => el.remove());
    const added: HTMLElement[] = [];
    for (const m of head.metas) {
      const el = document.createElement('meta');
      el.setAttribute(m.attr, m.key);
      el.setAttribute('content', m.content);
      added.push(el);
    }
    for (const l of head.links) {
      const el = document.createElement('link');
      el.setAttribute('rel', l.rel);
      if (l.hreflang) el.setAttribute('hreflang', l.hreflang);
      el.setAttribute('href', l.href);
      added.push(el);
    }
    for (const text of ldText) {
      const el = document.createElement('script');
      el.setAttribute('type', 'application/ld+json');
      el.dataset.pageMeta = 'true';
      el.textContent = text;
      added.push(el);
    }
    added.forEach((el) => document.head.appendChild(el));
    return () => {
      document.title = prevTitle;
      added.forEach((el) => el.remove());
      prev.filter((el) => !el.hasAttribute('data-pre')).forEach((el) => document.head.appendChild(el));
    };
    // headKey/ldKey içerik değişimini temsil eder (nesne kimliği her render değişebilir)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [headKey, ldKey]);
}
