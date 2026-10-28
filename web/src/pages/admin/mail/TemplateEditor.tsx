import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useEffect, useMemo, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  MAIL_LANGS,
  archiveTemplate,
  createTemplate,
  deleteTemplate,
  getMailVariables,
  getTemplate,
  listTemplateVersions,
  mailKeys,
  publishTemplate,
  sendTestMail,
  updateTemplate,
  type MailLang,
  type TemplateView,
} from '../../../api/adminMail';
import {
  Button,
  Card,
  ConfirmDialog,
  ErrorState,
  FormField,
  Icon,
  Input,
  Modal,
  PageHeader,
  Select,
  Skeleton,
  Tabs,
  Textarea,
  useToast,
} from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { usePageTitle } from '../../../lib/hooks';
import { paths } from '../../../paths';
import { Callout } from '../campaigns/shared';
import { LangBadges, TemplateStatusPill } from './MailParts';
import { TemplatePreview } from './TemplatePreview';
import {
  MAX_HTML,
  MAX_SUBJECT,
  emptyForm,
  formFromView,
  hasErrors,
  insertAt,
  isLangEmpty,
  mailErrorMessage,
  toRequest,
  validateForm,
  type LangForm,
  type TemplateForm,
} from './mailLogic';
import styles from './mail.module.css';

type Field = 'subject' | 'html' | 'text';

