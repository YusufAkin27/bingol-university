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
import { translate, hasKey, type TParams, type TranslationKey } from './index';
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
}: {
  children: ReactNode;
  initialLang?: Lang;
  /** Verilirse dil sabittir (yönetim paneli: tr): seçim yazılmaz, siteye ait tercih korunur. */
  forcedLang?: Lang;
}) {
  const [stateLang, setLangState] = useState<Lang>(initialLang ?? getCurrentLang);
  const lang = forcedLang ?? stateLang;

  // İlk boyamada <html lang dir> senkron olsun
  useEffect(() => {
    applyDocumentLang(lang);
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
        hasKey(key) ? bidi(translate(lang, key, params)) : (fallback ?? key.split('.').pop() ?? key),
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
  }, [lang, setLang]);

  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useI18n(): I18n {
  const v = useContext(Ctx);
  if (!v) throw new Error('useI18n yalnızca <I18nProvider> içinde kullanılabilir');
  return v;
}
