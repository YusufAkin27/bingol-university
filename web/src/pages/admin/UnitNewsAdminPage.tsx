// SAYFA: Birim haberleri yönetimi (/admin/content/unit-news)
// API: /api/admin/unit-news/** (api/adminUnitNews.ts, sözleşme docs/UNIT_NEWS_API.md).
// Kaynaklar (aç/kapat, eşleme, bölümler, elle çekim), kaynak sağlığı özeti ve duyuru listesi (gizle/göster).
import { PageHeader } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import { gt } from './unitnews/dict';
import { AnnouncementsSection } from './unitnews/AnnouncementsSection';
import { SourceHealth } from './unitnews/SourceHealth';
import { SourcesSection, useUnitSources } from './unitnews/SourcesSection';
import styles from './unitnews/unitNews.module.css';

export default function UnitNewsAdminPage() {
  const i18n = useI18n();
  const t = gt(i18n);
  usePageTitle(t('admin.unitNews.title'));
  const sources = useUnitSources();

  return (
    <>
      <PageHeader title={t('admin.unitNews.title')} description={t('admin.unitNews.subtitle')} />
      <div className={styles.stack}>
        {sources.data && <SourceHealth sources={sources.data} />}
        <SourcesSection query={sources} />
        <AnnouncementsSection sources={sources.data} />
      </div>
    </>
  );
}
