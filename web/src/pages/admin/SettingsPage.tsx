// SAYFA: Ayarlar (/admin/settings)
// API: GET /api/admin/settings, PUT /api/admin/settings/{key} {value} (api/settings.ts). Her alan tek tek kaydedilir.
//      Etkinlik grubu: events_require_approval, event_max_open_per_user, event_daily_create_limit (backend V62 ile tohumlar).
//      Anahtarlar: app_name, website, iletişim, sosyal, store_url_*, min/latest_version_*, banner_*, maintenance_*, faculties (`;` ile ayrılmış).
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { getSettings, putSetting } from '../../api/settings';
import { qk } from '../../api/queryKeys';
import type { Lang } from '../../api/types';
import {
  Badge,
  Button,
  Card,
  ErrorState,
  Icon,
  PageHeader,
  Skeleton,
  Switch,
  Tabs,
  useGuardedMutation,
  useUnsavedGuard,
} from '../../components/ui';
import { GuardedDialog } from '../../components/admin/GuardedDialog';
import { useI18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import { adminErrorMessage, Callout } from './campaigns/shared';
import { EventSettings } from './settings/EventSettings';
import { FacultyEditor } from './settings/FacultyEditor';
import { SettingDiff } from './settings/SettingDiff';
import {
  compareVersions,
  GROUP_KEYS,
  isCriticalSetting,
  isMinVersionKey,
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

const GROUPS: SettingGroup[] = ['general', 'stores', 'banner', 'maintenance', 'events', 'faculties'];
const LANGS: Lang[] = ['tr', 'en', 'ar'];
/** Kritik ayar sebebi en az bu kadar karakter (sunucu denetim kuralıyla aynı: 5). */
const SETTING_REASON_MIN = 5;

export default function SettingsPage() {
  const i18n = useI18n();
  const { t } = i18n;
  usePageTitle(t('admin.settings.title'));
  const qc = useQueryClient();
  const [group, setGroup] = useState<SettingGroup>('general');
  const [edits, setEdits] = useState<Record<string, string>>({});
  const [errors, setErrors] = useState<Record<string, string>>({});
  // Kritik anahtarlar için onay penceresi: kaydedilecek anahtar + değer
  const [pending, setPending] = useState<{ key: string; value: string } | null>(null);
  const [savingKey, setSavingKey] = useState<string | null>(null);
  const [bannerLang, setBannerLang] = useState<Lang>('tr');

  const q = useQuery({ queryKey: qk.settings.list(), queryFn: getSettings });
  const server = useMemo(() => q.data ?? {}, [q.data]);

  /** Başarılı kayıttan sonra yerel düzenlemeyi temizler ve önbellekleri tazeler. */
  const afterSaved = (key: string) => {
    setEdits((e) => {
      const { [key]: _removed, ...rest } = e;
      return rest;
    });
    setErrors((e) => {
      const { [key]: _removed, ...rest } = e;
      return rest;
    });
    void qc.invalidateQueries({ queryKey: qk.settings.all });
    void qc.invalidateQueries({ queryKey: qk.appInfo });
    if (key === 'faculties') void qc.invalidateQueries({ queryKey: qk.faculties });
  };
  const savedText = (key: string) => t('admin.settings.saved', { name: i18n.td(`admin.settings.key.${key}`, key) });
  /** Hata metnini alanın altında da gösterir (toast'u çağıran tarafı üretir). */
  const failText = (key: string, e: unknown) => {
    const msg = adminErrorMessage(i18n, e);
    setErrors((x) => ({ ...x, [key]: msg }));
    return msg;
  };

  // Kritik olmayan anahtarlar doğrudan kaydedilir; çift tıklama/Enter senkron kilitle tek isteğe iner.
  const saveG = useGuardedMutation<void, { key: string; value: string }>({
    mutationFn: (v, { idempotencyKey }) => putSetting(v.key, v.value, { idempotencyKey }),
    successMessage: (_d, v) => savedText(v.key),
    onSuccess: (_d, v) => afterSaved(v.key),
    onError: (e, v) => void failText(v.key, e),
  });
  const saveDirect = async (key: string, value: string) => {
    setSavingKey(key);
    try {
      await saveG.run({ key, value });
    } finally {
      setSavingKey(null);
    }
  };

  const ctx: SettingsCtx = {
    server,
    edits,
    errors,
    savingKey,
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
      if (value === (server[key] ?? '')) return; // fark yok
      if (isCriticalSetting(key)) {
        setPending({ key, value });
        return;
      }
      void saveDirect(key, value);
    },
  };

  // kaydedilmemiş değişiklik varken sayfadan çıkışı uyar
  const anyDirty = Object.keys(edits).some((k) => isDirty({ server, edits }, k));
  const unsaved = useUnsavedGuard(anyDirty);

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
      <PageHeader title={t('admin.settings.title')} />
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
              <Card title={t('admin.settings.general.legal')}>
                <p>{t('admin.settings.general.legalHint')}</p>
                <div className={styles.grid}>
                  <SettingRow k="legal.controller.name" label={t('admin.settings.key.legal.controller.name')} />
                  <SettingRow
                    k="legal.controller.address"
                    label={t('admin.settings.key.legal.controller.address')}
                    kind="textarea"
                  />
                  <SettingRow
                    k="legal.controller.email"
                    label={t('admin.settings.key.legal.controller.email')}
                    kind="email"
                  />
                  <SettingRow k="legal.controller.kep" label={t('admin.settings.key.legal.controller.kep')} ltr />
                  <SettingRow k="legal.controller.verbis" label={t('admin.settings.key.legal.controller.verbis')} ltr />
                  <SettingRow k="legal.hosting.location" label={t('admin.settings.key.legal.hosting.location')} />
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
                        ltr
                        placeholder="1.0.0"
                      />
                      <SettingRow
                        k={`latest_version_${p}`}
                        label={t('admin.settings.stores.latest')}
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
                    kind="url"
                    placeholder="https://"
                  />
                </div>
              </Card>
            </>
          )}

          {group === 'maintenance' && (
            <>
              {server.maintenance_mode === 'true' && (
                <Callout tone="danger" role="status" title={t('admin.settings.maintenance.activeTitle')}>
                  {t('admin.settings.maintenance.activeText')}
                </Callout>
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

          {group === 'events' && <EventSettings />}

          {group === 'faculties' && (
            <Card title={t('admin.settings.group.faculties')}>
              <FacultyEditor />
            </Card>
          )}
        </div>
      )}

      {unsaved.dialog}
      {pending && <CriticalSaveDialog pending={pending} server={server} onClose={() => setPending(null)} onSaved={afterSaved} onFail={failText} />}
    </SettingsProvider>
  );
}

