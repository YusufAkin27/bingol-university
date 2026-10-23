// SAYFA: 404 (tanıtım sitesi)
// API: yok.
import { EmptyState, ButtonLink } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import { paths } from '../../paths';

export default function NotFoundPage() {
  const { t } = useI18n();
  usePageTitle(t('site.notFound.title'));
  return (
    <div className="container" style={{ paddingBlock: 'var(--space-8)' }}>
      <EmptyState
        icon="search"
        title={t('site.notFound.title')}
        description={t('site.notFound.hint')}
        action={<ButtonLink to={paths.site.home}>{t('site.notFound.home')}</ButtonLink>}
      />
    </div>
  );
}
