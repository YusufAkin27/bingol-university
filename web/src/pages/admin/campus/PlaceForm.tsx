// Yer ekle/düzenle paneli (Drawer içinde). Doğrulama saf mantıkta (logic.ts); burada yalnız arayüz.
// Fotoğraf alanı YOK: yönetici uç sözleşmesinde yükleme ucu tanımlı değil; mevcut `photoUrl` düzenlemede aynen korunur.
import { useMemo, useState, type KeyboardEvent } from 'react';
import {
  createCampusPlace,
  updateCampusPlace,
  campusKeys,
  type CampusPlace,
  type CampusCategoryInfo,
  type LatLng,
} from '../../../api/adminCampus';
import {
  Button,
  CopyButton,
  Checkbox,
  Drawer,
  FormField,
  Icon,
  Input,
  Select,
  Textarea,
  useGuardedMutation,
} from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminError } from '../../../lib/errors';
import { errText, gt } from './dict';
import {
  EMPTY_PLACE_FORM,
  NAME_MAX,
  WEB_URL_MAX,
  SUMMARY_MAX,
  UNITS_MAX,
  addUnits,
  fmtCoord,
  insideBoundary,
  osmLink,
  parseLatLngPair,
  placeToForm,
  validatePlaceForm,
  type PlaceField,
  type PlaceFormState,
} from './logic';
import { PlacePhoto } from './PlacePhoto';
import { PlacePreview } from './PlacePreview';
import styles from './campus.module.css';

const FORM_ID = 'campus-place-form';
const ERR_SCOPES = ['admin.campus.err', 'admin.err'];

interface Props {
  /** null: yeni yer. */
  place: CampusPlace | null;
  boundary: LatLng[];
  /** Sunucudan gelen (ya da yedek) kategori listesi. */
  categories: CampusCategoryInfo[];
  onClose: () => void;
}

