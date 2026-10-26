// SAYFA: Yeni kampanya (/admin/campaigns/new) - bildirim oluşturucu
// API: POST /api/admin/push/audience-count, POST /api/admin/push/campaigns (api/campaigns.ts), GET /api/admin/users?q= (kullanıcı arama),
//      GET /api/departments (bölüm listesi). Taslak localStorage'a otomatik kaydedilir.
import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useEffect, useMemo, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { publicApi } from '../../api/client';
import { countAudience, createCampaign } from '../../api/campaigns';
import { qk } from '../../api/queryKeys';
import type { AudienceType, Lang } from '../../api/types';
import {
  Button,
  Card,
  ConfirmDialog,
  FormField,
  Icon,
  Input,
  PageHeader,
  Select,
  Spinner,
  useToast,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import { paths } from '../../paths';
import { ContentEditor } from './campaigns/ContentEditor';
import { PhonePreview } from './campaigns/PhonePreview';
import { SendDialog } from './campaigns/SendDialog';
import { UserPicker } from './campaigns/UserPicker';
import {
  AUDIENCE_TYPES,
  MAX_SCHEDULE_DAYS,
  NOTIF_TYPES,
  TARGET_TYPES,
  audienceFromState,
  buildRequest,
  clearDraft,
  emptyState,
  isDraftEmpty,
  loadDraft,
  localToIso,
  saveDraft,
  toLocalInput,
  type ComposeNotifType,
  type ComposeState,
  type ComposeTargetType,
} from './campaigns/lib';
import { adminErrorMessage, Callout, RadioCards } from './campaigns/shared';
import styles from './campaigns/campaigns.module.css';

export default function CampaignComposePage() {
  const i18n = useI18n();
  const { t, formatNumber, formatDateTime } = i18n;
  usePageTitle(t('admin.campaigns.compose.title'));
  const toast = useToast();
  const navigate = useNavigate();
  const qc = useQueryClient();

  const initial = useRef<ComposeState | null>(null);
  if (initial.current === null) initial.current = loadDraft();
  const [state, setState] = useState<ComposeState>(() => initial.current ?? emptyState());
  const [restored, setRestored] = useState(() => !!initial.current && !isDraftEmpty(initial.current));
  const [lang, setLang] = useState<Lang>('tr');
  const [sendOpen, setSendOpen] = useState(false);
  const [sendError, setSendError] = useState<string | null>(null);
  const [resetOpen, setResetOpen] = useState(false);
  const [touched, setTouched] = useState(false);
  const patch = (p: Partial<ComposeState>) => setState((s) => ({ ...s, ...p }));

  // taslak otomatik kaydı (debounce) + sayfadan çıkarken son hali yaz
  const sentRef = useRef(false);
  const latest = useRef(state);
  latest.current = state;
  useEffect(() => {
    const id = setTimeout(() => saveDraft(state), 400);
    return () => clearTimeout(id);
  }, [state]);
  useEffect(
    () => () => {
      if (!sentRef.current) saveDraft(latest.current);
    },
    [],
  );
  // ---- kitle ----
  const aud = audienceFromState(state);
  const departments = useQuery({
    queryKey: ['app', 'departments'],
    queryFn: () => publicApi.get<string[]>('/departments'),
    staleTime: 5 * 60 * 1000,
  });
  const countQ = useQuery({
    queryKey: qk.campaigns.audience(aud.audience?.type ?? 'NONE', aud.audience?.value),
    queryFn: () => countAudience(aud.audience!),
    enabled: !!aud.audience,
    placeholderData: keepPreviousData,
    staleTime: 15_000,
  });
  const count = aud.audience && countQ.data ? countQ.data.count : null;

  const now = new Date();
  const built = buildRequest(state, now, count);

  const send = useMutation({
    mutationFn: () => createCampaign(built.request!),
    onSuccess: () => {
      sentRef.current = true;
      clearDraft();
      void qc.invalidateQueries({ queryKey: qk.campaigns.all });
      toast.success(t(state.scheduleMode === 'later' ? 'admin.campaigns.toast.scheduled' : 'admin.campaigns.toast.created'));
      navigate(paths.admin.campaigns);
    },
    onError: (e) => {
      const msg = adminErrorMessage(i18n, e);
      setSendError(msg);
      toast.error(msg);
    },
  });

  function reset() {
    clearDraft();
    setState(emptyState());
    setRestored(false);
    setLang('tr');
    setTouched(false);
    setResetOpen(false);
  }

  const missing: string[] = [];
  if (aud.error) missing.push(t(`admin.campaigns.missing.${aud.error}`));
  else if (count === 0) missing.push(t('admin.campaigns.missing.NO_RECIPIENTS'));
  else if (count === null) missing.push(t('admin.campaigns.missing.COUNT'));
  if (Object.keys(built.contentErrors).length > 0) missing.push(t('admin.campaigns.missing.CONTENT'));
  if (built.targetError) missing.push(t('admin.campaigns.missing.TARGET'));
  if (built.scheduleError) missing.push(t('admin.campaigns.missing.SCHEDULE'));

  const minLocal = useMemo(() => toLocalInput(new Date(Date.now() + 60_000)), []);
  const maxLocal = useMemo(() => toLocalInput(new Date(Date.now() + MAX_SCHEDULE_DAYS * 86_400_000)), []);

  const audienceOptions = AUDIENCE_TYPES.map((v) => ({
    value: v,
    label: t(`admin.campaigns.audience.${v}`),
    hint: t(`admin.campaigns.audience.${v}.hint`),
    tone: v === 'ALL' ? ('danger' as const) : undefined,
  }));
  const typeOptions = NOTIF_TYPES.map((v) => ({
    value: v,
    label: t(`admin.campaigns.type.${v}`),
    hint: t(`admin.campaigns.type.${v}.hint`),
    tone: v === 'SYSTEM' ? ('danger' as const) : undefined,
  }));

  const targetErrText = built.targetError
    ? t(built.targetError === 'URL_HTTPS' ? 'admin.campaigns.target.err.URL_HTTPS' : 'admin.campaigns.target.err.ID_REQUIRED')
    : null;
  const scheduleErrText =
    state.scheduleMode === 'later' && built.scheduleError && (touched || state.scheduledLocal)
      ? t(`admin.campaigns.schedule.err.${built.scheduleError}`)
      : null;
  const iso = state.scheduleMode === 'later' ? localToIso(state.scheduledLocal) : null;

  return (
    <div>
      <PageHeader
        title={t('admin.campaigns.compose.title')}
       
        breadcrumbs={[{ label: t('admin.campaigns.title'), to: paths.admin.campaigns }, { label: t('admin.campaigns.new') }]}
        actions={
          <Button
            variant="secondary"
            onClick={() => (isDraftEmpty(state) ? reset() : setResetOpen(true))}
            leftIcon={<Icon name="plus" size={16} />}
          >
            {t('admin.campaigns.compose.reset')}
          </Button>
        }
      />
      {restored && (
        <div className={styles.restored}>
          <Callout tone="info" role="status">
            {t('admin.campaigns.compose.restored')}
          </Callout>
        </div>
      )}

      <div className={styles.layout}>
        <div className={styles.formCol}>
          {/* 1. Hedef kitle */}
          <Card title={t('admin.campaigns.compose.audience')}>
            <div className={styles.stack}>
              <RadioCards<AudienceType>
                name="audience"
                legend={t('admin.campaigns.compose.audience')}
                value={state.audienceType}
                options={audienceOptions}
                onChange={(v) => patch({ audienceType: v })}
              />
              {state.audienceType === 'DEPARTMENT' &&
                (departments.data && departments.data.length > 0 ? (
                  <FormField label={t('admin.campaigns.audience.DEPARTMENT')} required>
                    <Select value={state.department} onChange={(e) => patch({ department: e.target.value })}>
                      <option value="">{t('admin.campaigns.audience.pickDepartment')}</option>
                      {departments.data.map((d) => (
                        <option key={d} value={d}>
                          {d}
                        </option>
                      ))}
                    </Select>
                  </FormField>
                ) : (
                  <FormField
                    label={t('admin.campaigns.audience.DEPARTMENT')}
                    hint={t('admin.campaigns.audience.departmentHint')}
                    required
                  >
                    <Input value={state.department} maxLength={120} onChange={(e) => patch({ department: e.target.value })} />
                  </FormField>
                ))}
              {state.audienceType === 'CLASS_YEAR' && (
                <FormField label={t('admin.campaigns.audience.CLASS_YEAR')} required>
                  <Select value={state.classYear} onChange={(e) => patch({ classYear: e.target.value })}>
                    <option value="">{t('admin.campaigns.audience.pickYear')}</option>
                    {[1, 2, 3, 4, 5, 6, 7, 8].map((y) => (
                      <option key={y} value={y}>
                        {t('admin.campaigns.audience.classYearValue', { year: y })}
                      </option>
                    ))}
                  </Select>
                </FormField>
              )}
              {state.audienceType === 'USERS' && (
                <UserPicker value={state.users} onChange={(users) => patch({ users })} />
              )}

              <div
                className={`${styles.counter} ${count === 0 ? styles.counterZero : ''}`}
                role="status"
                aria-live="polite"
                data-testid="audience-count"
              >
                {aud.error ? (
                  <span className={styles.counterHint}>{t(`admin.campaigns.missing.${aud.error}`)}</span>
                ) : count === null ? (
                  <Spinner size="sm" />
                ) : count === 0 ? (
                  <span>
                    <strong>{t('admin.campaigns.count.zero')}</strong>
                    <span className={styles.counterHint}>{t('admin.campaigns.count.zeroHint')}</span>
                  </span>
                ) : (
                  <span>
                    <strong className={styles.bigNumber}>{formatNumber(count)}</strong>{' '}
                    {t('admin.campaigns.count.people')}
                    {countQ.isFetching && <Spinner size="sm" />}
                  </span>
                )}
              </div>
              {countQ.isError && (
                <Callout tone="danger" role="alert">
                  {adminErrorMessage(i18n, countQ.error)}
                </Callout>
              )}
              {state.audienceType === 'ALL' && (
                <Callout tone="warning">{t('admin.campaigns.audience.allWarning')}</Callout>
              )}
            </div>
          </Card>

          {/* 2. İçerik */}
          <Card title={t('admin.campaigns.compose.content')}>
            <ContentEditor
              lang={lang}
              onLangChange={setLang}
              contents={state.contents}
              onChange={(l, c) => patch({ contents: { ...state.contents, [l]: c } })}
              showErrors={touched}
            />
          </Card>

          {/* 3. Tür ve hedef */}
          <Card title={t('admin.campaigns.compose.type')}>
            <div className={styles.stack}>
              <RadioCards<ComposeNotifType>
                name="notif-type"
                legend={t('admin.campaigns.compose.type')}
                value={state.notifType}
                options={typeOptions}
                columns={2}
                onChange={(v) => patch({ notifType: v })}
              />
              {state.notifType === 'SYSTEM' && (
                <Callout tone="danger" role="alert" title={t('admin.campaigns.type.SYSTEM.warnTitle')}>
                  {t('admin.campaigns.type.SYSTEM.warn')}
                </Callout>
              )}
            </div>
          </Card>

          <Card title={t('admin.campaigns.compose.target')}>
            <div className={styles.targetRow}>
              <FormField label={t('admin.campaigns.target.type')}>
                <Select
                  value={state.targetType}
                  onChange={(e) => patch({ targetType: e.target.value as ComposeTargetType, targetValue: '' })}
                >
                  {TARGET_TYPES.map((v) => (
                    <option key={v} value={v}>
                      {t(`admin.campaigns.target.${v}`)}
                    </option>
                  ))}
                </Select>
              </FormField>
              {state.targetType !== 'NONE' && (
                <FormField
                  label={t(state.targetType === 'URL' ? 'admin.campaigns.target.urlLabel' : 'admin.campaigns.target.idLabel')}
                  error={state.targetValue ? targetErrText : null}
                >
                  <Input
                    className="ltr"
                    inputMode={state.targetType === 'URL' ? 'url' : 'numeric'}
                    placeholder={state.targetType === 'URL' ? 'https://' : '123'}
                    value={state.targetValue}
                    maxLength={500}
                    onChange={(e) => patch({ targetValue: e.target.value })}
                  />
                </FormField>
              )}
            </div>
          </Card>

          {/* 4. Zamanlama */}
          <Card title={t('admin.campaigns.compose.schedule')}>
            <div className={styles.stack}>
              <RadioCards<'now' | 'later'>
                name="schedule"
                legend={t('admin.campaigns.compose.schedule')}
                value={state.scheduleMode}
                columns={2}
                options={[
                  { value: 'now', label: t('admin.campaigns.schedule.now'), hint: t('admin.campaigns.schedule.nowHint') },
                  {
                    value: 'later',
                    label: t('admin.campaigns.schedule.later'),
                    hint: t('admin.campaigns.schedule.laterHint', { days: MAX_SCHEDULE_DAYS }),
                  },
                ]}
                onChange={(v) => patch({ scheduleMode: v })}
              />
              {state.scheduleMode === 'later' && (
                <FormField
                  label={t('admin.campaigns.schedule.when')}
                  error={scheduleErrText}
                  hint={iso ? t('admin.campaigns.schedule.utc', { utc: iso }) : undefined}
                >
                  <Input
                    type="datetime-local"
                    className="ltr"
                    min={minLocal}
                    max={maxLocal}
                    value={state.scheduledLocal}
                    onChange={(e) => patch({ scheduledLocal: e.target.value })}
                  />
                </FormField>
              )}
            </div>
          </Card>
        </div>

        {/* Önizleme + gönder */}
        <aside className={styles.sideCol} aria-label={t('admin.campaigns.preview.title')}>
          <div className={styles.sticky}>
            <Card title={t('admin.campaigns.preview.title')}>
              <div className={styles.langSwitch} role="group" aria-label={t('admin.campaigns.preview.lang')}>
                {(['tr', 'en', 'ar'] as Lang[]).map((l) => (
                  <button
                    key={l}
                    type="button"
                    aria-pressed={lang === l}
                    className={`${styles.langBtn} ${lang === l ? styles.langBtnOn : ''}`}
                    onClick={() => setLang(l)}
                  >
                    {l.toUpperCase()}
                  </button>
                ))}
              </div>
              <PhonePreview lang={lang} contents={state.contents} system={state.notifType === 'SYSTEM'} />
            </Card>
            <Card>
              <div className={styles.stack}>
                <p className={styles.sumLine} aria-live="polite">
                  {count !== null && count > 0
                    ? t('admin.campaigns.summary.ready', { n: formatNumber(count) })
                    : t('admin.campaigns.summary.notReady')}
                </p>
                {state.scheduleMode === 'later' && iso && !built.scheduleError && (
                  <p className={styles.muted}>{t('admin.campaigns.summary.at', { when: formatDateTime(iso) })}</p>
                )}
                {missing.length > 0 && touched && (
                  <ul className={styles.missing} aria-label={t('admin.campaigns.summary.missing')}>
                    {missing.map((m) => (
                      <li key={m}>{m}</li>
                    ))}
                  </ul>
                )}
                <Button
                  size="lg"
                  fullWidth
                  variant={state.audienceType === 'ALL' || state.notifType === 'SYSTEM' ? 'accent' : 'primary'}
                  leftIcon={<Icon name="bell" size={18} />}
                  onClick={() => {
                    setTouched(true);
                    if (built.valid) {
                      setSendError(null);
                      setSendOpen(true);
                    }
                  }}
                  disabled={count === 0}
                  data-testid="send-button"
                >
                  {t(state.scheduleMode === 'later' ? 'admin.campaigns.send.schedule' : 'admin.campaigns.send.review')}
                </Button>
              </div>
            </Card>
          </div>
        </aside>
      </div>

      {sendOpen && built.request && count !== null && (
        <SendDialog
          open
          onClose={() => setSendOpen(false)}
          onSend={() => send.mutate()}
          sending={send.isPending}
          error={sendError}
          state={state}
          request={built.request}
          count={count}
        />
      )}
      <ConfirmDialog
        open={resetOpen}
        onClose={() => setResetOpen(false)}
        onConfirm={reset}
        danger
        title={t('admin.campaigns.compose.resetTitle')}
        message={t('admin.campaigns.compose.resetMessage')}
        confirmLabel={t('admin.campaigns.compose.reset')}
      />
    </div>
  );
}
