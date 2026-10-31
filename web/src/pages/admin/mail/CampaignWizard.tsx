import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useMemo, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  createMailCampaign,
  listTemplates,
  mailKeys,
  previewAudience,
  scheduleMailCampaign,
  type AudiencePreview,
  type MailCampaignView,
  type MailLang,
} from '../../../api/adminMail';
import {
  Button,
  Card,
  EmptyState,
  ErrorState,
  FormField,
  Icon,
  Input,
  PageHeader,
  Select,
  Skeleton,
  Spinner,
  Textarea,
  useToast,
} from '../../../components/ui';
import { ReasonField } from '../../../components/admin/guard/ReasonField';
import { ADMIN_REASON_MIN, isReasonValid } from '../../../components/admin/guard/match';
import { useI18n } from '../../../i18n/I18nProvider';
import { usePageTitle } from '../../../lib/hooks';
import { paths } from '../../../paths';
import { Callout, RadioCards } from '../campaigns/shared';
import type { PickedUser } from '../campaigns/lib';
import { UserPicker } from '../campaigns/UserPicker';
import {
  MAX_LIST,
  MAX_SCHEDULE_DAYS,
  audienceReady,
  buildAudience,
  emptyAudience,
  mailErrorMessage,
  parseEmails,
  parseSchedule,
  type AudienceState,
} from './mailLogic';
import styles from './mail.module.css';

const STEPS = ['template', 'audience', 'preview', 'schedule', 'confirm'] as const;
type Step = (typeof STEPS)[number];

