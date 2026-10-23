// SAYFA: Ayarlar (/admin/settings)
// API: GET /api/admin/settings, PUT /api/admin/settings/{key} {value} (api/settings.ts). Her alan tek tek kaydedilir.
//      Anahtarlar: app_name, website, iletişim, sosyal, store_url_*, min/latest_version_*, banner_*, maintenance_*, faculties (`;` ile ayrılmış).
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useEffect, useMemo, useState } from 'react';
import { getSettings, putSetting } from '../../api/settings';
import { qk } from '../../api/queryKeys';
import type { Lang } from '../../api/types';
import {
  Badge,
  Button,
  Card,
  ConfirmDialog,
  ErrorState,
  Icon,
  PageHeader,
  Skeleton,
  Switch,
  Tabs,
  useToast,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import { adminErrorMessage, Callout } from './campaigns/shared';
import { FacultyEditor } from './settings/FacultyEditor';
import {
  compareVersions,
  GROUP_KEYS,
  validateSetting,
  type SettingGroup,
} from './settings/lib';
import {
  isDirty,
  SettingRow,
  SettingsProvider,
  useSettings,
  valueOf,
  type SettingsCtx,
} from './settings/SettingRow';
import styles from './settings/settings.module.css';

const GROUPS: SettingGroup[] = ['general', 'stores', 'banner', 'maintenance', 'faculties'];
const LANGS: Lang[] = ['tr', 'en', 'ar'];

export default function SettingsPage() {
  const i18n = useI18n();
  const { t } = i18n;
  usePageTitle(t('admin.settings.title'));
  const toast = useToast();
  const qc = useQueryClient();
  const [group, setGroup] = useState<SettingGroup>('general');
  const [edits, setEdits] = useState<Record<string, string>>({});
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [confirmMaintenance, setConfirmMaintenance] = useState(false);
  const [bannerLang, setBannerLang] = useState<Lang>('tr');

  const q = useQuery({ queryKey: qk.settings.list(), queryFn: getSettings });
  const server = useMemo(() => q.data ?? {}, [q.data]);

  const saveM = useMutation({
    mutationFn: (v: { key: string; value: string }) => putSetting(v.key, v.value),
    onSuccess: (_d, v) => {
      setEdits((e) => {
        const { [v.key]: _removed, ...rest } = e;
        return rest;
      });
      setErrors((e) => {
        const { [v.key]: _removed, ...rest } = e;
        return rest;
      });
      toast.success(t('admin.settings.saved', { name: i18n.td(`admin.settings.key.${v.key}`, v.key) }));
      void qc.invalidateQueries({ queryKey: qk.settings.all });
      void qc.invalidateQueries({ queryKey: qk.appInfo });
      if (v.key === 'faculties') void qc.invalidateQueries({ queryKey: qk.faculties });
    },
    onError: (e, v) => {
      const msg = adminErrorMessage(i18n, e);
      setErrors((x) => ({ ...x, [v.key]: msg }));
      toast.error(msg);
    },
  });

  const ctx: SettingsCtx = {
    server,
    edits,
    errors,
    savingKey: saveM.isPending ? (saveM.variables?.key ?? null) : null,
    setEdit: (key, value) => {
      setEdits((e) => ({ ...e, [key]: value }));
      setErrors((x) => {
        if (!(key in x)) return x;
        const { [key]: _r, ...rest } = x;
        return rest;
      });
    },
    revert: (key) => {
      setEdits((e) => {
        const { [key]: _r, ...rest } = e;
        return rest;
      });
      setErrors((x) => {
        const { [key]: _r, ...rest } = x;
        return rest;
      });
    },
    save: (key) => {
      const value = valueOf({ server, edits }, key).trim();
      if (validateSetting(key, value)) return;
      if (key === 'maintenance_mode' && value === 'true') {
        setConfirmMaintenance(true);
        return;
      }
      saveM.mutate({ key, value });
    },
  };

  // kaydedilmemiş değişiklik varken sayfadan çıkışı uyar
  const anyDirty = Object.keys(edits).some((k) => isDirty({ server, edits }, k));
  useEffect(() => {
    if (!anyDirty) return;
    const h = (e: BeforeUnloadEvent) => {
      e.preventDefault();
    };
    window.addEventListener('beforeunload', h);
    return () => window.removeEventListener('beforeunload', h);
  }, [anyDirty]);

  const groupDirty = (g: SettingGroup) => GROUP_KEYS[g].some((k) => isDirty({ server, edits }, k));
  const tabs = GROUPS.map((g) => ({
    id: g,
    label: (
      <span className={styles.tabLabel}>
        {t(`admin.settings.group.${g}`)}
        {groupDirty(g) && (
          <span
            className={styles.tabDot}
            role="img"
            aria-label={t('admin.settings.unsaved')}
            title={t('admin.settings.unsaved')}
          />
        )}
        {g === 'maintenance' && server.maintenance_mode === 'true' && (
          <Badge tone="danger">{t('admin.settings.maintenance.on')}</Badge>
        )}
      </span>
    ),
  }));

  const mode = valueOf({ server, edits }, 'maintenance_mode') === 'true';

  return (
    <SettingsProvider value={ctx}>
      <PageHeader title={t('admin.settings.title')} description={t('admin.settings.subtitle')} />
      <Tabs tabs={tabs} value={group} onChange={(id) => setGroup(id as SettingGroup)} label={t('admin.settings.groups')} />

      {q.isError ? (
        <ErrorState description={adminErrorMessage(i18n, q.error)} onRetry={() => void q.refetch()} />
      ) : q.isLoading ? (
        <div className={styles.skeletons} aria-busy="true">
          <Skeleton width="100%" height="5rem" />
          <Skeleton width="100%" height="5rem" />
          <Skeleton width="100%" height="5rem" />
        </div>
      ) : (
        <div className={styles.panel}>
          {group === 'general' && (
            <>
              <Card title={t('admin.settings.general.app')}>
                <div className={styles.grid}>
                  <SettingRow k="app_name" label={t('admin.settings.key.app_name')} />
                  <SettingRow k="website" label={t('admin.settings.key.website')} kind="url" placeholder="https://" />
                </div>
              </Card>
              <Card title={t('admin.settings.general.contact')}>
                <div className={styles.grid}>
                  <SettingRow k="contact_email" label={t('admin.settings.key.contact_email')} kind="email" />
                  <SettingRow k="support_email" label={t('admin.settings.key.support_email')} kind="email" />
                  <SettingRow k="phone" label={t('admin.settings.key.phone')} kind="tel" />
                  <SettingRow k="address" label={t('admin.settings.key.address')} kind="textarea" />
                </div>
              </Card>
              <Card title={t('admin.settings.general.social')}>
                <div className={styles.grid}>
                  <SettingRow k="instagram" label={t('admin.settings.key.instagram')} ltr />
                  <SettingRow k="twitter" label={t('admin.settings.key.twitter')} ltr />
                  <SettingRow k="youtube" label={t('admin.settings.key.youtube')} ltr />
                </div>
              </Card>
            </>
          )}

          {group === 'stores' && (
            <>
              <Callout tone="info" title={t('admin.settings.stores.forceTitle')}>
                {t('admin.settings.stores.force')}
              </Callout>
              {(['android', 'ios'] as const).map((p) => {
                const min = valueOf({ server, edits }, `min_version_${p}`).trim();
                const latest = valueOf({ server, edits }, `latest_version_${p}`).trim();
                const inverted =
                  !validateSetting(`min_version_${p}`, min) &&
                  !validateSetting(`latest_version_${p}`, latest) &&
                  compareVersions(min, latest) > 0;
                return (
                  <Card key={p} title={t(`admin.settings.stores.${p}`)}>
                    <div className={styles.grid}>
                      <SettingRow
                        k={`min_version_${p}`}
                        label={t('admin.settings.stores.min')}
                        hint={t('admin.settings.stores.minHint')}
                        ltr
                        placeholder="1.0.0"
                      />
                      <SettingRow
                        k={`latest_version_${p}`}
                        label={t('admin.settings.stores.latest')}
                        hint={t('admin.settings.stores.latestHint')}
                        ltr
                        placeholder="1.0.0"
                      />
                      <SettingRow
                        k={`store_url_${p}`}
                        label={t('admin.settings.stores.url')}
                        kind="url"
                        placeholder="https://"
                      />
                    </div>
                    {inverted && (
                      <div className={styles.cardNote}>
                        <Callout tone="warning">{t('admin.settings.stores.inverted')}</Callout>
                      </div>
                    )}
                  </Card>
                );
              })}
            </>
          )}

          {group === 'banner' && (
            <>
              <Card title={t('admin.settings.banner.preview')}>
                <div className={styles.langSwitch} role="group" aria-label={t('admin.settings.banner.previewLang')}>
                  {LANGS.map((l) => (
                    <button
                      key={l}
                      type="button"
                      aria-pressed={bannerLang === l}
                      className={`${styles.langBtn} ${bannerLang === l ? styles.langBtnOn : ''}`}
                      onClick={() => setBannerLang(l)}
                    >
                      {l.toUpperCase()}
                    </button>
                  ))}
                </div>
                <BannerPreview
                  lang={bannerLang}
                  text={valueOf({ server, edits }, `banner_text_${bannerLang}`)}
                  fallback={valueOf({ server, edits }, 'banner_text_tr')}
                  url={valueOf({ server, edits }, 'banner_url')}
                />
              </Card>
              <Card title={t('admin.settings.banner.texts')}>
                <p className={styles.cardIntro}>{t('admin.settings.banner.intro')}</p>
                <div className={styles.grid}>
                  {LANGS.map((l) => (
                    <SettingRow
                      key={l}
                      k={`banner_text_${l}`}
                      label={t(`admin.settings.key.banner_text_${l}`)}
                      kind="textarea"
                      lang={l}
                    />
                  ))}
                  <SettingRow
                    k="banner_url"
                    label={t('admin.settings.key.banner_url')}
                    hint={t('admin.settings.banner.urlHint')}
                    kind="url"
                    placeholder="https://"
                  />
                </div>
              </Card>
            </>
          )}

          {group === 'maintenance' && (
            <>
              {server.maintenance_mode === 'true' ? (
                <Callout tone="danger" role="status" title={t('admin.settings.maintenance.activeTitle')}>
                  {t('admin.settings.maintenance.activeText')}
                </Callout>
              ) : (
                <Callout tone="info">{t('admin.settings.maintenance.explain')}</Callout>
              )}
              <Card title={t('admin.settings.key.maintenance_mode')}>
                <div
                  className={`${styles.row} ${isDirty({ server, edits }, 'maintenance_mode') ? styles.rowDirty : ''}`}
                  data-key="maintenance_mode"
                >
                  {isDirty({ server, edits }, 'maintenance_mode') && (
                    <span className={styles.unsaved}>
                      <Badge tone="warning">{t('admin.settings.unsaved')}</Badge>
                    </span>
                  )}
                  <Switch
                    checked={mode}
                    onChange={(v) => ctx.setEdit('maintenance_mode', v ? 'true' : 'false')}
                    label={t(mode ? 'admin.settings.maintenance.switchOn' : 'admin.settings.maintenance.switchOff')}
                  />
                  {ctx.errors.maintenance_mode && (
                    <p className={styles.errText} role="alert">
                      {ctx.errors.maintenance_mode}
                    </p>
                  )}
                  <div className={styles.rowActions}>
                    <MaintenanceButtons />
                  </div>
                </div>
              </Card>
              <Card title={t('admin.settings.maintenance.messages')}>
                <div className={styles.grid}>
                  {LANGS.map((l) => (
                    <SettingRow
                      key={l}
                      k={`maintenance_message_${l}`}
                      label={t(`admin.settings.key.maintenance_message_${l}`)}
                      kind="textarea"
                      lang={l}
                    />
                  ))}
                </div>
              </Card>
            </>
          )}

          {group === 'faculties' && (
            <Card title={t('admin.settings.group.faculties')}>
              <FacultyEditor />
            </Card>
          )}
        </div>
      )}

      <ConfirmDialog
        open={confirmMaintenance}
        onClose={() => setConfirmMaintenance(false)}
        onConfirm={() => {
          setConfirmMaintenance(false);
          saveM.mutate({ key: 'maintenance_mode', value: 'true' });
        }}
        danger
        title={t('admin.settings.maintenance.confirmTitle')}
        message={t('admin.settings.maintenance.confirmText')}
        confirmLabel={t('admin.settings.maintenance.confirmBtn')}
      />
    </SettingsProvider>
  );
}

function MaintenanceButtons() {
  const { t } = useI18n();
  const c = useSettings();
  const dirty = isDirty(c, 'maintenance_mode');
  return (
    <>
      <Button
        size="sm"
        variant={valueOf(c, 'maintenance_mode') === 'true' ? 'danger' : 'primary'}
        disabled={!dirty}
        loading={c.savingKey === 'maintenance_mode'}
        onClick={() => c.save('maintenance_mode')}
        data-testid="save-maintenance_mode"
      >
        {t('admin.settings.saveField')}
      </Button>
      {dirty && (
        <Button size="sm" variant="ghost" onClick={() => c.revert('maintenance_mode')}>
          {t('admin.settings.revert')}
        </Button>
      )}
    </>
  );
}

/** Uygulamada görünecek duyuru bandının taklidi (seçili dilde; boşsa Türkçe'ye düşer, sunucu gibi). */
function BannerPreview({ lang, text, fallback, url }: { lang: Lang; text: string; fallback: string; url: string }) {
  const { t } = useI18n();
  const own = text.trim();
  const shown = own || fallback.trim();
  const shownLang: Lang = own ? lang : 'tr';
  if (!shown) {
    return (
      <div className={styles.bannerEmpty}>
        <Icon name="info" size={18} />
        {t('admin.settings.banner.none')}
      </div>
    );
  }
  return (
    <div>
      <div className={styles.banner} lang={shownLang} dir={shownLang === 'ar' ? 'rtl' : 'ltr'} data-testid="banner-preview">
        <Icon name="bell" size={18} />
        <span className={styles.bannerText}>{shown}</span>
        {url.trim() && <span className={styles.bannerLink}>{t('admin.settings.banner.open')}</span>}
      </div>
      {!own && lang !== 'tr' && <p className={styles.hintLine}>{t('admin.settings.banner.fallback')}</p>}
    </div>
  );
}
