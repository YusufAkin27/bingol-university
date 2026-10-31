// "Yeni sürümü yayınla" sihirbazı: 1) sürüm + kip + etki önizlemesi, 2) gerekçe + onay (FORCE için "ZORLA" yazdırılır).
import { useState } from 'react';
import { enforceAppVersion, type AppPlatform, type EnforceMode, type PlatformSummary, type VersionRow } from '../../../api/appVersions';
import { Button, FormField, Input, Modal } from '../../../components/ui';
import { GuardedDialog } from '../../../components/admin/GuardedDialog';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminError } from '../../../lib/errors';
import { Callout, RadioCards } from '../campaigns/shared';
import { enforceIssues, impactOf, isVersion, type IssueCode, type StoreInfo } from './lib';
import styles from './appVersions.module.css';

const MODES: EnforceMode[] = ['FORCE', 'SOFT', 'OFF'];
const REASON_MIN = 5;

export function PublishWizard({
  platform,
  summary,
  rows,
  store,
  onClose,
  onDone,
}: {
  platform: AppPlatform;
  summary: PlatformSummary;
  rows: VersionRow[];
  store: StoreInfo;
  onClose: () => void;
  onDone: () => void;
}) {
  const i18n = useI18n();
  const { t, formatNumber } = i18n;
  const [step, setStep] = useState<1 | 2>(1);
  const [version, setVersion] = useState(summary.latestVersion);
  const [mode, setMode] = useState<EnforceMode>('FORCE');
  const platformName = t(`admin.uv.platform.${platform}`);
  const v = version.trim();

  const issues = enforceIssues({
    platform,
    mode,
    version: v,
    min: summary.minVersion,
    latest: summary.latestVersion,
    store,
    rows,
  });
  const impact = impactOf(rows, platform, mode, v);
  const canProceed = issues.errors.length === 0 && (mode === 'OFF' || isVersion(v));
  const issueText = (code: IssueCode) =>
    t(`admin.uv.issue.${code}`, { latest: summary.latestVersion, min: summary.minVersion });
  const afterMin = mode === 'FORCE' ? v : mode === 'OFF' ? '1.0.0' : summary.minVersion;
  const afterLatest = mode === 'OFF' ? summary.latestVersion : v;

  if (step === 1) {
    return (
      <Modal
        open
        onClose={onClose}
        size="md"
        title={t('admin.uv.wizard.title', { platform: platformName })}
        footer={
          <>
            <Button variant="ghost" onClick={onClose}>
              {t('admin.uv.wizard.cancel')}
            </Button>
            <Button disabled={!canProceed} onClick={() => setStep(2)} data-testid="uv-next">
              {t('admin.uv.wizard.next')}
            </Button>
          </>
        }
      >
        <div className={styles.wizard}>
          <p>{t('admin.uv.wizard.intro')}</p>
          {mode !== 'OFF' && (
            <FormField
              label={t('admin.uv.wizard.version')}
              hint={t('admin.uv.wizard.versionHint')}
              error={v && !isVersion(v) ? t('admin.uv.issue.VERSION_INVALID') : null}
            >
              <Input
                className="ltr"
                value={version}
                onChange={(e) => setVersion(e.target.value)}
                placeholder="2.0.5"
                autoComplete="off"
                inputMode="decimal"
                data-testid="uv-version"
              />
            </FormField>
          )}
          <RadioCards<EnforceMode>
            name={`uv-mode-${platform}`}
            legend={t('admin.uv.wizard.mode')}
            value={mode}
            onChange={setMode}
            options={MODES.map((m) => ({
              value: m,
              label: t(`admin.uv.wizard.mode.${m}`),
              hint: t(`admin.uv.wizard.mode.${m}.hint`),
              tone: m === 'FORCE' ? ('danger' as const) : undefined,
            }))}
          />
          <p className={styles.impact} role="status" data-testid="uv-impact">
            {t(`admin.uv.wizard.impact.${mode}`, { n: formatNumber(impact) })}
            {mode !== 'OFF' && <span className={styles.muted}> {t('admin.uv.wizard.impactNote')}</span>}
          </p>
          {issues.errors.map((c) => (
            <Callout key={c} tone="danger" role="alert">
              {issueText(c)}
            </Callout>
          ))}
          {issues.warnings.map((c) => (
            <Callout key={c} tone="warning">
              {issueText(c)}
            </Callout>
          ))}
        </div>
      </Modal>
    );
  }

  return (
    <GuardedDialog
      open
      onClose={onClose}
      danger={mode === 'FORCE'}
      title={t(`admin.uv.confirm.title.${mode}`, { platform: platformName, version: v })}
      message={t(`admin.uv.confirm.message.${mode}`, { platform: platformName, version: v })}
      consequence={t(`admin.uv.confirm.consequence.${mode}`)}
      confirmLabel={t(`admin.uv.confirm.btn.${mode}`)}
      requireReason
      reasonMinLength={REASON_MIN}
      typeToConfirm={mode === 'FORCE' ? t('admin.uv.confirm.typeWord') : undefined}
      extra={
        <div className={styles.confirmExtra}>
          <p className={styles.ltr}>
            {t('admin.uv.confirm.diff', {
              minFrom: summary.minVersion,
              minTo: afterMin,
              latestFrom: summary.latestVersion,
              latestTo: afterLatest,
            })}
          </p>
          <p>{t('admin.uv.confirm.impact', { n: formatNumber(impact) })}</p>
          {issues.warnings.map((c) => (
            <Callout key={c} tone="warning">
              {issueText(c)}
            </Callout>
          ))}
        </div>
      }
      successMessage={t(`admin.uv.confirm.success.${mode}`, { platform: platformName, version: v })}
      errorMessage={(e) => adminError(i18n, e, 'admin.uv.err', 'admin.err')}
      onConfirm={({ reason, idempotencyKey }) =>
        enforceAppVersion(
          { platform, mode, ...(mode === 'OFF' ? {} : { version: v }) },
          { reason, idempotencyKey },
        )
      }
      onSuccess={onDone}
    />
  );
}
