import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useLayoutEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import { isolateLatinIdentifiers } from './bidi';
import type { TParams, TranslationKey } from './index';
import { hasKey, isLoaded, loadDictionary, translate, type DictScope } from './registry';
import {
  applyDocumentLang,
  dirOf,
  getCurrentLang,
  getSiteLang,
  localeOf,
  setCurrentLang,
  setForcedLang,
  type Dir,
  type Lang,
} from './lang';

export interface I18n {
  lang: Lang;
  dir: Dir;
  locale: string;
  setLang: (lang: Lang) => void;
  /** Tipli anahtarla çeviri. */
  t: (key: TranslationKey, params?: TParams) => string;
  /** Çalışma zamanında üretilen anahtar (örn. `admin.users.status.${s}`); yoksa fallback ya da anahtarın sonu. */
  td: (key: string, fallback?: string, params?: TParams) => string;
  formatDate: (value: string | number | Date | null | undefined, opts?: Intl.DateTimeFormatOptions) => string;
  formatDateTime: (value: string | number | Date | null | undefined) => string;
  formatNumber: (n: number, opts?: Intl.NumberFormatOptions) => string;
}

const Ctx = createContext<I18n | null>(null);

function toDate(v: string | number | Date | null | undefined): Date | null {
  if (v === null || v === undefined || v === '') return null;
  // yyyy-MM-dd değerleri yerel gece yarısı olarak yorumla (saat dilimi kayması olmasın)
  const d = typeof v === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(v) ? new Date(`${v}T00:00:00`) : new Date(v);
  return Number.isNaN(d.getTime()) ? null : d;
}

export function I18nProvider({
  children,
  initialLang,
  forcedLang,
  scope = 'site',
}: {
  children: ReactNode;
  initialLang?: Lang;
  /** Verilirse dil sabittir (yönetim paneli: tr): seçim yazılmaz, siteye ait tercih korunur. */
  forcedLang?: Lang;
  /** Yüklenecek sözlük kapsamı: 'admin' site sözlüğüne ek olarak yönetim sözlüğünü de indirir (yalnız /admin). */
  scope?: DictScope;
}) {
  const [stateLang, setLangState] = useState<Lang>(initialLang ?? getCurrentLang);
  const wanted = forcedLang ?? stateLang;
  const scopes = useMemo<DictScope[]>(() => (scope === 'admin' ? ['site', 'admin'] : ['site']), [scope]);
  const ready = (l: Lang) => scopes.every((s) => isLoaded(l, s));

  // Sözlük dil başına lazy yüklenir: yüklenene dek önceki dil gösterilir (ilk açılışta hiçbir şey çizilmez, yanıp sönme olmaz).
  // Yükleme hatasında görünen dil korunur; hiç dil yoksa Türkçe yedeğe, o da yoksa anahtar metinlerine düşülür.
  const [shown, setShown] = useState<Lang | null>(() => (ready(wanted) ? wanted : null));
  const lang: Lang | null = ready(wanted) ? wanted : shown;

  useEffect(() => {
    if (ready(wanted)) {
      setShown(wanted);
      return;
    }
    let cancelled = false;
    const loadAll = (l: Lang) => Promise.all(scopes.map((s) => loadDictionary(l, s)));
    loadAll(wanted).then(
      () => {
        if (!cancelled) setShown(wanted);
      },
      () => {
        if (cancelled) return;
        if (shown) return;
        loadAll('tr').then(
          () => !cancelled && setShown('tr'),
          () => !cancelled && setShown(wanted),
        );
      },
    );
    return () => {
      cancelled = true;
    };
    // ready/shown türevleri: yalnız hedef dil ve kapsam değişince yeniden dene
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [wanted, scopes]);

  const effective: Lang = lang ?? wanted;

  // İlk boyamada <html lang dir> senkron olsun (görünen dile göre)
  useEffect(() => {
    if (lang) applyDocumentLang(lang);
  }, [lang]);

  // Sabitleme: API istekleri (Accept-Language) de bu dili kullanır; çıkınca site dili geri gelir
  // (layout effect: alt bileşenlerin ilk istekleri atılmadan önce devreye girsin)
  useLayoutEffect(() => {
    if (!forcedLang) return;
    setForcedLang(forcedLang);
    applyDocumentLang(forcedLang);
    return () => {
      setForcedLang(null);
      applyDocumentLang(getSiteLang());
    };
  }, [forcedLang]);

  const setLang = useCallback(
    (next: Lang) => {
      if (forcedLang) return;
      setCurrentLang(next);
      setLangState(next);
    },
    [forcedLang],
  );

  const value = useMemo<I18n>(() => {
    const lang = effective;
    const locale = localeOf(lang);
    // Arapça cümle içindeki alan adı/e-posta/URL soldan sağa yalıtılır (bkz. bidi.ts)
    const bidi = lang === 'ar' ? isolateLatinIdentifiers : (s: string) => s;
    return {
      lang,
      dir: dirOf(lang),
      locale,
      setLang,
      t: (key, params) => bidi(translate(lang, key, params)),
      td: (key, fallback, params) =>
        hasKey(key, lang) ? bidi(translate(lang, key, params)) : (fallback ?? key.split('.').pop() ?? key),
      formatDate: (v, opts) => {
        const d = toDate(v);
        return d ? new Intl.DateTimeFormat(locale, opts ?? { dateStyle: 'medium' }).format(d) : '—';
      },
      formatDateTime: (v) => {
        const d = toDate(v);
        return d
          ? new Intl.DateTimeFormat(locale, { dateStyle: 'medium', timeStyle: 'short' }).format(d)
          : '—';
      },
      formatNumber: (n, opts) => new Intl.NumberFormat(locale, opts).format(n),
    };
  }, [effective, setLang]);

  // Hiçbir sözlük yokken (ilk yükleme) anahtar metni göstermemek için çizimi ertele
  if (lang === null) return null;
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useI18n(): I18n {
  const v = useContext(Ctx);
  if (!v) throw new Error('useI18n yalnızca <I18nProvider> içinde kullanılabilir');
  return v;
}
