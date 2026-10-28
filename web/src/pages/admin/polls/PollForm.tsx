import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { adminPollsApi } from '../../../api';
import type { PollDetail, PollShowResults, PollType } from '../../../api/adminPolls';
import { Button, Checkbox, FormField, Input, Modal, Select, Textarea, useToast } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminErrorMessage } from '../campaigns/shared';
import {
  EMPTY_POLL_FORM,
  MAX_AUDIENCE_TEXT,
  MAX_DESCRIPTION,
  MAX_GRADE,
  MAX_OPTIONS,
  MAX_OPTION_TEXT,
  MAX_TITLE,
  MIN_OPTIONS,
  POLL_TYPES,
  SHOW_RESULTS,
  formFromDetail,
  isStructureLocked,
  toCreateBody,
  toUpdateBody,
  validatePollForm,
  type PollFormError,
  type PollFormState,
} from './pollsLogic';
import styles from './polls.module.css';

/**
 * Anket oluşturma/düzenleme. Yönetim ucu yok: POST /api/polls ve PATCH /api/polls/{id} ADMIN JWT ile çalışır
 * (kapsam GLOBAL; kulüp anketini kulüp yöneticisi, menü anketini sistem açar).
 */
export function PollFormModal({ poll, onClose }: { poll: PollDetail | null; onClose: () => void }) {
  const i18n = useI18n();
  const { t } = i18n;
  const toast = useToast();
  const qc = useQueryClient();
  const initial = poll ? formFromDetail(poll) : EMPTY_POLL_FORM;
  const [f, setF] = useState<PollFormState>(initial);
  const [showErr, setShowErr] = useState(false);
  const set = (p: Partial<PollFormState>) => setF((s) => ({ ...s, ...p }));
  const err = validatePollForm(f);
  const locked = poll ? isStructureLocked(poll) : false;
  const isDraft = !poll || poll.status === 'DRAFT';
  const errText = (code: PollFormError) =>
    showErr && err === code ? i18n.td(`admin.p03.err.${code}`, code, { min: MIN_OPTIONS, max: MAX_OPTIONS }) : null;

  const save = useMutation({
    mutationFn: () => (poll ? adminPollsApi.updatePoll(poll.id, toUpdateBody(initial, f)) : adminPollsApi.createPoll(toCreateBody(f))),
    onSuccess: () => {
      toast.success(t('admin.p03.saved'));
      void qc.invalidateQueries({ queryKey: ['adminPolls'] });
      onClose();
    },
    onError: (e) => toast.error(adminErrorMessage(i18n, e)),
  });

  function submit() {
    if (err) {
      setShowErr(true);
      return;
    }
    if (poll && Object.keys(toUpdateBody(initial, f)).length === 0) {
      onClose();
      return;
    }
    save.mutate();
  }
  const setOption = (i: number, v: string) => set({ options: f.options.map((o, j) => (j === i ? v : o)) });
  const multi = f.type === 'MULTI' || f.type === 'RANKED';

  return (
    <Modal
      open
      onClose={onClose}
      title={poll ? t('admin.p03.edit') : t('admin.p03.create')}
      size="lg"
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>
            {t('common.cancel')}
          </Button>
          <Button loading={save.isPending} onClick={submit} data-testid="poll-save">
            {t('common.save')}
          </Button>
        </>
      }
    >
      <form
        className={styles.form}
        onSubmit={(e) => {
          e.preventDefault();
          submit();
        }}
      >
        {!poll && <p className={styles.muted}>{t('admin.p03.form.scopeNote')}</p>}
        {locked && (
          <p className={styles.notice} role="status">
            {t('admin.p03.form.locked')}
          </p>
        )}
        <FormField label={t('admin.p03.field.title')} required error={errText('title')}>
          <Input value={f.title} maxLength={MAX_TITLE} onChange={(e) => set({ title: e.target.value })} data-autofocus />
        </FormField>
        <FormField label={t('admin.p03.field.description')} error={errText('description')}>
          <Textarea rows={3} value={f.description} maxLength={MAX_DESCRIPTION} onChange={(e) => set({ description: e.target.value })} />
        </FormField>
        <div className={styles.grid2}>
          <FormField label={t('admin.p03.field.type')}>
            <Select value={f.type} disabled={locked} onChange={(e) => set({ type: e.target.value as PollType })}>
              {POLL_TYPES.map((x) => (
                <option key={x} value={x}>
                  {i18n.td(`admin.p03.type.${x}`, x)}
                </option>
              ))}
            </Select>
          </FormField>
          <FormField label={t('admin.p03.field.showResults')}>
            <Select value={f.showResults} onChange={(e) => set({ showResults: e.target.value as PollShowResults })}>
              {SHOW_RESULTS.map((x) => (
                <option key={x} value={x}>
                  {i18n.td(`admin.p03.showResults.${x}`, x)}
                </option>
              ))}
            </Select>
          </FormField>
          <FormField label={t('admin.p03.field.opensAt')} hint={t('admin.p03.field.opensAtHint')}>
            <Input type="datetime-local" value={f.opensAt} disabled={locked} onChange={(e) => set({ opensAt: e.target.value })} />
          </FormField>
          <FormField label={t('admin.p03.field.closesAt')} error={errText('period') ?? errText('closesPast')}>
            <Input type="datetime-local" value={f.closesAt} onChange={(e) => set({ closesAt: e.target.value })} />
          </FormField>
        </div>
        <div className={styles.checks}>
          <Checkbox label={t('admin.p03.field.anonymous')} checked={f.anonymous} disabled={locked} onChange={(e) => set({ anonymous: e.target.checked })} />
          <Checkbox label={t('admin.p03.field.allowChange')} checked={f.allowChangeVote} disabled={locked} onChange={(e) => set({ allowChangeVote: e.target.checked })} />
          <Checkbox label={t('admin.p03.field.notify')} checked={f.notify} onChange={(e) => set({ notify: e.target.checked })} />
        </div>
        <p className={styles.muted}>{t('admin.p03.field.anonymousHint')}</p>

        {f.type === 'RATING' ? (
          <p className={styles.muted}>{t('admin.p03.ratingHint')}</p>
        ) : (
          <fieldset className={styles.fieldset} disabled={locked}>
            <legend>{t('admin.p03.field.options', { min: MIN_OPTIONS, max: MAX_OPTIONS })}</legend>
            {f.options.map((o, i) => (
              <div key={i} className={styles.optionRow}>
                <FormField label={t('admin.p03.option', { n: i + 1 })}>
                  <Input value={o} maxLength={MAX_OPTION_TEXT} onChange={(e) => setOption(i, e.target.value)} />
                </FormField>
                <Button
                  variant="ghost"
                  size="sm"
                  type="button"
                  disabled={f.options.length <= MIN_OPTIONS}
                  aria-label={t('admin.p03.optionRemove', { n: i + 1 })}
                  onClick={() => set({ options: f.options.filter((_, j) => j !== i) })}
                >
                  ×
                </Button>
              </div>
            ))}
            <div>
              <Button
                variant="secondary"
                size="sm"
                type="button"
                disabled={f.options.length >= MAX_OPTIONS}
                onClick={() => set({ options: [...f.options, ''] })}
              >
                {t('admin.p03.optionAdd')}
              </Button>
            </div>
            {showErr && (err === 'options' || err === 'optionEmpty' || err === 'optionLong' || err === 'optionDup') && (
              <p className={styles.error} role="alert">
                {i18n.td(`admin.p03.err.${err}`, err, { min: MIN_OPTIONS, max: MAX_OPTIONS })}
              </p>
            )}
            {multi && (
              <FormField label={t('admin.p03.field.maxChoices')} hint={t('admin.p03.field.maxChoicesHint')} error={errText('maxChoices')}>
                <Input className="ltr" inputMode="numeric" value={f.maxChoices} onChange={(e) => set({ maxChoices: e.target.value.replace(/\D/g, '') })} />
              </FormField>
            )}
          </fieldset>
        )}

        <fieldset className={styles.fieldset} disabled={locked}>
          <legend>{t('admin.p03.field.audience')}</legend>
          <p className={styles.muted}>{t('admin.p03.field.audienceHint')}</p>
          <div className={styles.grid2}>
            <FormField label={t('admin.p03.field.faculty')} error={errText('audience')}>
              <Input value={f.faculty} maxLength={MAX_AUDIENCE_TEXT} onChange={(e) => set({ faculty: e.target.value })} />
            </FormField>
            <FormField label={t('admin.p03.field.department')}>
              <Input value={f.department} maxLength={MAX_AUDIENCE_TEXT} onChange={(e) => set({ department: e.target.value })} />
            </FormField>
            <FormField label={t('admin.p03.field.grade')}>
              <Input value={f.grade} maxLength={MAX_GRADE} onChange={(e) => set({ grade: e.target.value })} />
            </FormField>
          </div>
        </fieldset>

        {isDraft && (
          <Checkbox
            label={t('admin.p03.field.draft')}
            checked={f.draft}
            onChange={(e) => set({ draft: e.target.checked })}
          />
        )}
      </form>
    </Modal>
  );
}
