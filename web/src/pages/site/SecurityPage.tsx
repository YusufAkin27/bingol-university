// SAYFA: Güvenlik ve güvenlik açığı bildirimi (/security)
// API: GET /api/app/info (supportEmail ?? contactEmail) → bildirim adresi. "Uçtan uca şifreleme" İDDİA EDİLMEZ.
import { useAppInfo } from '../../api/hooks';
import { ButtonLink } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { paths } from '../../paths';
import { InfoPage, type SectionSpec } from './components/InfoPage';

export const SECURITY_SECTIONS: SectionSpec[] = [
  { id: 's1', l: 6 },
  { id: 's2', p: 1, l: 4 },
  { id: 's3', l: 2 },
  { id: 's4', p: 1 },
  { id: 's5', l: 3 },
];

export default function SecurityPage() {
  const { t } = useI18n();
  const info = useAppInfo();
  const email = info.data?.supportEmail ?? info.data?.contactEmail ?? null;
  return (
    <InfoPage
      slug="security"
      path={paths.site.security}
      sections={SECURITY_SECTIONS}
      after={{
        s4: (
          <>
            {email ? (
              <p>
                <a href={`mailto:${email}`} className="ltr">
                  {email}
                </a>
              </p>
            ) : (
              info.isSuccess && <p>{t('pg.security.contactNone')}</p>
            )}
            <p>
              <a href="/.well-known/security.txt">{t('pg.security.txt')}</a>
            </p>
            <div>
              <ButtonLink to={paths.site.contact} variant="secondary">
                {t('site.nav.contact')}
              </ButtonLink>
            </div>
          </>
        ),
      }}
    />
  );
}
