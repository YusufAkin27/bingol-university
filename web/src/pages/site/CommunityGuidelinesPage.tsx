// SAYFA: Topluluk kuralları özeti (/community-guidelines): moderasyon, raporlama, itiraz (docs/MODERATION.md ile tutarlı).
// API: yok (statik). Bağlayıcı metin: /legal/community-rules.
import { ButtonLink } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { paths } from '../../paths';
import { InfoPage, type SectionSpec } from './components/InfoPage';

export const GUIDELINES_SECTIONS: SectionSpec[] = [
  { id: 's1', l: 4 },
  { id: 's2', p: 1, l: 3 },
  { id: 's3', p: 1, l: 4, pAfter: 1 },
  { id: 's4', p: 2 },
  { id: 's5', p: 1 },
];

export default function CommunityGuidelinesPage() {
  const { t } = useI18n();
  return (
    <InfoPage
      slug="guidelines"
      path={paths.site.guidelines}
      sections={GUIDELINES_SECTIONS}
      after={{
        s5: <ButtonLink to={paths.site.legal('COMMUNITY_RULES')}>{t('pg.guidelines.fullText')}</ButtonLink>,
      }}
    />
  );
}
