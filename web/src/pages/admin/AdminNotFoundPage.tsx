// SAYFA: Yönetim paneli 404
// API: yok.
import { EmptyState } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';

export default function AdminNotFoundPage() {
  const { t } = useI18n();
  return (
    <EmptyState icon="search" title={t('admin.notFound.title')} description={t('admin.notFound.hint')} />
  );
}