/** Kritik anahtar kaydı: eski → yeni fark önizlemesi + onay; bakım modunda ayrıca "BAKIM" yazdırır. */
function CriticalSaveDialog({
  pending,
  server,
  onClose,
  onSaved,
  onFail,
}: {
  pending: { key: string; value: string };
  server: Record<string, string>;
  onClose: () => void;
  onSaved: (key: string) => void;
  onFail: (key: string, e: unknown) => string;
}) {
  const i18n = useI18n();
  const { t, td } = i18n;
  const { key, value } = pending;
  const isMaintenance = key === 'maintenance_mode';
  const label = td(`admin.settings.key.${key}`, key);
  const before = server[key] ?? '';
  return (
    <GuardedDialog
      open
      onClose={onClose}
      danger={isMaintenance || isMinVersionKey(key)}
      title={
        isMaintenance
          ? t(value === 'true' ? 'admin.settings.maintenance.confirmTitle' : 'admin.p05.settings.maintenanceOffTitle')
          : t('admin.p05.settings.confirmTitle', { name: label })
      }
      message={
        isMaintenance
          ? t(value === 'true' ? 'admin.settings.maintenance.confirmText' : 'admin.p05.settings.maintenanceOffText')
          : t('admin.p05.settings.confirmText')
      }
      consequence={isMinVersionKey(key) ? t('admin.p05.settings.minVersionWarning') : undefined}
      confirmLabel={
        isMaintenance
          ? t(value === 'true' ? 'admin.settings.maintenance.confirmBtn' : 'admin.p05.settings.maintenanceOffBtn')
          : t('admin.p05.settings.confirmBtn')
      }
      requireReason
      reasonMinLength={SETTING_REASON_MIN}
      typeToConfirm={isMaintenance ? 'BAKIM' : undefined}
      extra={<SettingDiff label={label} before={before} after={value} />}
      successMessage={t('admin.settings.saved', { name: label })}
      errorMessage={(e) => onFail(key, e)}
      onConfirm={({ reason, idempotencyKey }) => putSetting(key, value, { reason, idempotencyKey })}
      onSuccess={() => onSaved(key)}
    />
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
    </div>
  );
}
