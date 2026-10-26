// SAYFA: Erişilebilirlik beyanı (/accessibility)
// API: yok (statik). Geri bildirim için iletişim sayfasına bağlanır.
import { ButtonLink } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { paths } from '../../paths';
import { InfoPage, type SectionSpec } from './components/InfoPage';

export const ACCESSIBILITY_SECTIONS: SectionSpec[] = [
  { id: 's1', p: 1 },
  { id: 's2', l: 6 },
  { id: 's3', l: 2 },
  { id: 's4', p: 1 },
  { id: 's5', p: 1 },
];

export default function AccessibilityPage() {
  const { t } = useI18n();
  return (
    <InfoPage
      slug="accessibility"
      path={paths.site.accessibility}
      sections={ACCESSIBILITY_SECTIONS}
      after={{ s4: <ButtonLink to={paths.site.contact}>{t('site.nav.contact')}</ButtonLink> }}
    />
  );
}
