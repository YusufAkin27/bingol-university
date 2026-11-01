// SAYFA: Yönetim paneli 404
// API: yok.
import { ButtonLink, EmptyState, PageHeader } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { paths } from '../../paths';

export default function AdminNotFoundPage() {
  const { t } = useI18n();
  return (
    <>
      <PageHeader title={t('admin.notFound.title')} />
      <EmptyState
        icon="search"
        title={t('admin.v2n.nf.title')}
        description={t('admin.v2n.nf.hint')}
        action={<ButtonLink to={paths.admin.dashboard}>{t('admin.v2n.nf.home')}</ButtonLink>}
      />
    </>
  );
}
