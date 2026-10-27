import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { adminPollsApi } from '../../../api';
import type { AdminPoll, PollAudience, PollScope, PollType } from '../../../api/adminPolls';
import { Button, Checkbox, FormField, Input, Modal, Select, useToast } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminErrorMessage } from '../campaigns/shared';
import {
  EMPTY_POLL_FORM,
  MAX_OPTIONS,
  MIN_OPTIONS,
  formFromPoll,
  toPollInput,
  validatePollForm,
  type PollFormState,
} from './pollsLogic';
import styles from './polls.module.css';

const TYPES: PollType[] = ['SINGLE', 'MULTI', 'RATING'];
const SCOPES: PollScope[] = ['GENERAL', 'COMMUNITY', 'EVENT', 'MENU'];
const AUDIENCES: PollAudience[] = ['ALL', 'STUDENT', 'STAFF'];

/** Anket oluşturma/düzenleme (POST /admin/polls, PUT /admin/polls/{id}). */
export function PollFormModal({ poll, onClose }: { poll: AdminPoll | null; onClose: () => void }) {
  const i18n = useI18n();
  const { t } = i18n;
  const toast = useToast();
  const qc = useQueryClient();
  const [f, setF] = useState<PollFormState>(poll ? formFromPoll(poll) : EMPTY_POLL_FORM);
  const [showErr, setShowErr] = useState(false);
  const set = (p: Partial<PollFormState>) => setF((s) => ({ ...s, ...p }));
  const err = validatePollForm(f);

  const save = useMutation({
    mutationFn: () => (poll ? adminPollsApi.updatePoll(poll.id, toPollInput(f)) : adminPollsApi.createPoll(toPollInput(f))),
    onSuccess: () => {
      toast.success(t('admin.polls.saved'));
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
    save.mutate();
  }
  const setOption = (i: number, v: string) => set({ options: f.options.map((o, j) => (j === i ? v : o)) });

  return (
    <Modal
      open
      onClose={onClose}
      title={poll ? t('admin.polls.edit') : t('admin.polls.create')}
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
        <FormField label={t('admin.polls.field.title')} required error={showErr && err === 'title' ? t('admin.polls.err.title') : null}>
          <Input value={f.title} maxLength={200} onChange={(e) => set({ title: e.target.value })} data-autofocus />
        </FormField>
        <div className={styles.grid2}>
          <FormField label={t('admin.polls.field.type')}>
            <Select value={f.type} onChange={(e) => set({ type: e.target.value as PollType })}>
              {TYPES.map((x) => (
                <option key={x} value={x}>
                  {t(`admin.polls.type.${x}` as 'admin.polls.type.SINGLE')}
                </option>
              ))}
            </Select>
          </FormField>
          <FormField label={t('admin.polls.field.audience')}>
            <Select value={f.audience} onChange={(e) => set({ audience: e.target.value as PollAudience })}>
              {AUDIENCES.map((x) => (
                <option key={x} value={x}>
                  {t(`admin.polls.audience.${x}` as 'admin.polls.audience.ALL')}
                </option>
              ))}
            </Select>
          </FormField>
          <FormField label={t('admin.polls.field.scope')}>
            <Select value={f.scope} onChange={(e) => set({ scope: e.target.value as PollScope })}>
              {SCOPES.map((x) => (
                <option key={x} value={x}>
                  {t(`admin.polls.scope.${x}` as 'admin.polls.scope.GENERAL')}
                </option>
              ))}
            </Select>
          </FormField>
          {(f.scope === 'COMMUNITY' || f.scope === 'EVENT') && (
            <FormField label={t('admin.polls.field.scopeId')} error={showErr && err === 'scopeId' ? t('admin.polls.err.scopeId') : null}>
              <Input className="ltr" inputMode="numeric" value={f.scopeId} onChange={(e) => set({ scopeId: e.target.value })} />
            </FormField>
          )}
          <FormField label={t('admin.polls.field.startsAt')}>
            <Input type="datetime-local" value={f.startsAt} onChange={(e) => set({ startsAt: e.target.value })} />
          </FormField>
          <FormField label={t('admin.polls.field.endsAt')} error={showErr && err === 'period' ? t('admin.polls.err.period') : null}>
            <Input type="datetime-local" value={f.endsAt} onChange={(e) => set({ endsAt: e.target.value })} />
          </FormField>
        </div>
        <Checkbox
          label={t('admin.polls.field.anonymous')}
          checked={f.anonymous}
          onChange={(e) => set({ anonymous: e.target.checked })}
        />
        <p className={styles.muted}>{t('admin.polls.field.anonymousHint')}</p>

        {f.type === 'RATING' ? (
          <p className={styles.muted}>{t('admin.polls.ratingHint')}</p>
        ) : (
          <fieldset className={styles.form} style={{ border: 0, padding: 0, margin: 0 }}>
            <legend>{t('admin.polls.field.options', { min: MIN_OPTIONS, max: MAX_OPTIONS })}</legend>
            {f.options.map((o, i) => (
              <div key={i} className={styles.optionRow}>
                <FormField label={t('admin.polls.option', { n: i + 1 })}>
                  <Input value={o} maxLength={120} onChange={(e) => setOption(i, e.target.value)} />
                </FormField>
                <Button
                  variant="ghost"
                  size="sm"
                  type="button"
                  disabled={f.options.length <= MIN_OPTIONS}
                  aria-label={t('admin.polls.optionRemove', { n: i + 1 })}
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
                {t('admin.polls.optionAdd')}
              </Button>
            </div>
            {showErr && (err === 'options' || err === 'optionEmpty' || err === 'optionDup') && (
              <p className={styles.error} role="alert">
                {t(`admin.polls.err.${err}` as 'admin.polls.err.options', { min: MIN_OPTIONS, max: MAX_OPTIONS })}
              </p>
            )}
          </fieldset>
        )}
      </form>
    </Modal>
  );
}
