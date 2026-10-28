import { useMemo, useState } from 'react';
import type { AdminEventPatch } from '../../../api/adminEvents';
import type { EventJoinPolicy, EventView } from '../../../api/types';
import { Button, FormField, Input, Select, Textarea } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { Callout } from '../campaigns/shared';
import { REASON_MAX, buildPatch, formFromEvent, validateEdit, type EditError, type EditForm } from './lib';

/** Yönetici düzenleme formu: yalnızca değişen alanlar gönderilir; sunucu hatası (örn. 422 CONTENT_PROFANITY) üstte gösterilir. */
export function EventEditForm({
  event,
  saving,
  error,
  onCancel,
  onSave,
}: {
  event: EventView;
  saving: boolean;
  error: string | null;
  onCancel: () => void;
  onSave: (patch: AdminEventPatch) => void;
}) {
  const { t } = useI18n();
  const [f, setF] = useState<EditForm>(() => formFromEvent(event));
  const [touched, setTouched] = useState(false);
  const errors = useMemo(() => validateEdit(f), [f]);
  const patch = useMemo(() => buildPatch(event, f), [event, f]);
  const set = (p: Partial<EditForm>) => setF((s) => ({ ...s, ...p }));
  const e = (k: EditError) => (touched && errors.includes(k) ? t(`admin.events.edit.err.${k}`) : null);

  return (
    <form
      noValidate
      onSubmit={(ev) => {
        ev.preventDefault();
        setTouched(true);
        if (errors.length === 0 && patch) onSave(patch);
      }}
      style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-4)' }}
    >
      {error && (
        <Callout tone="danger" role="alert">
          {error}
        </Callout>
      )}
      <FormField label={t('admin.events.edit.title')} error={e('TITLE')} required>
        <Input value={f.title} maxLength={160} onChange={(x) => set({ title: x.target.value })} />
      </FormField>
      <FormField label={t('admin.events.edit.description')} error={e('DESCRIPTION')}>
        <Textarea rows={4} value={f.description} onChange={(x) => set({ description: x.target.value })} />
      </FormField>
      <FormField label={t('admin.events.starts')} error={e('DATES')}>
        <Input type="datetime-local" className="ltr" value={f.startsLocal} onChange={(x) => set({ startsLocal: x.target.value })} />
      </FormField>
      <FormField label={t('admin.events.ends')}>
        <Input type="datetime-local" className="ltr" value={f.endsLocal} onChange={(x) => set({ endsLocal: x.target.value })} />
      </FormField>
      <FormField label={t('admin.events.location')} error={e('LOCATION')}>
        <Input value={f.location} maxLength={210} onChange={(x) => set({ location: x.target.value })} />
      </FormField>
      <FormField label={t('admin.events.capacity')} hint={t('admin.events.edit.capacityHint')} error={e('CAPACITY')}>
        <Input inputMode="numeric" className="ltr" value={f.capacity} onChange={(x) => set({ capacity: x.target.value })} />
      </FormField>
      <FormField label={t('admin.events.joinPolicy')}>
        <Select value={f.joinPolicy} onChange={(x) => set({ joinPolicy: x.target.value as EventJoinPolicy })}>
          <option value="OPEN">{t('admin.events.join.OPEN')}</option>
          <option value="APPROVAL">{t('admin.events.join.APPROVAL')}</option>
        </Select>
      </FormField>
      <FormField
        label={t('admin.events.edit.reason')}
        hint={t('admin.events.edit.reasonHint', { max: REASON_MAX })}
        error={e('REASON')}
      >
        <Input value={f.reason} onChange={(x) => set({ reason: x.target.value })} />
      </FormField>
      {touched && !patch && errors.length === 0 && <Callout tone="info">{t('admin.events.edit.noChange')}</Callout>}
      <div style={{ display: 'flex', gap: 'var(--space-2)', justifyContent: 'flex-end' }}>
        <Button variant="secondary" onClick={onCancel} disabled={saving}>
          {t('common.cancel')}
        </Button>
        <Button type="submit" loading={saving} data-testid="edit-save">
          {t('admin.events.edit.save')}
        </Button>
      </div>
    </form>
  );
}
