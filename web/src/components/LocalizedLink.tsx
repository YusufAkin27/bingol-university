import { forwardRef, useCallback } from 'react';
import {
  Link as RouterLink,
  NavLink as RouterNavLink,
  useNavigate,
  type LinkProps,
  type NavLinkProps,
  type NavigateOptions,
  type To,
} from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import { localizePath } from '../i18n/langPath';
import type { Lang } from '../i18n/lang';

function localizeTo(to: To, lang: Lang): To {
  if (typeof to === 'string') return localizePath(to, lang);
  return to.pathname ? { ...to, pathname: localizePath(to.pathname, lang) } : to;
}

/**
 * Site içi bağlantılar: mantıksal yolu (`paths.site.*`) geçerli dilin önekiyle birleştirir.
 * Yönetim yolları ve dış bağlantılar olduğu gibi kalır; react-router `Link`/`NavLink` yerine kullanılır.
 */
export const Link = forwardRef<HTMLAnchorElement, LinkProps>(function Link({ to, ...rest }, ref) {
  const { lang } = useI18n();
  return <RouterLink ref={ref} to={localizeTo(to, lang)} {...rest} />;
});

export const NavLink = forwardRef<HTMLAnchorElement, NavLinkProps>(function NavLink({ to, ...rest }, ref) {
  const { lang } = useI18n();
  return <RouterNavLink ref={ref} to={localizeTo(to, lang)} {...rest} />;
});

/** Mantıksal yolu geçerli dil önekli yola çevirir: `useLocalizedPath()('/privacy')` → `/tr/privacy`. */
export function useLocalizedPath(): (to: string) => string {
  const { lang } = useI18n();
  return useCallback((to: string) => localizePath(to, lang), [lang]);
}

/** `navigate` ile aynı, ama mantıksal site yollarına dil öneki ekler. */
export function useLocalizedNavigate(): (to: string, opts?: NavigateOptions) => void {
  const navigate = useNavigate();
  const localize = useLocalizedPath();
  return useCallback((to: string, opts?: NavigateOptions) => navigate(localize(to), opts), [navigate, localize]);
}