export function PlaceForm({ place, boundary, categories, onClose }: Props) {
  const i18n = useI18n();
  const t = gt(i18n);
  const { formatNumber } = i18n;
  const [form, setForm] = useState<PlaceFormState>(() => (place ? placeToForm(place) : EMPTY_PLACE_FORM));
  const [submitted, setSubmitted] = useState(false);
  const [blurred, setBlurred] = useState<ReadonlySet<PlaceField>>(new Set());
  const [pasteText, setPasteText] = useState('');
  const [pasteState, setPasteState] = useState<'idle' | 'ok' | 'bad'>('idle');
  const [unitDraft, setUnitDraft] = useState('');

  const [photoUrl, setPhotoUrl] = useState<string | null>(place?.photoUrl ?? null);
  const categoryKeys = useMemo(() => categories.map((c) => c.key), [categories]);
  const unitSourceCode = place?.unitSourceCode ?? null;
  const v = useMemo(
    () => validatePlaceForm(form, boundary, { photoUrl, categories: categoryKeys, unitSourceCode }),
    [form, boundary, photoUrl, categoryKeys, unitSourceCode],
  );
  const set = (patch: Partial<PlaceFormState>) => setForm((f) => ({ ...f, ...patch }));
  const blur = (field: PlaceField) => setBlurred((s) => (s.has(field) ? s : new Set(s).add(field)));

  /** Hata metni: gönderim denendiyse hepsi, yoksa yalnız dokunulmuş alanlar (bitmemiş formda kırmızı yağmur olmasın). */
  const err = (field: PlaceField): string | null => {
    const e = v.errors[field];
    if (!e) return null;
    const live = field === 'footprint' && form.footprintText.trim() !== '';
    return submitted || blurred.has(field) || live ? errText(t, e) : null;
  };

  const save = useGuardedMutation<unknown, NonNullable<typeof v.input>>({
    mutationFn: (input, ctx) =>
      place
        ? updateCampusPlace(place.id, input, { idempotencyKey: ctx.idempotencyKey })
        : createCampusPlace(input, { idempotencyKey: ctx.idempotencyKey }),
    successMessage: t(place ? 'admin.campus.toast.saved' : 'admin.campus.toast.created'),
    errorMessage: (e) => adminError(i18n, e, ...ERR_SCOPES),
    invalidateKeys: [campusKeys.all],
    onSuccess: onClose,
  });

  const onSubmit = () => {
    setSubmitted(true);
    if (v.input) void save.run(v.input);
  };

  /** Yapıştırılan/yazılan "enlem, boylam" çiftini alanlara işler (yazarken değil; yapıştırma, Enter ve odak çıkışında). */
  const applyPaste = (text: string) => {
    if (!text.trim()) return setPasteState('idle');
    const pair = parseLatLngPair(text);
    if (!pair) return setPasteState('bad');
    set({ lat: fmtCoord(pair.lat), lng: fmtCoord(pair.lng) });
    setPasteText('');
    setPasteState('ok');
  };

  const addUnit = () => {
    if (!unitDraft.trim()) return;
    set({ units: addUnits(form.units, unitDraft) });
    setUnitDraft('');
  };
  const onUnitKey = (e: KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      addUnit();
    }
  };

  const inside = v.point ? insideBoundary(v.point.lat, v.point.lng, boundary) : null;
  const previewState =
    inside === null
      ? t('admin.campus.form.previewNoBoundary')
      : t(inside ? 'admin.campus.form.previewInside' : 'admin.campus.form.previewOutside');
  const coordText = v.point ? `${fmtCoord(v.point.lat)}, ${fmtCoord(v.point.lng)}` : '';
  const invalid = submitted && !v.input;

  return (
    <Drawer
      open
      onClose={onClose}
      size="lg"
      title={t(place ? 'admin.campus.form.edit' : 'admin.campus.form.new')}
      footer={
        <>
          <Button type="button" variant="secondary" onClick={onClose} disabled={save.isPending}>
            {t('admin.campus.form.cancel')}
          </Button>
          <Button type="submit" form={FORM_ID} loading={save.isPending}>
            {t('admin.campus.form.save')}
          </Button>
        </>
      }
    >
      <form
        id={FORM_ID}
        noValidate
        className={styles.formGrid}
        onSubmit={(e) => {
          e.preventDefault();
          onSubmit();
        }}
      >
        <div className={styles.wide}>
          <FormField
            label={t('admin.campus.form.name')}
            hint={t('admin.campus.form.nameHint', { max: NAME_MAX })}
            error={err('name')}
            required
          >
            <Input
              data-search-anchor="campus-name"
              value={form.name}
              maxLength={NAME_MAX + 20}
              autoComplete="off"
              onChange={(e) => set({ name: e.target.value })}
              onBlur={() => blur('name')}
            />
          </FormField>
        </div>

        <FormField label={t('admin.campus.form.category')} error={err('category')} required>
          <Select
            data-search-anchor="campus-category"
            value={form.category}
            onChange={(e) => set({ category: e.target.value })}
            onBlur={() => blur('category')}
          >
            <option value="">{t('admin.campus.form.categoryChoose')}</option>
            {categories.map((c) => (
              <option key={c.key} value={c.key}>
                {c.label}
              </option>
            ))}
          </Select>
        </FormField>

        <FormField label={t('admin.campus.form.sortKey')} hint={t('admin.campus.form.sortKeyHint')} error={err('sortKey')}>
          <Input
            data-search-anchor="campus-sortkey"
            value={form.sortKey}
            inputMode="numeric"
            dir="ltr"
            onChange={(e) => set({ sortKey: e.target.value })}
            onBlur={() => blur('sortKey')}
          />
        </FormField>

        <fieldset className={`${styles.wide} ${styles.coords}`}>
          <legend className={styles.legend}>{t('admin.campus.form.coords')}</legend>
          <div className={styles.coordRow}>
            <FormField label={t('admin.campus.form.lat')} hint={t('admin.campus.form.latHint')} error={err('lat')} required>
              <Input
                data-search-anchor="campus-coords"
                value={form.lat}
                inputMode="decimal"
                dir="ltr"
                autoComplete="off"
                onChange={(e) => set({ lat: e.target.value })}
                onBlur={() => blur('lat')}
              />
            </FormField>
            <FormField label={t('admin.campus.form.lng')} hint={t('admin.campus.form.lngHint')} error={err('lng')} required>
              <Input
                value={form.lng}
                inputMode="decimal"
                dir="ltr"
                autoComplete="off"
                onChange={(e) => set({ lng: e.target.value })}
                onBlur={() => blur('lng')}
              />
            </FormField>
          </div>
          <FormField
            label={t('admin.campus.form.paste')}
            hint={t('admin.campus.form.pasteHint')}
            error={pasteState === 'bad' ? t('admin.campus.form.pasteBad') : null}
          >
            <Input
              data-search-anchor="campus-paste"
              value={pasteText}
              dir="ltr"
              autoComplete="off"
              placeholder="38.8847, 40.4981"
              onChange={(e) => {
                setPasteText(e.target.value);
                setPasteState('idle');
              }}
              onPaste={(e) => {
                e.preventDefault();
                applyPaste(e.clipboardData.getData('text'));
              }}
              onBlur={() => applyPaste(pasteText)}
              onKeyDown={(e) => {
                if (e.key === 'Enter') {
                  e.preventDefault();
                  applyPaste(pasteText);
                }
              }}
            />
          </FormField>
          {pasteState === 'ok' && (
            <p className={styles.okNote} role="status">
              {t('admin.campus.form.pasteOk')}
            </p>
          )}
          <div className={styles.coordActions} data-search-anchor="campus-check">
            {v.point ? (
              <a
                className={styles.extLink}
                href={osmLink(v.point.lat, v.point.lng)}
                target="_blank"
                rel="noopener noreferrer"
              >
                <Icon name="external" size={16} aria-hidden="true" />
                {t('admin.campus.form.check')}
                <span className="sr-only"> ({t('admin.campus.form.checkHint')})</span>
              </a>
            ) : (
              <span className={`${styles.extLink} ${styles.extLinkOff}`} aria-disabled="true">
                <Icon name="external" size={16} aria-hidden="true" />
                {t('admin.campus.form.check')}
              </span>
            )}
            {v.point && <CopyButton value={coordText} label={t('admin.campus.form.copyCoords')} />}
            <span className={styles.muted}>{t('admin.campus.form.checkHint')}</span>
          </div>
          {v.warnings.includes('outsideBoundary') && (
            <p className={`${styles.callout} ${styles.calloutWarn}`} role="note">
              {t('admin.campus.form.warnOutside')}
            </p>
          )}
        </fieldset>

        <div className={styles.wide}>
          <FormField
            label={t('admin.campus.form.webUrl')}
            hint={t('admin.campus.form.webUrlHint', { max: WEB_URL_MAX })}
            error={err('webUrl')}
          >
            <Input
              data-search-anchor="campus-weburl"
              value={form.webUrl}
              dir="ltr"
              inputMode="url"
              autoComplete="off"
              spellCheck={false}
              placeholder="https://fef.bingol.edu.tr"
              onChange={(e) => set({ webUrl: e.target.value })}
              onBlur={() => blur('webUrl')}
            />
          </FormField>
        </div>

        <div className={styles.wide} data-search-anchor="campus-remote">
          <Checkbox
            label={t('admin.campus.form.remote')}
            checked={form.remote}
            onChange={(e) => set({ remote: e.target.checked })}
          />
          <p className={styles.muted}>{t('admin.campus.form.remoteHint')}</p>
        </div>

        {place && (
          <div className={styles.wide}>
            <PlacePhoto placeId={place.id} name={place.name} url={photoUrl} onChange={setPhotoUrl} />
          </div>
        )}

        <div className={styles.wide}>
          <FormField
            label={t('admin.campus.form.summary')}
            hint={`${t('admin.campus.form.summaryHint', { max: SUMMARY_MAX })} (${formatNumber(form.summary.trim().length)}/${formatNumber(SUMMARY_MAX)})`}
            error={err('summary')}
          >
            <Textarea
              data-search-anchor="campus-summary"
              rows={3}
              value={form.summary}
              onChange={(e) => set({ summary: e.target.value })}
              onBlur={() => blur('summary')}
            />
          </FormField>
        </div>

        <div className={styles.wide} data-search-anchor="campus-units">
          <FormField label={t('admin.campus.form.units')} hint={t('admin.campus.form.unitsHint')}>
            <Input
              value={unitDraft}
              maxLength={200}
              autoComplete="off"
              disabled={form.units.length >= UNITS_MAX}
              onChange={(e) => setUnitDraft(e.target.value)}
              onKeyDown={onUnitKey}
            />
          </FormField>
          <Button
            type="button"
            size="sm"
            variant="secondary"
            onClick={addUnit}
            disabled={!unitDraft.trim() || form.units.length >= UNITS_MAX}
          >
            {t('admin.campus.form.unitAdd')}
          </Button>
          {form.units.length >= UNITS_MAX && (
            <p className={styles.muted}>{t('admin.campus.form.unitsFull', { max: UNITS_MAX })}</p>
          )}
          {form.units.length > 0 && (
            <ul className={styles.chips} aria-label={t('admin.campus.form.unitsList')}>
              {form.units.map((u) => (
                <li key={u} className={styles.chip}>
                  <span dir="auto">{u}</span>
                  <button
                    type="button"
                    className={styles.chipX}
                    aria-label={t('admin.campus.form.unitRemove', { name: u })}
                    onClick={() => set({ units: form.units.filter((x) => x !== u) })}
                  >
                    <Icon name="x" size={14} aria-hidden="true" />
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>

        {place?.departments && place.departments.length > 0 && (
          <div className={styles.wide} data-search-anchor="campus-departments">
            <span className={styles.photoLabel}>{t('admin.campus.form.departments')}</span>
            <ul className={styles.chips} aria-label={t('admin.campus.form.departments')}>
              {place.departments.map((d) => (
                <li key={d} className={`${styles.chip} ${styles.chipStatic}`}>
                  <span dir="auto">{d}</span>
                </li>
              ))}
            </ul>
            <p className={styles.muted}>{t('admin.campus.form.departmentsHint')}</p>
          </div>
        )}

        <div className={styles.wide}>
          <FormField
            label={t('admin.campus.form.footprint')}
            hint={t('admin.campus.form.footprintHint')}
            error={err('footprint')}
          >
            <Textarea
              data-search-anchor="campus-footprint"
              rows={5}
              dir="ltr"
              spellCheck={false}
              placeholder={'38.88470, 40.49810\n38.88470, 40.49860\n38.88430, 40.49860'}
              value={form.footprintText}
              onChange={(e) => set({ footprintText: e.target.value })}
              onBlur={() => blur('footprint')}
            />
          </FormField>
          {v.footprint.length > 0 && (
            <p className={styles.muted} role="status">
              {t('admin.campus.form.footprintCount', { n: formatNumber(v.footprint.length) })}
            </p>
          )}
          {v.warnings.includes('footprintOutside') && (
            <p className={`${styles.callout} ${styles.calloutWarn}`} role="note">
              {t('admin.campus.form.warnFootprintOutside')}
            </p>
          )}
        </div>

        {(v.point || v.footprint.length > 0) && (
          <div className={`${styles.wide} ${styles.previewBox}`}>
            <h3 className={styles.subTitle}>{t('admin.campus.form.preview')}</h3>
            <PlacePreview
              label={t('admin.campus.form.previewAria', { state: previewState })}
              boundary={boundary}
              footprint={v.footprint}
              point={v.point}
            />
            <p className={styles.muted}>{t('admin.campus.form.previewHint')}</p>
          </div>
        )}

        <div className={styles.wide}>
          <Checkbox
            label={t('admin.campus.form.active')}
            checked={form.active}
            onChange={(e) => set({ active: e.target.checked })}
          />
        </div>

        {invalid && (
          <p className={`${styles.wide} ${styles.formInvalid}`} role="alert">
            {t('admin.campus.form.invalid')}
          </p>
        )}
      </form>
    </Drawer>
  );
}
