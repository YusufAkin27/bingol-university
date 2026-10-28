// SAYFA: Kulüp içerik moderasyonu (/admin/content-review) — tüm kulüplerin gönderi + duyuruları tek listede.
// API: GET /api/admin/community-posts (süzgeç: kind, status, q, minReports, from/to, sort=reports), PATCH /{id} (metin),
// POST /{id}/hide|unhide, DELETE /{id} (api/adminCommunities.ts). Gizleme geri alınabilir; silme geri alınamaz (sebep zorunlu).
import { useNavigate } from 'react-router-dom';
import { PageHeader } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import { paths } from '../../paths';
import { ContentList } from './clubs/ContentList';

export default function ContentReviewPage() {
  const { t } = useI18n();
  const navigate = useNavigate();
  usePageTitle(t('admin.p06.review.title'));
  return (
    <div>
      <PageHeader title={t('admin.p06.review.title')} description={t('admin.p06.review.subtitle')} />
      <ContentList onOpenClub={(id) => navigate(`${paths.admin.communities}?club=${id}`)} />
    </div>
  );
}