export function CampaignWizard() {
  const i18n = useI18n();
  const { t, formatNumber, formatDateTime } = i18n;
  usePageTitle(t('admin.mail.wizard.title'));
  const navigate = useNavigate();
  const toast = useToast();
  const qc = useQueryClient();

  const [step, setStep] = useState<Step>('template');
  const [name, setName] = useState('');
  const [templateId, setTemplateId] = useState<number | null>(null);
  const [aud, setAud] = useState<AudienceState>(emptyAudience);
  const [picked, setPicked] = useState<PickedUser[]>([]);
  const [mode, setMode] = useState<'now' | 'later'>('now');
  const [when, setWhen] = useState('');
  const [error, setError] = useState<string | null>(null);
  // W1-B (T-013): kampanya olusturma + zamanlama gerekce ister (X-Admin-Reason).
  const [why, setWhy] = useState('');
  const whyOk = isReasonValid(why, ADMIN_REASON_MIN);
  // Çift gönderim koruması: form açılışında bir kez üretilir; aynı anahtarla tekrar POST aynı kampanyayı döndürür.
  const requestKey = useRef<string>(crypto.randomUUID());
  const created = useRef<MailCampaignView | null>(null);

  const templates = useQuery({
    queryKey: mailKeys.templates({ status: 'PUBLISHED', size: 100, wizard: true }),
    queryFn: () => listTemplates({ status: 'PUBLISHED', size: 100 }),
  });
  const template = templates.data?.items.find((x) => x.id === templateId) ?? null;

  const audience = useMemo(() => buildAudience({ ...aud, userIds: picked.map((u) => u.id) }), [aud, picked]);
  const audState: AudienceState = { ...aud, userIds: picked.map((u) => u.id) };
  const ready = audienceReady(audState);

  const prev = useQuery({
    queryKey: ['adminMail', 'audiencePreview', audience, templateId],
    queryFn: () => previewAudience(audience, templateId ?? undefined),
    enabled: (step === 'preview' || step === 'confirm') && ready && templateId !== null,
  });

  const scheduleCheck = mode === 'later' ? parseSchedule(when) : null;
  const scheduleErr = scheduleCheck && 'error' in scheduleCheck ? scheduleCheck.error : null;

  const emails = parseEmails(aud.emailsText);

  const submit = useMutation({
    mutationFn: async () => {
      const iso = scheduleCheck && 'iso' in scheduleCheck ? scheduleCheck.iso : null;
      if (!created.current) {
        created.current = await createMailCampaign(
          {
            name: name.trim(),
            templateId: templateId as number,
            audience,
            scheduledAt: iso,
            requestKey: requestKey.current,
          },
          { reason: why },
        );
      }
      return scheduleMailCampaign(created.current.id, iso, { reason: why });
    },
    onSuccess: (c) => {
      void qc.invalidateQueries({ queryKey: ['adminMail', 'campaigns'] });
      toast.success(t('admin.mail.wizard.sent'));
      navigate(`${paths.admin.mailCampaigns}/${c.id}`);
    },
    onError: (e) => {
      const msg = mailErrorMessage(i18n, e);
      setError(msg);
      toast.error(msg);
    },
  });

  const idx = STEPS.indexOf(step);
  const stepValid: Record<Step, boolean> = {
    template: name.trim().length > 0 && templateId !== null,
    audience: ready,
    preview: !!prev.data && prev.data.willSend > 0,
    schedule: mode === 'now' || (scheduleCheck !== null && 'iso' in scheduleCheck),
    confirm: true,
  };
  const go = (d: number) => {
    setError(null);
    if (d < 0) {
      // Geri dönüp değişiklik yapılabilir: eski taslak kaydı artık geçersiz, yeni anahtar üret.
      created.current = null;
      requestKey.current = crypto.randomUUID();
    }
    setStep(STEPS[Math.max(0, Math.min(STEPS.length - 1, idx + d))]);
  };

  return (
    <div>
      <PageHeader
        title={t('admin.mail.wizard.title')}
        breadcrumbs={[{ label: t('admin.mail.campaigns.title'), to: paths.admin.mailCampaigns }, { label: t('admin.mail.wizard.title') }]}
      />
      <ol className={styles.steps} aria-label={t('admin.mail.wizard.steps')}>
        {STEPS.map((s, i) => (
          <li key={s} className={`${styles.step} ${s === step ? styles.stepOn : ''}`} aria-current={s === step ? 'step' : undefined}>
            <span className={styles.stepNum} aria-hidden="true">
              {i < idx ? '✓' : i + 1}
            </span>
            {t(`admin.mail.wizard.step.${s}`)}
          </li>
        ))}
      </ol>

      <Card>
        {step === 'template' && (
          <div className={styles.stack}>
            <FormField label={t('admin.mail.wizard.name')} required hint={t('admin.mail.wizard.nameHint')}>
              <Input value={name} maxLength={120} onChange={(e) => setName(e.target.value)} />
            </FormField>
            {templates.isLoading && <Skeleton height={60} />}
            {templates.isError && (
              <ErrorState compact description={mailErrorMessage(i18n, templates.error)} onRetry={() => void templates.refetch()} />
            )}
            {templates.data && templates.data.items.length === 0 && (
              <EmptyState
                compact
                icon="mail"
                title={t('admin.mail.wizard.noPublished')}
                description={t('admin.mail.wizard.noPublishedHint')}
              />
            )}
            {templates.data && templates.data.items.length > 0 && (
              <FormField label={t('admin.mail.wizard.template')} required hint={t('admin.mail.wizard.templateHint')}>
                <Select value={templateId ?? ''} onChange={(e) => setTemplateId(e.target.value ? Number(e.target.value) : null)}>
                  <option value="">{t('admin.mail.wizard.pick')}</option>
                  {templates.data.items.map((x) => (
                    <option key={x.id} value={x.id}>
                      {x.name} (v{x.version} · {x.languages.map((l) => l.toUpperCase()).join('/')})
                    </option>
                  ))}
                </Select>
              </FormField>
            )}
          </div>
        )}

        {step === 'audience' && (
          <div className={styles.stack}>
            <RadioCards
              name="mail-aud"
              legend={t('admin.mail.aud.legend')}
              value={aud.type}
              columns={2}
              onChange={(v) => setAud((a) => ({ ...a, type: v }))}
              options={(['ALL', 'FILTER', 'USERS', 'EMAILS'] as const).map((v) => ({
                value: v,
                label: t(`admin.mail.aud.${v}`),
                hint: t(`admin.mail.aud.${v}.hint`),
              }))}
            />
            {aud.type === 'FILTER' && (
              <div>
                <p className={styles.muted}>{t('admin.mail.aud.filterHint')}</p>
                <div className={styles.grid2}>
                  <FormField label={t('admin.mail.aud.faculty')}>
                    <Input value={aud.faculty} onChange={(e) => setAud({ ...aud, faculty: e.target.value })} />
                  </FormField>
                  <FormField label={t('admin.mail.aud.department')}>
                    <Input value={aud.department} onChange={(e) => setAud({ ...aud, department: e.target.value })} />
                  </FormField>
                  <FormField label={t('admin.mail.aud.classYear')}>
                    <Input type="number" min={0} max={8} value={aud.classYear} onChange={(e) => setAud({ ...aud, classYear: e.target.value })} />
                  </FormField>
                  <FormField label={t('admin.mail.aud.role')}>
                    <Select value={aud.role} onChange={(e) => setAud({ ...aud, role: e.target.value as AudienceState['role'] })}>
                      <option value="">{t('common.all')}</option>
                      <option value="USER">{t('admin.mail.aud.role.USER')}</option>
                      <option value="ADMIN">{t('admin.mail.aud.role.ADMIN')}</option>
                    </Select>
                  </FormField>
                  <FormField label={t('admin.mail.aud.language')}>
                    <Select value={aud.language} onChange={(e) => setAud({ ...aud, language: e.target.value as '' | MailLang })}>
                      <option value="">{t('common.all')}</option>
                      {(['tr', 'en', 'ar'] as MailLang[]).map((l) => (
                        <option key={l} value={l}>
                          {t(`admin.mail.langName.${l}`)}
                        </option>
                      ))}
                    </Select>
                  </FormField>
                  <FormField label={t('admin.mail.aud.communityId')}>
                    <Input type="number" min={1} value={aud.communityId} onChange={(e) => setAud({ ...aud, communityId: e.target.value })} />
                  </FormField>
                </div>
                {!ready && <Callout tone="warning" role="status">{t('admin.mail.aud.filterNeeded')}</Callout>}
              </div>
            )}
            {aud.type === 'USERS' && <UserPicker value={picked} onChange={setPicked} />}
            {aud.type === 'EMAILS' && (
              <div>
                <FormField label={t('admin.mail.aud.emails')} hint={t('admin.mail.aud.emailsHint', { max: formatNumber(MAX_LIST) })}>
                  <Textarea
                    className={styles.textarea}
                    rows={6}
                    value={aud.emailsText}
                    onChange={(e) => setAud({ ...aud, emailsText: e.target.value })}
                  />
                </FormField>
                <p className={styles.muted} role="status">
                  {t('admin.mail.aud.emailsParsed', { valid: formatNumber(emails.valid.length), invalid: formatNumber(emails.invalid.length), dup: formatNumber(emails.duplicates) })}
                </p>
                {emails.valid.length > MAX_LIST && <Callout tone="danger" role="alert">{t('admin.mail.err.MAIL_CAMPAIGN_AUDIENCE_INVALID')}</Callout>}
              </div>
            )}
            {aud.type === 'ALL' && <Callout tone="info">{t('admin.mail.aud.allNote')}</Callout>}
          </div>
        )}

        {step === 'preview' && (
          <div className={styles.stack} aria-live="polite">
            {prev.isLoading && <Spinner label={t('common.loading')} />}
            {prev.isError && <ErrorState compact description={mailErrorMessage(i18n, prev.error)} onRetry={() => void prev.refetch()} />}
            {prev.data && <AudienceSummary data={prev.data} />}
          </div>
        )}

        {step === 'schedule' && (
          <div className={styles.stack}>
            <RadioCards
              name="mail-when"
              legend={t('admin.mail.sched.legend')}
              value={mode}
              columns={2}
              onChange={setMode}
              options={[
                { value: 'now', label: t('admin.mail.sched.now'), hint: t('admin.mail.sched.nowHint') },
                { value: 'later', label: t('admin.mail.sched.later'), hint: t('admin.mail.sched.laterHint', { days: MAX_SCHEDULE_DAYS }) },
              ]}
            />
            {mode === 'later' && (
              <FormField
                label={t('admin.mail.sched.at')}
                required
                error={scheduleErr ? t(`admin.mail.sched.err.${scheduleErr}`, { days: MAX_SCHEDULE_DAYS }) : null}
              >
                <Input type="datetime-local" value={when} onChange={(e) => setWhen(e.target.value)} />
              </FormField>
            )}
          </div>
        )}

        {step === 'confirm' && (
          <div className={styles.stack}>
            <Callout tone="warning" title={t('admin.mail.confirm.title')}>
              {t(mode === 'now' ? 'admin.mail.confirm.nowNote' : 'admin.mail.confirm.laterNote')}
            </Callout>
            <dl className={styles.dl}>
              <dt>{t('admin.mail.wizard.name')}</dt>
              <dd>{name}</dd>
              <dt>{t('admin.mail.wizard.template')}</dt>
              <dd>{template ? `${template.name} (v${template.version})` : '—'}</dd>
              <dt>{t('admin.mail.wizard.step.audience')}</dt>
              <dd>{t(`admin.mail.aud.${aud.type}`)}</dd>
              <dt>{t('admin.mail.confirm.recipients')}</dt>
              <dd>{prev.data ? formatNumber(prev.data.willSend) : '…'}</dd>
              <dt>{t('admin.mail.confirm.when')}</dt>
              <dd>{mode === 'now' ? t('admin.mail.sched.now') : formatDateTime(when)}</dd>
            </dl>
            <ReasonField
              value={why}
              onChange={setWhy}
              minLength={ADMIN_REASON_MIN}
              label={t('admin.wp02.actionReason.label')}
              disabled={submit.isPending}
            />
            {error && (
              <div role="alert">
                <Callout tone="danger">{error}</Callout>
              </div>
            )}
          </div>
        )}
      </Card>

      <div className={styles.footer}>
        <Button variant="secondary" onClick={() => (idx === 0 ? navigate(paths.admin.mailCampaigns) : go(-1))} disabled={submit.isPending}>
          {idx === 0 ? t('common.cancel') : t('common.back')}
        </Button>
        {step !== 'confirm' ? (
          <Button onClick={() => go(1)} disabled={!stepValid[step]}>
            {t('admin.mail.wizard.next')}
          </Button>
        ) : (
          <Button
            onClick={() => submit.mutate()}
            loading={submit.isPending}
            disabled={!prev.data || prev.data.willSend === 0 || !whyOk}
            leftIcon={<Icon name="mail" size={18} />}
          >
            {t(mode === 'now' ? 'admin.mail.wizard.sendNow' : 'admin.mail.wizard.scheduleIt')}
          </Button>
        )}
      </div>
    </div>
  );
}

