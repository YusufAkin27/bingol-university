// SAYFA: Yönetim paneli 404
// API: yok.
import { EmptyState, PageHeader } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';

export default function AdminNotFoundPage() {
  const { t } = useI18n();
  return (
    <>
      <PageHeader title={t('admin.notFound.title')} />
      <EmptyState icon="search" title={t('admin.notFound.hint')} />
    </>
  );
}
