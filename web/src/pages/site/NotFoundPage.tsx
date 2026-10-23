// SAYFA: 404 (tanıtım sitesi)
// API: yok. Not: routes.tsx'te '/legal' (liste) rotası olmadığından bu yol burada LegalListPage'e yönlendirilir.
import { useLocation } from 'react-router-dom';
import { EmptyState, ButtonLink } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { paths } from '../../paths';
import { useHeadingFocus } from './components/PageHero';
import { usePageMeta } from './components/usePageMeta';
import LegalListPage from './LegalListPage';

export default function NotFoundPage() {
  const { pathname } = useLocation();
  if (/^\/legal\/?$/.test(pathname)) return <LegalListPage />;
  return <NotFound />;
}

function NotFound() {
  const { t } = useI18n();
  const wrap = useHeadingFocus<HTMLDivElement>();
  usePageMeta({ title: t('site.notFound.title'), noindex: true });
  return (
    <div ref={wrap} tabIndex={-1} className="container" style={{ paddingBlock: 'var(--space-8)', outline: 'none' }}>
      <EmptyState
        icon="search"
        title={t('site.notFound.title')}
        description={t('site.notFound.hint')}
        action={<ButtonLink to={paths.site.home}>{t('site.notFound.home')}</ButtonLink>}
      />
    </div>
  );
}
