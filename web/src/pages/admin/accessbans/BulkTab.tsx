// Toplu IP/CIDR ekleme: POST /api/admin/access-bans/bulk {text, reasonCode, note, force} -> {created, alreadyBanned, rejected[]}.
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { accessBanKeys, BAN_REASONS, bulkAdd, type BanReason, type BulkResult } from '../../../api/accessBans';
import { Button, Card, ConfirmDialog, FormField, Input, Select, Textarea, useToast } from '../../../components/ui';
import { ReasonField } from '../../../components/admin/guard/ReasonField';
import { ADMIN_REASON_MIN, isReasonValid } from '../../../components/admin/guard/match';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminErrorMessage, Callout } from '../campaigns/shared';
import styles from './accessBans.module.css';
import { isIpOrCidr, parseLines } from './logic';

/** Ortak sonuç raporu (toplu ekleme ve VPN/Tor yükleme). */
export function BulkResultView({ result, onForce }: { result: BulkResult; onForce?: () => void }) {
  const { t, td, formatNumber } = useI18n();
  const selfLocked = result.invalid.some((r) => r.error === 'BAN_SELF_LOCKOUT');
  return (
    <div className={styles.form} role="status">
      <p>
        <strong>{t('admin.ab.bulk.result')}</strong> — {t('admin.ab.bulk.added', { n: formatNumber(result.added) })} ·{' '}
        {t('admin.ab.bulk.skipped', { n: formatNumber(result.skipped) })}
      </p>
      {result.invalid.length > 0 && (
        <div>
          <p className={styles.muted}>{t('admin.ab.bulk.invalid', { n: formatNumber(result.invalid.length) })}</p>
          <ul className={styles.picker}>
            {result.invalid.map((l, i) => (
              <li key={`${l.line}-${i}`}>
                <span className={styles.muted}>#{l.line}</span> <code className={`${styles.mono} ltr`}>{l.value}</code>{' '}
                <span className={styles.muted}>{td(`admin.err.${l.error}`, l.error)}</span>
              </li>
            ))}
          </ul>
          {selfLocked && onForce && (
            <Button size="sm" variant="danger" onClick={onForce}>
              {t('admin.ab.bulk.force')}
            </Button>
          )}
        </div>
      )}
    </div>
  );
}

export function BulkTab() {
  const i18n = useI18n();
  const { t, formatNumber } = i18n;
  const toast = useToast();
  const qc = useQueryClient();
  const [text, setText] = useState('');
  const [reason, setReason] = useState<BanReason>('ABUSE');
  const [note, setNote] = useState('');
  // W1-B (T-013): toplu engel de islem gerekcesi ister (X-Admin-Reason).
  const [why, setWhy] = useState('');
  const whyOk = isReasonValid(why, ADMIN_REASON_MIN);
  const [result, setResult] = useState<BulkResult | null>(null);
  const [forceAsk, setForceAsk] = useState(false);

  const lines = useMemo(() => parseLines(text), [text]);
  // Satır biçimi: "IP-veya-CIDR [etiket]"; yalnız ilk sözcük doğrulanır.
  const badCount = useMemo(() => lines.filter((l) => !isIpOrCidr(l.split(/[\s,;]+/)[0])).length, [lines]);

  const run = useMutation({
    mutationFn: (force: boolean) =>
      bulkAdd(
        { text: lines.join('\n'), reasonCode: reason, note: note.trim() || undefined, ...(force ? { force: true } : {}) },
        { reason: why },
      ),
    onSuccess: (r) => {
      setResult(r);
      setForceAsk(false);
      toast.success(t('admin.ab.toast.added'));
      void qc.invalidateQueries({ queryKey: accessBanKeys.all });
    },
    onError: (e) => {
      setForceAsk(false);
      toast.error(adminErrorMessage(i18n, e));
    },
  });

  return (
    <div className={styles.stack}>
      <Card>
        <form
          className={styles.form}
          noValidate
          onSubmit={(e) => {
            e.preventDefault();
            if (lines.length > 0 && whyOk) run.mutate(false);
          }}
        >
          <p className={styles.muted}>{t('admin.ab.bulk.intro')}</p>
          <FormField label={t('admin.ab.bulk.lines')}>
            <Textarea
              className={`${styles.textarea} ltr`}
              value={text}
              rows={10}
              spellCheck={false}
              onChange={(e) => {
                setText(e.target.value);
                setResult(null);
              }}
            />
          </FormField>
          <p className={styles.muted} aria-live="polite">
            {t('admin.ab.bulk.preview', { n: formatNumber(lines.length) })}
            {badCount > 0 && ` · ${t('admin.ab.bulk.invalidLocal', { n: formatNumber(badCount) })}`}
          </p>
          <div className={styles.row2}>
            <FormField label={t('admin.ab.reason.label')}>
              <Select value={reason} onChange={(e) => setReason(e.target.value as BanReason)}>
                {BAN_REASONS.map((r) => (
                  <option key={r} value={r}>
                    {i18n.td(`admin.ab.reason.${r}`)}
                  </option>
                ))}
              </Select>
            </FormField>
            <FormField label={t('admin.ab.add.note')}>
              <Input value={note} maxLength={300} dir="auto" onChange={(e) => setNote(e.target.value)} />
            </FormField>
          </div>
          <ReasonField
            value={why}
            onChange={setWhy}
            minLength={ADMIN_REASON_MIN}
            label={t('admin.wp02.actionReason.label')}
            disabled={run.isPending}
          />
          <div>
            <Button type="submit" variant="danger" loading={run.isPending} disabled={lines.length === 0 || !whyOk}>
              {t('admin.ab.bulk.submit')}
            </Button>
          </div>
        </form>
      </Card>
      {result && (
        <Card>
          <BulkResultView result={result} onForce={() => setForceAsk(true)} />
        </Card>
      )}
      {run.isError && (
        <Callout tone="danger" role="alert">
          {adminErrorMessage(i18n, run.error)}
        </Callout>
      )}
      <ConfirmDialog
        open={forceAsk}
        onClose={() => setForceAsk(false)}
        onConfirm={() => run.mutate(true)}
        loading={run.isPending}
        danger
        title={t('admin.ab.self.title')}
        message={t('admin.ab.self.body')}
        confirmLabel={t('admin.ab.self.confirm')}
      />
    </div>
  );
}
