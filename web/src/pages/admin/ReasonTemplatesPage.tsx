// SAYFA: Karar nedeni şablonları (/admin/moderation/reason-templates)  [P11]
// API: GET/POST /api/admin/moderation/reason-templates, PUT/DELETE .../{id} (api/modAdmin.ts). En çok 50 şablon.
// Panel yalnız Türkçedir; ancak şablon METİNLERİ kullanıcıya gösterilir (rapor kararı bildirimi, alıcının dilinde):
// bu yüzden tr/en/ar üç metin alanı vardır (boş en/ar Türkçeye düşer). Kod oluşturulduktan sonra değişmez.
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { modAdminApi, qk } from '../../api';
import { MAX_REASON_TEMPLATES, type ReasonTemplateRow } from '../../api/modAdmin';
import {
  Badge,
  Button,
  EmptyState,
  ErrorState,
  FormField,
  GuardedAction,
  Icon,
  Input,
  Modal,
  PageHeader,
  StatusPill,
  Switch,
  Table,
  Textarea,
  useToast,
  type Column,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { adminError } from '../../lib/errors';
import { usePageTitle } from '../../lib/hooks';
import {
  EMPTY_TEMPLATE,
  TEMPLATE_TEXT_MAX,
  canAddTemplate,
  templateBody,
  templateErrors,
  type TemplateDraft,
} from './moderation/p11Logic';
import styles from './moderation/p11.module.css';

const listKey = [...qk.moderation.all, 'reasonTemplates'] as const;

function toDraft(r: ReasonTemplateRow): TemplateDraft {
  return {
    code: r.code,
    textTr: r.textTr,
    textEn: r.textEn ?? '',
    textAr: r.textAr ?? '',
    active: r.active,
    sortOrder: String(r.sortOrder),
  };
}

export default function ReasonTemplatesPage() {
  const i18n = useI18n();
  const { t, td } = i18n;
  usePageTitle(t('admin.p11.tpl.title'));
  const toast = useToast();
  const qc = useQueryClient();
  const [editing, setEditing] = useState<ReasonTemplateRow | 'new' | null>(null);
  const [draft, setDraft] = useState<TemplateDraft>(EMPTY_TEMPLATE);
  const [submitted, setSubmitted] = useState(false);

  const query = useQuery({ queryKey: listKey, queryFn: () => modAdminApi.listReasonTemplates() });
  const rows = query.data?.items ?? [];
  const max = query.data?.max ?? MAX_REASON_TEMPLATES;
  const canAdd = canAddTemplate(rows.length, max);
  const isNew = editing === 'new';
  const errors = templateErrors(draft, isNew);
  const valid = Object.keys(errors).length === 0;

  function openNew() {
    setDraft(EMPTY_TEMPLATE);
    setSubmitted(false);
    setEditing('new');
  }
  function openEdit(r: ReasonTemplateRow) {
    setDraft(toDraft(r));
    setSubmitted(false);
    setEditing(r);
  }

  const save = useMutation({
    mutationFn: () => {
      const body = templateBody(draft, isNew);
      return editing && editing !== 'new'
        ? modAdminApi.updateReasonTemplate(editing.id, body)
        : modAdminApi.createReasonTemplate(body);
    },
    onSuccess: () => {
      toast.success(t(isNew ? 'admin.p11.tpl.created' : 'admin.p11.tpl.saved'));
      setEditing(null);
      void qc.invalidateQueries({ queryKey: qk.moderation.all });
      void qc.invalidateQueries({ queryKey: qk.reports.templates() });
    },
    onError: (e) => toast.error(adminError(i18n, e)),
  });

  function submit() {
    setSubmitted(true);
    if (valid) save.mutate();
  }
  const err = (k: keyof typeof errors) => (submitted && errors[k] ? td(errors[k] as string) : null);

  const columns: Column<ReasonTemplateRow>[] = [
    { key: 'code', header: t('admin.p11.tpl.col.code'), render: (r) => <code className="ltr">{r.code}</code> },
    {
      key: 'texts',
      header: t('admin.p11.tpl.col.texts'),
      render: (r) => (
        <span className={styles.cellStack}>
          <span dir="auto">{r.textTr}</span>
          <span className={styles.muted}>
            {t('admin.p11.tpl.langs', {
              en: r.textEn ? t('admin.p11.tpl.has') : t('admin.p11.tpl.fallback'),
              ar: r.textAr ? t('admin.p11.tpl.has') : t('admin.p11.tpl.fallback'),
            })}
          </span>
        </span>
      ),
    },
    {
      key: 'active',
      header: t('admin.p11.tpl.col.active'),
      render: (r) => (
        <StatusPill tone={r.active ? 'success' : 'neutral'}>{t(r.active ? 'admin.p11.tpl.on' : 'admin.p11.tpl.off')}</StatusPill>
      ),
    },
    { key: 'order', header: t('admin.p11.tpl.col.order'), align: 'end', render: (r) => <span className="ltr">{r.sortOrder}</span> },
    {
      key: 'actions',
      header: t('admin.p11.col.actions'),
      align: 'end',
      render: (r) => (
        <span className={styles.actionsRow}>
          <Button size="sm" variant="secondary" onClick={() => openEdit(r)}>
            {t('common.edit')}
          </Button>
          <GuardedAction
            size="sm"
            variant="ghost"
            danger
            irreversible
            requireReason
            title={t('admin.p11.tpl.delete.title')}
            confirmLabel={t('common.delete')}
            message={<strong dir="auto">{r.code}</strong>}
            consequence={t('admin.p11.tpl.delete.consequence')}
            successMessage={t('admin.p11.tpl.deleted')}
            errorMessage={(e) => adminError(i18n, e)}
            invalidateKeys={[qk.moderation.all, qk.reports.templates()]}
            onConfirm={({ reason, idempotencyKey }) => modAdminApi.deleteReasonTemplate(r.id, { reason, idempotencyKey })}
          >
            {t('common.delete')}
          </GuardedAction>
        </span>
      ),
    },
  ];

  return (
    <>
      <PageHeader
        title={t('admin.p11.tpl.title')}
        description={t('admin.p11.tpl.desc')}
        actions={
          <Button leftIcon={<Icon name="plus" size={18} />} onClick={openNew} disabled={!canAdd}>
            {t('admin.p11.tpl.add')}
          </Button>
        }
      />
      <p className={styles.callout}>{t('admin.p11.tpl.userFacing')}</p>
      {query.data && (
        <p className={styles.meta} aria-live="polite">
          {t('admin.p11.tpl.count', { n: rows.length, max })}
          {!canAdd && <Badge tone="warning">{t('admin.p11.tpl.limit')}</Badge>}
        </p>
      )}
      {query.isError ? (
        <ErrorState onRetry={() => void query.refetch()} description={adminError(i18n, query.error)} />
      ) : (
        <Table
          caption={t('admin.p11.tpl.list')}
          columns={columns}
          rows={rows}
          rowKey={(r) => r.id}
          loading={query.isLoading}
          empty={<EmptyState icon="list" title={t('admin.p11.tpl.empty.title')} description={t('admin.p11.tpl.empty.hint')} compact />}
        />
      )}

      <Modal
        open={editing !== null}
        onClose={() => setEditing(null)}
        title={t(isNew ? 'admin.p11.tpl.modal.add' : 'admin.p11.tpl.modal.edit')}
        size="lg"
        footer={
          <>
            <Button variant="secondary" onClick={() => setEditing(null)}>
              {t('common.cancel')}
            </Button>
            <Button onClick={submit} loading={save.isPending}>
              {t('common.save')}
            </Button>
          </>
        }
      >
        <div className={styles.form}>
          <FormField label={t('admin.p11.tpl.field.code')} hint={t('admin.p11.tpl.field.codeHint')} error={err('code')} required>
            <Input
              className="ltr"
              value={draft.code}
              maxLength={32}
              disabled={!isNew}
              onChange={(e) => setDraft({ ...draft, code: e.target.value })}
            />
          </FormField>
          <FormField label={t('admin.p11.tpl.field.textTr')} error={err('textTr')} required>
            <Textarea
              rows={2}
              dir="auto"
              maxLength={TEMPLATE_TEXT_MAX}
              value={draft.textTr}
              onChange={(e) => setDraft({ ...draft, textTr: e.target.value })}
            />
          </FormField>
          <FormField label={t('admin.p11.tpl.field.textEn')} hint={t('admin.p11.tpl.field.fallbackHint')} error={err('textEn')}>
            <Textarea
              rows={2}
              dir="ltr"
              maxLength={TEMPLATE_TEXT_MAX}
              value={draft.textEn}
              onChange={(e) => setDraft({ ...draft, textEn: e.target.value })}
            />
          </FormField>
          <FormField label={t('admin.p11.tpl.field.textAr')} hint={t('admin.p11.tpl.field.fallbackHint')} error={err('textAr')}>
            <Textarea
              rows={2}
              dir="rtl"
              maxLength={TEMPLATE_TEXT_MAX}
              value={draft.textAr}
              onChange={(e) => setDraft({ ...draft, textAr: e.target.value })}
            />
          </FormField>
          <div className={styles.formRow}>
            <FormField label={t('admin.p11.tpl.field.order')} hint={t('admin.p11.tpl.field.orderHint')} error={err('sortOrder')}>
              <Input
                inputMode="numeric"
                className="ltr"
                value={draft.sortOrder}
                onChange={(e) => setDraft({ ...draft, sortOrder: e.target.value })}
              />
            </FormField>
            <Switch checked={draft.active} onChange={(v) => setDraft({ ...draft, active: v })} label={t('admin.p11.tpl.field.active')} />
          </div>
        </div>
      </Modal>
    </>
  );
}