export function TemplateEditor({ id }: { id: number | null }) {
  const i18n = useI18n();
  const { t, formatDateTime, formatNumber } = i18n;
  const toast = useToast();
  const navigate = useNavigate();
  const qc = useQueryClient();
  usePageTitle(t(id ? 'admin.mail.editor.titleEdit' : 'admin.mail.editor.titleNew'));

  const tpl = useQuery({ queryKey: mailKeys.template(id ?? 0), queryFn: () => getTemplate(id as number), enabled: id !== null });
  const vars = useQuery({ queryKey: mailKeys.variables(), queryFn: getMailVariables, staleTime: 600_000 });
  const versions = useQuery({
    queryKey: mailKeys.versions(id ?? 0),
    queryFn: () => listTemplateVersions(id as number),
    enabled: id !== null,
  });

  const [form, setForm] = useState<TemplateForm>(emptyForm);
  const [baseline, setBaseline] = useState<string>(JSON.stringify(emptyForm()));
  const [lang, setLang] = useState<MailLang>('tr');
  const [target, setTarget] = useState<Field>('html');
  const [showErrors, setShowErrors] = useState(false);
  const [serverError, setServerError] = useState<string | null>(null);
  const [confirm, setConfirm] = useState<null | 'publish' | 'archive' | 'delete'>(null);
  const [testLang, setTestLang] = useState<MailLang>('tr');
  const [versionsOpen, setVersionsOpen] = useState(false);
  const [previewVersion, setPreviewVersion] = useState<number | null>(null);

  const refs = {
    subject: useRef<HTMLInputElement>(null),
    html: useRef<HTMLTextAreaElement>(null),
    text: useRef<HTMLTextAreaElement>(null),
  };

  function load(v: TemplateView) {
    const f = formFromView(v);
    setForm(f);
    setBaseline(JSON.stringify(f));
  }
  useEffect(() => {
    if (tpl.data) load(tpl.data);
  }, [tpl.data]);

  const view = tpl.data ?? null;
  const status = view?.status ?? 'DRAFT';
  const archived = status === 'ARCHIVED';
  const dirty = JSON.stringify(form) !== baseline;
  const errors = useMemo(() => validateForm(form), [form]);

  function setLangField(l: MailLang, field: keyof LangForm, value: string) {
    setForm((f) => ({ ...f, [l]: { ...f[l], [field]: value } }));
  }

  function insertVar(placeholder: string) {
    const el = refs[target].current;
    const cur = form[lang][target];
    const { value, caret } = insertAt(cur, el?.selectionStart ?? cur.length, el?.selectionEnd ?? cur.length, placeholder);
    setLangField(lang, target, value);
    requestAnimationFrame(() => {
      el?.focus();
      el?.setSelectionRange(caret, caret);
    });
  }

  const onDone = (v: TemplateView) => {
    qc.setQueryData(mailKeys.template(v.id), v);
    void qc.invalidateQueries({ queryKey: ['adminMail', 'templates'] });
    void qc.invalidateQueries({ queryKey: mailKeys.versions(v.id) });
    load(v);
    setServerError(null);
  };
  const onError = (e: unknown) => {
    const msg = mailErrorMessage(i18n, e);
    setServerError(msg);
    toast.error(msg);
    setConfirm(null);
  };

  const save = useMutation({
    mutationFn: () => (id === null ? createTemplate(toRequest(form)) : updateTemplate(id, toRequest(form))),
    onSuccess: (v) => {
      onDone(v);
      toast.success(t('admin.mail.editor.saved'));
      if (id === null) navigate(`${paths.admin.mailTemplates}/${v.id}`, { replace: true });
    },
    onError,
  });
  const publish = useMutation({
    mutationFn: () => publishTemplate(id as number),
    onSuccess: (v) => {
      onDone(v);
      setConfirm(null);
      toast.success(t('admin.mail.editor.published'));
    },
    onError,
  });
  const archive = useMutation({
    mutationFn: () => archiveTemplate(id as number),
    onSuccess: (v) => {
      onDone(v);
      setConfirm(null);
      toast.success(t('admin.mail.editor.archivedOk'));
    },
    onError,
  });
  const remove = useMutation({
    mutationFn: () => deleteTemplate(id as number),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ['adminMail', 'templates'] });
      toast.success(t('admin.mail.editor.deleted'));
      navigate(paths.admin.mailTemplates);
    },
    onError,
  });
  const test = useMutation({
    mutationFn: () => sendTestMail(id as number, testLang),
    onSuccess: (r) => toast.success(t('admin.mail.editor.testSent', { to: r.to })),
    onError: (e) => toast.error(mailErrorMessage(i18n, e)),
  });

  function submit() {
    setShowErrors(true);
    if (hasErrors(errors)) {
      // hatalı ilk dili göster
      const first = MAIL_LANGS.find((l) => errors.lang[l]);
      if (first) setLang(first);
      return;
    }
    save.mutate();
  }

  if (id !== null && tpl.isLoading) return <Skeleton height={320} />;
  if (id !== null && tpl.isError)
    return <ErrorState description={mailErrorMessage(i18n, tpl.error)} onRetry={() => void tpl.refetch()} />;

  const le = errors.lang[lang];
  const msgFor = (c: 'required' | 'tooLong' | undefined, max: number) =>
    !showErrors || !c
      ? null
      : c === 'required'
        ? t('admin.mail.err.required')
        : t('admin.mail.err.tooLong', { max: formatNumber(max) });
  const emptyOther = (l: MailLang) => l !== 'tr' && isLangEmpty(form[l]);
  const missing = (['en', 'ar'] as MailLang[]).filter(emptyOther);
  const cur = form[lang];
  const rtl = lang === 'ar';

  const tabs = MAIL_LANGS.map((l) => ({
    id: l,
    label: (
      <span>
        {t(`admin.mail.langName.${l}`)}
        {errors.lang[l] && showErrors ? ` ⚠` : ''}
        {emptyOther(l) ? ` (${t('admin.mail.editor.empty')})` : ''}
      </span>
    ),
  }));

  return (
    <div>
      <PageHeader
        title={t(id ? 'admin.mail.editor.titleEdit' : 'admin.mail.editor.titleNew')}
        breadcrumbs={[{ label: t('admin.mail.templates.title'), to: paths.admin.mailTemplates }, { label: view?.name ?? t('admin.mail.editor.titleNew') }]}
        actions={
          <div className={styles.row}>
            {view && <TemplateStatusPill status={view.status} />}
            {view && (
              <span className={styles.muted}>
                {t('admin.mail.editor.version', { v: view.version })}
              </span>
            )}
            {view && <LangBadges languages={view.languages} />}
          </div>
        }
      />

      {archived && (
        <Callout tone="warning" role="status" title={t('admin.mail.editor.archivedTitle')}>
          {t('admin.mail.editor.archivedHint')}
        </Callout>
      )}
      {serverError && (
        <div role="alert" style={{ marginBlock: 'var(--space-3)' }}>
          <Callout tone="danger">{serverError}</Callout>
        </div>
      )}

      <div className={styles.stack}>
        <Card>
          <div className={styles.grid2}>
            <FormField label={t('admin.mail.editor.name')} required error={showErrors && errors.name ? t('admin.mail.err.required') : null}>
              <Input
                value={form.name}
                maxLength={120}
                disabled={archived}
                onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
              />
            </FormField>
            <FormField label={t('admin.mail.editor.description')}>
              <Input
                value={form.description}
                maxLength={300}
                onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))}
              />
            </FormField>
          </div>
        </Card>

        <Tabs tabs={tabs} value={lang} onChange={(v) => setLang(v as MailLang)} label={t('admin.mail.editor.langTabs')}>
          <div className={styles.editorGrid}>
            <div className={styles.stack}>
              {emptyOther(lang) && (
                <Callout tone="info" role="status">
                  {t('admin.mail.editor.fallbackInfo')}
                </Callout>
              )}
              <FormField
                label={t('admin.mail.editor.subject')}
                required={lang === 'tr'}
                error={msgFor(le?.subject, MAX_SUBJECT)}
                hint={t('admin.mail.editor.counter', { n: formatNumber(cur.subject.length), max: formatNumber(MAX_SUBJECT) })}
              >
                <Input
                  ref={refs.subject}
                  value={cur.subject}
                  dir={rtl ? 'rtl' : undefined}
                  disabled={archived}
                  onFocus={() => setTarget('subject')}
                  onChange={(e) => setLangField(lang, 'subject', e.target.value)}
                />
              </FormField>

              <div>
                <p className={styles.muted} id="mail-vars-label">
                  {t('admin.mail.editor.insertVar', { field: t(`admin.mail.editor.field.${target}`) })}
                </p>
                <div className={styles.varRow} role="group" aria-labelledby="mail-vars-label">
                  {(vars.data?.variables ?? []).map((v) => (
                    <button
                      key={v.name}
                      type="button"
                      className={styles.varBtn}
                      title={v.description}
                      disabled={archived}
                      onClick={() => insertVar(v.placeholder)}
                    >
                      {v.placeholder}
                    </button>
                  ))}
                  {vars.isLoading && <span className={styles.muted}>{t('common.loading')}</span>}
                </div>
              </div>

              <FormField
                label={t('admin.mail.editor.html')}
                required={lang === 'tr'}
                error={msgFor(le?.html, MAX_HTML)}
                hint={t('admin.mail.editor.counter', { n: formatNumber(cur.html.length), max: formatNumber(MAX_HTML) })}
              >
                <Textarea
                  ref={refs.html}
                  className={styles.code}
                  value={cur.html}
                  rows={14}
                  spellCheck={false}
                  disabled={archived}
                  onFocus={() => setTarget('html')}
                  onChange={(e) => setLangField(lang, 'html', e.target.value)}
                />
              </FormField>
              <p className={styles.muted}>{t('admin.mail.editor.htmlHint')}</p>

              <FormField label={t('admin.mail.editor.text')} hint={t('admin.mail.editor.textHint')}>
                <Textarea
                  ref={refs.text}
                  className={`${styles.code} ${styles.textarea}`}
                  value={cur.text}
                  rows={5}
                  disabled={archived}
                  onFocus={() => setTarget('text')}
                  onChange={(e) => setLangField(lang, 'text', e.target.value)}
                />
              </FormField>
            </div>

            <div className={styles.stack}>
              <h2 className={styles.previewSubject}>{t('admin.mail.preview.title')}</h2>
              <TemplatePreview
                lang={lang}
                source={{
                  kind: 'draft',
                  content: isLangEmpty(cur) && lang !== 'tr' ? toContentOf(form.tr) : toContentOf(cur),
                }}
              />
            </div>
          </div>
        </Tabs>

        {missing.length > 0 && (
          <Callout tone="warning" role="status">
            {t('admin.mail.editor.fallbackSummary', { langs: missing.map((l) => l.toUpperCase()).join(', ') })}
          </Callout>
        )}

        <div className={styles.footer}>
          <div className={styles.row}>
            <Button onClick={submit} loading={save.isPending} disabled={archived || (id !== null && !dirty)} leftIcon={<Icon name="check" size={18} />}>
              {t(id ? 'admin.mail.editor.save' : 'admin.mail.editor.create')}
            </Button>
            {id !== null && !archived && (
              <Button variant="accent" onClick={() => setConfirm('publish')} disabled={dirty || status === 'PUBLISHED'}>
                {t('admin.mail.editor.publish')}
              </Button>
            )}
            {id !== null && status !== 'ARCHIVED' && (
              <Button variant="secondary" onClick={() => setConfirm('archive')}>
                {t('admin.mail.editor.archive')}
              </Button>
            )}
            {id !== null && status === 'ARCHIVED' && (
              <Button variant="secondary" onClick={() => setConfirm('publish')} disabled={dirty}>
                {t('admin.mail.editor.republish')}
              </Button>
            )}
            {dirty && id !== null && <span className={styles.muted}>{t('admin.mail.editor.dirty')}</span>}
          </div>
          {id !== null && (
            <div className={styles.row}>
              <Select
                aria-label={t('admin.mail.editor.testLang')}
                value={testLang}
                onChange={(e) => setTestLang(e.target.value as MailLang)}
              >
                {MAIL_LANGS.map((l) => (
                  <option key={l} value={l}>
                    {t(`admin.mail.langName.${l}`)}
                  </option>
                ))}
              </Select>
              <Button variant="secondary" onClick={() => test.mutate()} loading={test.isPending} disabled={dirty} leftIcon={<Icon name="mail" size={18} />}>
                {t('admin.mail.editor.test')}
              </Button>
              <Button variant="ghost" onClick={() => setVersionsOpen(true)}>
                {t('admin.mail.editor.versions')}
              </Button>
              <Button variant="danger" onClick={() => setConfirm('delete')}>
                {t('common.delete')}
              </Button>
            </div>
          )}
        </div>
        {id !== null && <p className={styles.muted}>{t('admin.mail.editor.testHint')}</p>}
      </div>

      <ConfirmDialog
        open={confirm === 'publish'}
        onClose={() => setConfirm(null)}
        onConfirm={() => publish.mutate()}
        loading={publish.isPending}
        title={t('admin.mail.editor.publishTitle')}
        message={t('admin.mail.editor.publishMsg')}
        confirmLabel={t('admin.mail.editor.publish')}
      />
      <ConfirmDialog
        open={confirm === 'archive'}
        onClose={() => setConfirm(null)}
        onConfirm={() => archive.mutate()}
        loading={archive.isPending}
        title={t('admin.mail.editor.archiveTitle')}
        message={t('admin.mail.editor.archiveMsg')}
        confirmLabel={t('admin.mail.editor.archive')}
      />
      <ConfirmDialog
        open={confirm === 'delete'}
        onClose={() => setConfirm(null)}
        onConfirm={() => remove.mutate()}
        loading={remove.isPending}
        danger
        title={t('admin.mail.editor.deleteTitle')}
        message={t('admin.mail.editor.deleteMsg')}
        confirmLabel={t('common.delete')}
      />

      <Modal
        open={versionsOpen}
        onClose={() => {
          setVersionsOpen(false);
          setPreviewVersion(null);
        }}
        title={t('admin.mail.editor.versions')}
        size="lg"
      >
        {versions.isLoading && <Skeleton height={80} />}
        {versions.isError && <ErrorState compact description={mailErrorMessage(i18n, versions.error)} />}
        {versions.data && (
          <ul className={styles.kv}>
            {versions.data.map((v) => (
              <li key={v.version}>
                <span>
                  {t('admin.mail.editor.version', { v: v.version })} · {formatDateTime(v.createdAt)}
                </span>
                <Button size="sm" variant="ghost" onClick={() => setPreviewVersion(v.version)}>
                  {t('admin.mail.editor.previewVersion')}
                </Button>
              </li>
            ))}
          </ul>
        )}
        {previewVersion !== null && id !== null && (
          <div style={{ marginBlockStart: 'var(--space-4)' }}>
            <TemplatePreview lang={lang} source={{ kind: 'saved', id, version: previewVersion }} />
          </div>
        )}
      </Modal>
    </div>
  );
}

function toContentOf(c: LangForm) {
  return { subject: c.subject.trim(), html: c.html, text: c.text.trim() ? c.text : null };
}
