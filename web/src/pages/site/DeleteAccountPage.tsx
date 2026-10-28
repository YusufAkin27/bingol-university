// SAYFA: Hesap silme talimatı (/delete-account) — Google Play "veri silme" gereği için herkese açık URL.
// API: yok (statik). Silme uygulamadan yapılır (hesap silme = anonimleştirme); uygulamasız talep /data-request'e bağlanır.
// Geliştirici adı GET /api/app/info -> operatorName (ayar legal.controller.name); ayar boşsa yalnız "Bağımsız uygulama".
// Saklama süreleri backend ayarlarıyla uyumludur: analitik ham olay 45 gün (app.dbmaint.analytics-raw-days),
// cihaz günlüğü 90 gün, bildirim 30/90 gün (app.notification.*), mail kuyruğu 7/30 gün, herkese açık destek 365 gün.
import { useAppInfo } from '../../api/hooks';
import { ButtonLink } from '../../components/ui';
import type { TranslationKey } from '../../i18n';
import { useI18n } from '../../i18n/I18nProvider';
import { paths } from '../../paths';
import { InfoPage, type SectionSpec } from './components/InfoPage';
import infoStyles from './components/InfoPage.module.css';
import styles from './DeleteAccountPage.module.css';

export const DELETE_SECTIONS: SectionSpec[] = [
  { id: 's1', p: 1, o: 4 },
  { id: 's2', l: 4 },
  { id: 's6', p: 1 },
  { id: 's3', p: 1 },
  { id: 's4', p: 1 },
  { id: 's5', p: 1 },
];

/** Tablo satır sayısı; her satır pg.delete.t.r<n>.a|b|c (veri, işlem, süre). */
export const DELETE_TABLE_ROWS = 10;

export function deleteTableKeys(): string[] {
  const keys = ['pg.delete.t.caption', 'pg.delete.t.data', 'pg.delete.t.action', 'pg.delete.t.period'];
  for (let i = 1; i <= DELETE_TABLE_ROWS; i++) for (const c of ['a', 'b', 'c']) keys.push(`pg.delete.t.r${i}.${c}`);
  return keys;
}

export default function DeleteAccountPage() {
  const { t } = useI18n();
  const k = (s: string) => t(s as TranslationKey);
  // Geliştirici/işleten adı sözleşmelerle aynı ayardan (legal.controller.name) gelir; sabit kodlanmaz.
  const operatorName = useAppInfo().data?.operatorName?.trim();
  return (
    <InfoPage
      slug="delete"
      path={paths.site.deleteAccount}
      sections={DELETE_SECTIONS}
      intro={
        <p className={styles.app} data-testid="delete-app-line">
          {operatorName
            ? t('pg.delete.app', { app: t('common.appName'), dev: operatorName })
            : t('pg.delete.app.nodev', { app: t('common.appName') })}
        </p>
      }
      after={{
        s6: (
          <div className={styles.wrap} role="region" aria-label={t('pg.delete.t.caption')} tabIndex={0}>
            <table className={styles.table} role="table">
              <caption className="sr-only">{t('pg.delete.t.caption')}</caption>
              <thead className={styles.thead} role="rowgroup">
                <tr role="row">
                  <th scope="col" role="columnheader">{t('pg.delete.t.data')}</th>
                  <th scope="col" role="columnheader">{t('pg.delete.t.action')}</th>
                  <th scope="col" role="columnheader">{t('pg.delete.t.period')}</th>
                </tr>
              </thead>
              <tbody role="rowgroup">
                {Array.from({ length: DELETE_TABLE_ROWS }, (_, i) => (
                  <tr key={i} role="row">
                    <th scope="row" role="rowheader">{k(`pg.delete.t.r${i + 1}.a`)}</th>
                    <td role="cell" data-label={t('pg.delete.t.action')}>{k(`pg.delete.t.r${i + 1}.b`)}</td>
                    <td role="cell" data-label={t('pg.delete.t.period')}>{k(`pg.delete.t.r${i + 1}.c`)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ),
        s4: (
          <div className={infoStyles.actions}>
            <ButtonLink to={paths.site.dataRequest}>{t('site.dataRequest.title')}</ButtonLink>
            <ButtonLink to={paths.site.contact} variant="secondary">
              {t('site.nav.contact')}
            </ButtonLink>
          </div>
        ),
        s5: (
          <div className={infoStyles.actions}>
            <ButtonLink to={paths.site.privacy} variant="secondary">
              {t('legal.title.PRIVACY')}
            </ButtonLink>
            <ButtonLink to={paths.site.legal('KVKK')} variant="secondary">
              {t('legal.title.KVKK')}
            </ButtonLink>
            <ButtonLink to={paths.site.legal('RETENTION')} variant="secondary">
              {t('pg.delete.retention')}
            </ButtonLink>
          </div>
        ),
      }}
    />
  );
}
