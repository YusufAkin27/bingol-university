// SAYFA: SSS yönetimi (/admin/content/faq)
// API: GET /api/admin/faq, POST /api/admin/faq, PUT/DELETE /api/admin/faq/{id} (api/faq.ts). Her dil ayrı kayıt kümesidir (lang).
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { faqApi, qk } from '../../api';
import type { FaqAdminView, Lang } from '../../api/types';
import {
  Badge,
  Button,
  ConfirmDialog,
  EmptyState,
  ErrorState,
  FormField,
  Icon,
  IconButton,
  Input,
  Modal,
  PageHeader,
  Skeleton,
  Switch,
  Tabs,
  Textarea,
  useToast,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { errorMessage } from '../../lib/errors';
import { usePageTitle } from '../../lib/hooks';
import styles from './content/Faq.module.css';

const LANGS: Lang[] = ['tr', 'en', 'ar'];

interface FormState {
  category: string;
  question: string;
  answer: string;
  sortOrder: string;
  published: boolean;
}
const blank: FormState = { category: '', question: '', answer: '', sortOrder: '0', published: true };

export default function FaqAdminPage() {
  const i18n = useI18n();
  const { t } = i18n;
  usePageTitle(t('admin.faq.title'));
  const toast = useToast();
  const qc = useQueryClient();

  const [lang, setLang] = useState<Lang>('tr');
  const [editing, setEditing] = useState<FaqAdminView | 'new' | null>(null);
  const [form, setForm] = useState<FormState>(blank);
  const [submitted, setSubmitted] = useState(false);
  const [deleting, setDeleting] = useState<FaqAdminView | null>(null);

  const query = useQuery({ queryKey: qk.faq.admin(), queryFn: faqApi.listFaqAdmin });

  const groups = useMemo(() => {
    const list = (query.data ?? [])
      .filter((f) => f.lang === lang)
      .sort((a, b) => a.sortOrder - b.sortOrder || a.id - b.id);
    const map = new Map<string, FaqAdminView[]>();
    for (const f of list) map.set(f.category, [...(map.get(f.category) ?? []), f]);
    return [...map.entries()].sort(([a], [b]) => a.localeCompare(b, i18n.locale));
  }, [query.data, lang, i18n.locale]);
  const total = groups.reduce((n, [, l]) => n + l.length, 0);
  const categories = useMemo(
    () => [...new Set((query.data ?? []).filter((f) => f.lang === lang).map((f) => f.category))],
    [query.data, lang],
  );

  function openNew() {
    setForm(blank);
    setSubmitted(false);
    setEditing('new');
  }
  function openEdit(f: FaqAdminView) {
    setForm({
      category: f.category,
      question: f.question,
      answer: f.answer,
      sortOrder: String(f.sortOrder),
      published: f.published,
    });
    setSubmitted(false);
    setEditing(f);
  }

  const done = () => void qc.invalidateQueries({ queryKey: qk.faq.all });

  const save = useMutation({
    mutationFn: () => {
      const body = {
        lang,
        category: form.category.trim(),
        question: form.question.trim(),
        answer: form.answer.trim(),
        sortOrder: Number.parseInt(form.sortOrder, 10) || 0,
        published: form.published,
      };
      return editing && editing !== 'new' ? faqApi.updateFaq(editing.id, { ...body, lang: editing.lang }) : faqApi.createFaq(body);
    },
    onSuccess: () => {
      toast.success(t('admin.faq.saved'));
      setEditing(null);
      done();
    },
    onError: (e) => toast.error(errorMessage(i18n, e)),
  });

  const toggle = useMutation({
    mutationFn: (f: FaqAdminView) =>
      faqApi.updateFaq(f.id, {
        lang: f.lang,
        category: f.category,
        question: f.question,
        answer: f.answer,
        sortOrder: f.sortOrder,
        published: !f.published,
      }),
    onSuccess: done,
    onError: (e) => toast.error(errorMessage(i18n, e)),
  });

  const remove = useMutation({
    mutationFn: (f: FaqAdminView) => faqApi.deleteFaq(f.id),
    onSuccess: () => {
      toast.success(t('admin.faq.deleted'));
      setDeleting(null);
      done();
    },
    onError: (e) => {
      toast.error(errorMessage(i18n, e));
      setDeleting(null);
    },
  });

  const req = (v: string) => (submitted && !v.trim() ? t('admin.faq.required') : null);
  const valid = form.category.trim() && form.question.trim() && form.answer.trim();
  function submit() {
    setSubmitted(true);
    if (valid) save.mutate();
  }
  const formLang = editing && editing !== 'new' ? editing.lang : lang;

  return (
    <>
      <PageHeader
        title={t('admin.faq.title')}
       
        actions={
          <Button leftIcon={<Icon name="plus" size={18} />} onClick={openNew}>
            {t('admin.faq.add')}
          </Button>
        }
      />
      <Tabs
        label={t('admin.faq.langs')}
        value={lang}
        onChange={(id) => setLang(id as Lang)}
        tabs={LANGS.map((l) => ({ id: l, label: t(`admin.legal.lang.${l}`) }))}
      />

      {query.isError ? (
        <ErrorState onRetry={() => void query.refetch()} description={errorMessage(i18n, query.error)} />
      ) : query.isLoading ? (
        <div className={styles.groups}>
          <Skeleton height="5rem" radius="var(--radius-md)" />
          <Skeleton height="5rem" radius="var(--radius-md)" />
        </div>
      ) : total === 0 ? (
        <EmptyState
          icon="help"
          title={t('admin.faq.empty.title')}
          description={t('admin.faq.empty.hint')}
          action={<Button onClick={openNew}>{t('admin.faq.add')}</Button>}
        />
      ) : (
        <div className={styles.groups} dir={lang === 'ar' ? 'rtl' : 'ltr'}>
          {groups.map(([cat, list]) => (
            <section key={cat} className={styles.group} aria-label={cat}>
              <h2 className={styles.groupTitle}>
                <span dir="auto">{cat}</span>
                <span className={styles.count}>{t('admin.faq.count', { n: list.length })}</span>
              </h2>
              <ul className={styles.items}>
                {list.map((f) => (
                  <li key={f.id} className={`${styles.item} ${f.published ? '' : styles.draft}`}>
                    <div className={styles.itemMain}>
                      <p className={styles.q} dir="auto">
                        {f.question}
                      </p>
                      <p className={styles.a} dir="auto">
                        {f.answer}
                      </p>
                      <div className={styles.itemMeta}>
                        <Badge tone={f.published ? 'success' : 'neutral'}>
                          {f.published ? t('admin.faq.published') : t('admin.faq.draft')}
                        </Badge>
                        <span>{t('admin.faq.order', { n: f.sortOrder })}</span>
                      </div>
                    </div>
                    <div className={styles.itemActions} dir={i18n.dir}>
                      <Button
                        size="sm"
                        variant="ghost"
                        loading={toggle.isPending && toggle.variables?.id === f.id}
                        onClick={() => toggle.mutate(f)}
                      >
                        {f.published ? t('admin.faq.toggleDraft') : t('admin.faq.togglePublish')}
                      </Button>
                      <Button size="sm" variant="secondary" onClick={() => openEdit(f)}>
                        {t('common.edit')}
                      </Button>
                      <IconButton label={t('common.delete')} size="sm" onClick={() => setDeleting(f)}>
                        <Icon name="x" size={16} />
                      </IconButton>
                    </div>
                  </li>
                ))}
              </ul>
            </section>
          ))}
        </div>
      )}

      <Modal
        open={editing !== null}
        onClose={() => setEditing(null)}
        title={editing === 'new' ? t('admin.faq.modal.add') : t('admin.faq.modal.edit')}
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
        <div className={styles.form} dir={formLang === 'ar' ? 'rtl' : 'ltr'}>
          <FormField
            label={t('admin.faq.field.category')}
            required
            error={req(form.category)}
          >
            <Input
              list="faq-categories"
              maxLength={40}
              value={form.category}
              onChange={(e) => setForm({ ...form, category: e.target.value })}
            />
          </FormField>
          <datalist id="faq-categories">
            {categories.map((c) => (
              <option key={c} value={c} />
            ))}
          </datalist>
          <FormField label={t('admin.faq.field.question')} required error={req(form.question)}>
            <Input
              maxLength={300}
              value={form.question}
              onChange={(e) => setForm({ ...form, question: e.target.value })}
            />
          </FormField>
          <FormField label={t('admin.faq.field.answer')} required error={req(form.answer)}>
            <Textarea
              rows={6}
              maxLength={2000}
              value={form.answer}
              onChange={(e) => setForm({ ...form, answer: e.target.value })}
            />
          </FormField>
          <div className={styles.formRow}>
            <FormField label={t('admin.faq.field.order')}>
              <Input
                type="number"
                inputMode="numeric"
                value={form.sortOrder}
                onChange={(e) => setForm({ ...form, sortOrder: e.target.value })}
              />
            </FormField>
            <Switch
              checked={form.published}
              onChange={(v) => setForm({ ...form, published: v })}
              label={t('admin.faq.field.published')}
            />
          </div>
        </div>
      </Modal>

      <ConfirmDialog
        open={!!deleting}
        onClose={() => setDeleting(null)}
        onConfirm={() => deleting && remove.mutate(deleting)}
        loading={remove.isPending}
        danger
        title={t('admin.faq.delete.title')}
        message={
          <>
            <strong dir="auto">{deleting?.question}</strong>
            <br />
            {t('admin.faq.delete.body')}
          </>
        }
        confirmLabel={t('common.delete')}
      />
    </>
  );
}
