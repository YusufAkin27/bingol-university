import { useQueries } from '@tanstack/react-query';
import { getUser } from '../../../api/users';
import { qk } from '../../../api/queryKeys';
import type { CampaignAudience, CampaignTarget } from '../../../api/types';
import { useI18n } from '../../../i18n/I18nProvider';

/** Kitle özeti: "Bölüm: Bilgisayar Mühendisliği", "12 seçili kullanıcı"... */
export function useAudienceSummary() {
  const { t, td } = useI18n();
  return (a: CampaignAudience): string => {
    switch (a.type) {
      case 'DEPARTMENT':
      case 'FACULTY':
        return `${t(`admin.campaigns.audience.${a.type}`)}: ${a.value ?? ''}`;
      case 'LANGUAGE':
        return `${t('admin.campaigns.audience.LANGUAGE')}: ${td(`admin.campaigns.lang.${a.value ?? 'tr'}`, a.value ?? 'tr')}`;
      case 'EMAILS':
        return t('admin.campaigns.audience.emailsValue', { n: a.value ? a.value.split(/[\s,;]+/).filter(Boolean).length : 0 });
      case 'CLASS_YEAR':
        return t('admin.campaigns.audience.classYearValue', { year: a.value ?? '' });
      case 'USERS':
        return t('admin.campaigns.audience.usersValue', { n: a.value ? a.value.split(',').length : 0 });
      default:
        return t(`admin.campaigns.audience.${a.type}`);
    }
  };
}

export function useTargetSummary() {
  const { t } = useI18n();
  return (x: CampaignTarget | null): string => {
    if (!x || x.type === 'NONE') return t('admin.campaigns.target.NONE');
    return `${t(`admin.campaigns.target.${x.type}`)}: ${x.value ?? ''}`;
  };
}

/** Kampanya listesindeki "oluşturan" kimliklerini kısa adlara çözer (kullanıcı başına bir kez önbelleğe alınır). */
export function useAdminNames(ids: number[]): Record<number, string> {
  const unique = Array.from(new Set(ids));
  const results = useQueries({
    queries: unique.map((id) => ({
      queryKey: qk.users.detail(id),
      queryFn: () => getUser(id),
      staleTime: 10 * 60 * 1000,
      retry: false,
    })),
  });
  const out: Record<number, string> = {};
  unique.forEach((id, i) => {
    const d = results[i]?.data;
    if (d) out[id] = d.displayName || d.email;
  });
  return out;
}
