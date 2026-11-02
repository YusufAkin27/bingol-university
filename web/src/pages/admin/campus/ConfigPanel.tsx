// "Harita ayarları" sekmesi: merkez, yakınlaştırma, kampüs sınırı, karo adresi ve atıf. Kaydetmek gerekçe ister (GuardedAction).
import type { UseQueryResult } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { campusKeys, updateCampusConfig, type CampusConfig } from '../../../api/adminCampus';
import {
  Badge,
  Button,
  ErrorState,
  FormField,
  GuardedAction,
  Input,
  Skeleton,
  Textarea,
  useUnsavedGuard,
} from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminError } from '../../../lib/errors';
import { errText, gt } from './dict';
import { configToForm, parsePoints, validateConfigForm, type ConfigFormState } from './logic';
import { PlacePreview } from './PlacePreview';
import styles from './campus.module.css';

const ERR_SCOPES = ['admin.campus.err', 'admin.err'];

interface Props {
  query: UseQueryResult<CampusConfig>;
  canWrite: boolean;
}

export function ConfigPanel({ query, canWrite }: Props) {
  const i18n = useI18n();
  const t = gt(i18n);
  if (query.isError) {
    return (
      <ErrorState
        subject={t('admin.campus.cfg.subject')}
        error={query.error}
        description={adminError(i18n, query.error, ...ERR_SCOPES)}
        onRetry={() => void query.refetch()}
      />
    );
  }
  if (!query.data) {
    return (
      <div aria-busy="true" role="status" aria-label={t('admin.campus.cfg.title')}>
        <Skeleton height="14rem" width="100%" />
      </div>
    );
  }
  return <ConfigForm config={query.data} canWrite={canWrite} />;
}