function AudienceSummary({ data }: { data: AudiencePreview }) {
  const { t, td, formatNumber } = useI18n();
  const reasons = Object.entries(data.skippedByReason ?? {}).filter(([, n]) => n > 0);
  const langs = Object.entries(data.languages ?? {}).filter(([, n]) => n > 0);
  return (
    <>
      <div className={styles.stats}>
        <div className={styles.stat}>
          <p className={styles.statLabel}>{t('admin.mail.prev.total')}</p>
          <p className={styles.statValue}>{formatNumber(data.total)}</p>
        </div>
        <div className={styles.stat} data-testid="will-send">
          <p className={styles.statLabel}>{t('admin.mail.prev.willSend')}</p>
          <p className={styles.statValue}>{formatNumber(data.willSend)}</p>
        </div>
        <div className={styles.stat}>
          <p className={styles.statLabel}>{t('admin.mail.prev.skipped')}</p>
          <p className={styles.statValue}>{formatNumber(data.skipped)}</p>
        </div>
        {data.unmatched > 0 && (
          <div className={styles.stat}>
            <p className={styles.statLabel}>{t('admin.mail.prev.unmatched')}</p>
            <p className={styles.statValue}>{formatNumber(data.unmatched)}</p>
          </div>
        )}
      </div>
      {data.willSend === 0 && <Callout tone="danger" role="alert">{t('admin.mail.err.MAIL_CAMPAIGN_NO_RECIPIENTS')}</Callout>}
      {data.unmatched > 0 && <Callout tone="info">{t('admin.mail.prev.unmatchedHint')}</Callout>}
      <div className={styles.grid2}>
        {reasons.length > 0 && (
          <div>
            <h3>{t('admin.mail.prev.reasons')}</h3>
            <ul className={styles.kv}>
              {reasons.map(([k, n]) => (
                <li key={k}>
                  <span>{td(`admin.mail.skip.${k}`, k)}</span>
                  <strong>{formatNumber(n)}</strong>
                </li>
              ))}
            </ul>
          </div>
        )}
        {langs.length > 0 && (
          <div>
            <h3>{t('admin.mail.prev.languages')}</h3>
            <ul className={styles.kv}>
              {langs.map(([k, n]) => (
                <li key={k}>
                  <span>{td(`admin.mail.langName.${k}`, k)}</span>
                  <strong>{formatNumber(n)}</strong>
                </li>
              ))}
            </ul>
            {data.languageFallback > 0 && (
              <p className={styles.muted}>{t('admin.mail.prev.fallback', { n: formatNumber(data.languageFallback) })}</p>
            )}
          </div>
        )}
      </div>
    </>
  );
}

export { AudienceSummary };
