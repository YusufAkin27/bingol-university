// Ayarlar > Mağaza ve sürümler sekmesinin üstündeki yönlendirme: zorlama ve dağılım yeni sayfadadır.
import { Link } from 'react-router-dom';
import { useI18n } from '../../../i18n/I18nProvider';
import { paths } from '../../../paths';
import { Callout } from '../campaigns/shared';

export function AppVersionsLink() {
  const { t } = useI18n();
  return (
    <Callout tone="info">
      {t('admin.uv.settingsLink')} <Link to={paths.admin.appVersions}>{t('admin.uv.settingsLinkBtn')}</Link>
    </Callout>
  );
}