function ConfigForm({ config, canWrite }: { config: CampusConfig; canWrite: boolean }) {
  const i18n = useI18n();
  const t = gt(i18n);
  const { formatNumber } = i18n;
  const base = useMemo(() => configToForm(config), [config]);
  const [draft, setDraft] = useState<Partial<ConfigFormState> | null>(null);
  const form: ConfigFormState = { ...base, ...draft };
  const dirty = draft !== null && (Object.keys(draft) as (keyof ConfigFormState)[]).some((k) => draft[k] !== base[k]);
  const guard = useUnsavedGuard(dirty);
  const v = validateConfigForm(form);
  const set = (patch: Partial<ConfigFormState>) => setDraft((d) => ({ ...d, ...patch }));
  const fe = (f: keyof typeof v.errors) => (v.errors[f] ? errText(t, v.errors[f]!) : null);
  const ro = !canWrite;

  const boundaryCount = useMemo(() => {
    const r = parsePoints(form.boundaryText, 3);
    return r.error ? 0 : r.points.length;
  }, [form.boundaryText]);

  const osm = v.warnings.includes('osmPublic');

  return (
    <form
      className={styles.cfgForm}
      noValidate
      onSubmit={(e) => e.preventDefault()}
      aria-label={t('admin.campus.cfg.title')}
    >
      <p className={styles.muted}>{t('admin.campus.cfg.intro')}</p>
      {ro && (
        <p className={styles.callout} role="note">
          {t('admin.campus.cfg.readonly')}
        </p>
      )}

      <fieldset className={styles.group} data-search-anchor="cfg-center" disabled={ro}>
        <legend className={styles.legend}>{t('admin.campus.cfg.center')}</legend>
        <p className={styles.muted}>{t('admin.campus.cfg.centerHint')}</p>
        <div className={styles.coordRow}>
          <FormField label={t('admin.campus.form.lat')} error={fe('lat')} required>
            <Input value={form.lat} inputMode="decimal" dir="ltr" onChange={(e) => set({ lat: e.target.value })} />
          </FormField>
          <FormField label={t('admin.campus.form.lng')} error={fe('lng')} required>
            <Input value={form.lng} inputMode="decimal" dir="ltr" onChange={(e) => set({ lng: e.target.value })} />
          </FormField>
        </div>
        {v.warnings.includes('centerOutside') && (
          <p className={`${styles.callout} ${styles.calloutWarn}`} role="note">
            {t('admin.campus.cfg.warnCenter')}
          </p>
        )}
      </fieldset>

      <fieldset className={styles.group} data-search-anchor="cfg-zoom" disabled={ro}>
        <legend className={styles.legend}>{t('admin.campus.cfg.zoom')}</legend>
        <p className={styles.muted}>{t('admin.campus.cfg.zoomHint')}</p>
        <div className={styles.zoomRow}>
          <FormField label={t('admin.campus.cfg.zoomMin')} error={fe('zoomMin')} required>
            <Input value={form.zoomMin} inputMode="numeric" dir="ltr" onChange={(e) => set({ zoomMin: e.target.value })} />
          </FormField>
          <FormField label={t('admin.campus.cfg.zoomInitial')} error={fe('zoomInitial')} required>
            <Input
              value={form.zoomInitial}
              inputMode="numeric"
              dir="ltr"
              onChange={(e) => set({ zoomInitial: e.target.value })}
            />
          </FormField>
          <FormField label={t('admin.campus.cfg.zoomMax')} error={fe('zoomMax')} required>
            <Input value={form.zoomMax} inputMode="numeric" dir="ltr" onChange={(e) => set({ zoomMax: e.target.value })} />
          </FormField>
        </div>
      </fieldset>

      <fieldset className={styles.group} data-search-anchor="cfg-boundary" disabled={ro}>
        <legend className={styles.legend}>{t('admin.campus.cfg.boundary')}</legend>
        <FormField label={t('admin.campus.cfg.boundaryPoints')} hint={t('admin.campus.cfg.boundaryHint')} error={fe('boundary')}>
          <Textarea
            rows={6}
            dir="ltr"
            spellCheck={false}
            value={form.boundaryText}
            onChange={(e) => set({ boundaryText: e.target.value })}
          />
        </FormField>
        {boundaryCount > 0 && (
          <p className={styles.muted} role="status">
            {t('admin.campus.cfg.boundaryCount', { n: formatNumber(boundaryCount) })}
          </p>
        )}
        {(v.boundary.length >= 3 || v.center) && (
          <div className={styles.previewBox}>
            <h3 className={styles.subTitle}>{t('admin.campus.cfg.preview')}</h3>
            <PlacePreview label={t('admin.campus.cfg.previewAria')} boundary={v.boundary} point={v.center} />
          </div>
        )}
      </fieldset>

      <fieldset className={styles.group} data-search-anchor="cfg-tiles" disabled={ro}>
        <legend className={styles.legend}>
          {t('admin.campus.cfg.tiles')} {osm && <Badge tone="warning">{t('admin.campus.cfg.osmBadge')}</Badge>}
        </legend>
        <p className={`${styles.callout} ${styles.calloutWarn}`} role="note" data-search-anchor="cfg-tile-warning">
          {t('admin.campus.cfg.tileWarning')}
        </p>
        <FormField label={t('admin.campus.cfg.tileUrl')} hint={t('admin.campus.cfg.tileUrlHint')} error={fe('tileUrl')} required>
          <Input
            data-search-anchor="cfg-tile-url"
            value={form.tileUrl}
            dir="ltr"
            spellCheck={false}
            autoComplete="off"
            onChange={(e) => set({ tileUrl: e.target.value })}
          />
        </FormField>
        <FormField
          label={t('admin.campus.cfg.attribution')}
          hint={t('admin.campus.cfg.attributionHint')}
          error={fe('attribution')}
          required
        >
          <Input
            data-search-anchor="cfg-attribution"
            value={form.attribution}
            onChange={(e) => set({ attribution: e.target.value })}
          />
        </FormField>
        <FormField
          label={t('admin.campus.cfg.maxNative')}
          hint={t('admin.campus.cfg.maxNativeHint')}
          error={fe('maxNativeZoom')}
          required
        >
          <Input
            value={form.maxNativeZoom}
            inputMode="numeric"
            dir="ltr"
            onChange={(e) => set({ maxNativeZoom: e.target.value })}
          />
        </FormField>
      </fieldset>

      {canWrite && (
        <div className={styles.cfgActions} data-search-anchor="cfg-save">
          <GuardedAction
            permission="campus.write"
            disabled={!dirty || !v.config}
            requireReason
            reasonMinLength={5}
            reasonLabel={t('admin.campus.cfg.reason')}
            irreversible={false}
            title={t('admin.campus.cfg.saveTitle')}
            message={t('admin.campus.cfg.saveMessage')}
            consequence={t('admin.campus.cfg.saveConsequence')}
            confirmLabel={t('admin.campus.cfg.save')}
            successMessage={t('admin.campus.cfg.saved')}
            errorMessage={(e) => adminError(i18n, e, ...ERR_SCOPES)}
            invalidateKeys={[campusKeys.config]}
            onSuccess={() => setDraft(null)}
            onConfirm={({ reason, idempotencyKey }) => updateCampusConfig(v.config!, { reason, idempotencyKey })}
          >
            {t('admin.campus.cfg.save')}
          </GuardedAction>
          <Button type="button" variant="secondary" disabled={!dirty} onClick={() => setDraft(null)}>
            {t('admin.campus.cfg.reset')}
          </Button>
          {dirty && !v.config && (
            <span className={styles.formInvalid} role="alert">
              {t('admin.campus.cfg.invalid')}
            </span>
          )}
          {dirty && v.config && (
            <span className={styles.muted} role="status">
              {t('admin.campus.cfg.dirty')}
            </span>
          )}
        </div>
      )}
      {guard.dialog}
    </form>
  );
}
