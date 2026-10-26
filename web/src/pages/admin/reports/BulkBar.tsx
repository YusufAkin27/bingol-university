// Toplu karar çubuğu (en çok 100 rapor). API: POST /api/admin/reports/bulk-resolve {ids, action, message?, reasonCode?} -> [{id, ok, error}].
import { useMutation } from '@tanstack/react-query';
import { useState } from 'react';
import { reportsApi } from '../../../api';
import type { ReasonTemplate, ReportReasonCode, ReportResolution } from '../../../api/types';
import { Button, ConfirmDialog, FormField, Select, Textarea, useToast } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { errorMessage } from '../../../lib/errors';
import { BULK_MAX, summarizeBulk, usesMessage } from '../moderation/modLogic';
import styles from '../moderation/moderation.module.css';
import { ReasonFields } from './ReasonFields';
import { MAX_MESSAGE, RESOLUTIONS, buildResolveRequest, validateDecision } from './reportLogic';

export function BulkBar({
  ids,
  templates,
  onClear,
  onDone,
}: {
  ids: number[];
  templates: ReasonTemplate[];
  onClear: () => void;
  onDone: () => void;
}) {
  const i18n = useI18n();
  const { t } = i18n;
  const toast = useToast();
  const [action, setAction] = useState<ReportResolution>('DISMISS');
  const [reasonCode, setReasonCode] = useState<ReportReasonCode | ''>('');
  const [message, setMessage] = useState('');
  const [confirm, setConfirm] = useState(false);
  const [failures, setFailures] = useState<string | null>(null);

  const error = validateDecision(action, message);

  const run = useMutation({
    mutationFn: () => reportsApi.bulkResolve({ ids, ...buildResolveRequest(action, message, reasonCode) }),
    onSuccess: (rows) => {
      const s = summarizeBulk(rows ?? []);
      setConfirm(false);
      if (s.failed > 0) {
        toast.error(t('admin.reports.bulk.result', { ok: s.ok, failed: s.failed }));
        setFailures(s.errors.map((e) => `#${e.id} ${i18n.td(`common.error.${e.error}`, e.error)}`).join(', '));
      } else {
        toast.success(t('admin.reports.bulk.result', { ok: s.ok, failed: 0 }));
        setFailures(null);
      }
      onDone();
    },
    onError: (e) => {
      setConfirm(false);
      toast.error(errorMessage(i18n, e));
    },
  });

  if (ids.length === 0 && !failures) return null;
  return (
    <div className={styles.bulkBar} role="region" aria-label={t('admin.reports.bulk.title')}>
      {ids.length > 0 && (
        <>
          <strong>{t('admin.reports.bulk.selected', { n: ids.length })}</strong>
          {ids.length >= BULK_MAX && <span className={styles.muted}>{t('admin.reports.bulk.max')}</span>}
          <FormField label={t('admin.reports.decision.label')}>
            <Select value={action} onChange={(e) => setAction(e.target.value as ReportResolution)}>
              {RESOLUTIONS.map((r) => (
                <option key={r} value={r}>
                  {t(`admin.reports.resolution.${r}`)}
                </option>
              ))}
            </Select>
          </FormField>
          <ReasonFields
            value={reasonCode}
            onChange={setReasonCode}
            templates={templates}
            onTemplateText={usesMessage(action) ? setMessage : undefined}
          />
          {usesMessage(action) && (
            <FormField
              label={t(`admin.reports.decision.message.${action as 'WARN' | 'SUSPEND_USER'}`)}
              required={action === 'SUSPEND_USER'}
              error={
                error
                  ? error === 'reasonRequired'
                    ? t('admin.reports.decision.reasonRequired')
                    : t('admin.reports.decision.tooLong')
                  : null
              }
            >
              <Textarea
                rows={2}
                value={message}
                maxLength={MAX_MESSAGE + 50}
                dir="auto"
                onChange={(e) => setMessage(e.target.value)}
              />
            </FormField>
          )}
          <div className={styles.actions}>
            <Button
              variant={action === 'SUSPEND_USER' ? 'danger' : 'primary'}
              disabled={!!error}
              onClick={() => setConfirm(true)}
            >
              {t('admin.reports.bulk.apply')}
            </Button>
            <Button variant="ghost" onClick={onClear}>
              {t('admin.reports.bulk.clear')}
            </Button>
          </div>
        </>
      )}
      {failures && (
        <p className={styles.muted} role="status">
          {t('admin.reports.bulk.failedList', { list: failures })}
        </p>
      )}
      <ConfirmDialog
        open={confirm}
        onClose={() => setConfirm(false)}
        onConfirm={() => run.mutate()}
        loading={run.isPending}
        danger={action === 'SUSPEND_USER' || action === 'HIDE'}
        title={t('admin.reports.bulk.confirmTitle')}
        confirmLabel={t(`admin.reports.resolution.${action}`)}
        message={t('admin.reports.bulk.confirmBody', {
          n: ids.length,
          action: t(`admin.reports.resolution.${action}`),
        })}
      />
    </div>
  );
}
