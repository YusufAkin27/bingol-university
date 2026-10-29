// SAYFA: Çocuk güvenliği standartları (/child-safety): Google Play CSAE beyanı için herkese açık URL.
// API: yok (statik). Metin yalnız uygulamada gerçekten var olanı anlatır (docs/MODERATION.md, docs/LEGAL_NOTES.md bölüm 11).
import { ButtonLink } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { paths } from '../../paths';
import { InfoPage, type SectionSpec } from './components/InfoPage';
import infoStyles from './components/InfoPage.module.css';

/** Çocuk Güvenliği İrtibat Noktası (Play beyanındaki iletişim); ad yazılmaz, rol olarak anılır. */
export const CHILD_SAFETY_EMAIL = 'ysufakin23@gmail.com';

export const CHILD_SAFETY_SECTIONS: SectionSpec[] = [
  { id: 's1', p: 3 },
  { id: 's2', p: 1, l: 6 },
  { id: 's3', p: 1, l: 5, pAfter: 1 },
  { id: 's4', p: 1, l: 5, pAfter: 1 },
  { id: 's5', p: 1, l: 6, pAfter: 1 },
  { id: 's6', p: 4 },
  { id: 's7', p: 1, l: 1 },
];

export default function ChildSafetyPage() {
  const { t } = useI18n();
  return (
    <InfoPage
      slug="childsafety"
      path={paths.site.childSafety}
      sections={CHILD_SAFETY_SECTIONS}
      after={{
        s6: (
          <div className={infoStyles.actions}>
            <ButtonLink to={paths.site.guidelines} variant="secondary">
              {t('pg.childsafety.rules')}
            </ButtonLink>
            <ButtonLink to={paths.site.legal('TERMS')} variant="secondary">
              {t('pg.childsafety.terms')}
            </ButtonLink>
          </div>
        ),
        s7: (
          <p>
            <a href={`mailto:${CHILD_SAFETY_EMAIL}`}>{t('pg.childsafety.mail')}</a>
          </p>
        ),
      }}
    />
  );
}
