// SAYFA: Hesap silme talimatı (/delete-account) — Google Play için herkese açık URL.
// API: yok (statik). Silme uygulamadan yapılır (DELETE hesap = anonimleştirme); veri talebi sayfasına bağlanır.
import { ButtonLink } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { paths } from '../../paths';
import { InfoPage, type SectionSpec } from './components/InfoPage';
import styles from './components/InfoPage.module.css';

export const DELETE_SECTIONS: SectionSpec[] = [
  { id: 's1', p: 1, o: 4 },
  { id: 's2', l: 4 },
  { id: 's3', p: 1 },
  { id: 's4', p: 1 },
  { id: 's5', p: 1 },
];

export default function DeleteAccountPage() {
  const { t } = useI18n();
  return (
    <InfoPage
      slug="delete"
      path={paths.site.deleteAccount}
      sections={DELETE_SECTIONS}
      after={{
        s4: (
          <div className={styles.actions}>
            <ButtonLink to={paths.site.dataRequest}>{t('site.dataRequest.title')}</ButtonLink>
            <ButtonLink to={paths.site.contact} variant="secondary">
              {t('site.nav.contact')}
            </ButtonLink>
          </div>
        ),
        s5: (
          <div className={styles.actions}>
            <ButtonLink to={paths.site.privacy} variant="secondary">
              {t('legal.title.PRIVACY')}
            </ButtonLink>
            <ButtonLink to={paths.site.legal('KVKK')} variant="secondary">
              {t('legal.title.KVKK')}
            </ButtonLink>
          </div>
        ),
      }}
    />
  );
}
