// SAYFA: SSS yönetimi (/admin/content/faq)
// API: GET /api/admin/faq, POST /api/admin/faq, PUT/DELETE /api/admin/faq/{id} (api/faq.ts). Her dil ayrı kayıt kümesidir (lang).
import { useInfiniteQuery } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { faqApi, qk } from '../../api';
import type { FaqAdminView, Lang } from '../../api/types';
import {
  Badge,
  Button,
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
  useGuardedMutation,
  useUnsavedGuard,
} from '../../components/ui';
import { GuardedDialog } from '../../components/admin/GuardedDialog';
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

  const [lang, setLang] = useState<Lang>('tr');
  const [editing, setEditing] = useState<FaqAdminView | 'new' | null>(null);
  const [form, setFormState] = useState<FormState>(blank);
  const [baseline, setBaseline] = useState<FormState>(blank);
  const setForm = (f: FormState) => setFormState(f);
  const [submitted, setSubmitted] = useState(false);
  const [deleting, setDeleting] = useState<FaqAdminView | null>(null);

  // Sunucu en çok 50 kayıt döner; devam varsa X-Next-Cursor ile sonraki sayfa "Daha fazla yükle" ile alınır.
  const query = useInfiniteQuery({
    queryKey: [...qk.faq.admin(), 'pages'],
    queryFn: ({ pageParam }) => faqApi.listFaqAdminPage(pageParam),
    initialPageParam: undefined as number | undefined,
    getNextPageParam: (last) => last.nextCursor ?? undefined,
  });
  const allItems = useMemo(() => query.data?.pages.flatMap((p) => p.items) ?? [], [query.data]);

  const groups = useMemo(() => {
    const list = allItems
      .filter((f) => f.lang === lang)
      .sort((a, b) => a.sortOrder - b.sortOrder || a.id - b.id);
    const map = new Map<string, FaqAdminView[]>();
    for (const f of list) map.set(f.category, [...(map.get(f.category) ?? []), f]);
    return [...map.entries()].sort(([a], [b]) => a.localeCompare(b, i18n.locale));
  }, [allItems, lang, i18n.locale]);
  const total = groups.reduce((n, [, l]) => n + l.length, 0);
  const categories = useMemo(
    () => [...new Set(allItems.filter((f) => f.lang === lang).map((f) => f.category))],
    [allItems, lang],
  );

  function openNew() {
    setForm(blank);
    setBaseline(blank);
    setSubmitted(false);
    setEditing('new');
  }
  function openEdit(f: FaqAdminView) {
    const next: FormState = {
      category: f.category,
      question: f.question,
      answer: f.answer,
      sortOrder: String(f.sortOrder),
      published: f.published,
    };
    setForm(next);
    setBaseline(next);
    setSubmitted(false);
    setEditing(f);
  }

  const dirty = editing !== null && JSON.stringify(form) !== JSON.stringify(baseline);
  const unsaved = useUnsavedGuard(dirty);
  const closeEditor = () => unsaved.confirmLeave(() => setEditing(null));

  const faqKeys = [qk.faq.all];

  const save = useGuardedMutation<unknown, void>({
    mutationFn: (_v, { idempotencyKey }) => {
      const body = {
        lang,
        category: form.category.trim(),
        question: form.question.trim(),
        answer: form.answer.trim(),
        sortOrder: Number.parseInt(form.sortOrder, 10) || 0,
        published: form.published,
      };
      const o = { idempotencyKey };
      return editing && editing !== 'new'
        ? faqApi.updateFaq(editing.id, { ...body, lang: editing.lang }, o)
        : faqApi.createFaq(body, o);
    },
    successMessage: t('admin.faq.saved'),
    invalidateKeys: faqKeys,
    onSuccess: () => {
      setBaseline(form); // kaydedildi: çıkışta uyarı çıkmasın
      setEditing(null);
    },
  });

  const [togglingId, setTogglingId] = useState<number | null>(null);
  const toggle = useGuardedMutation<unknown, FaqAdminView>({
    mutationFn: (f, { idempotencyKey }) =>
      faqApi.updateFaq(
        f.id,
        {
          lang: f.lang,
          category: f.category,
          question: f.question,
          answer: f.answer,
          sortOrder: f.sortOrder,
          published: !f.published,
        },
        { idempotencyKey },
      ),
    successMessage: false,
    invalidateKeys: faqKeys,
  });
  async function toggleItem(f: FaqAdminView) {
    setTogglingId(f.id);
    try {
      await toggle.run(f);
    } finally {
      setTogglingId(null);
    }
  }

  const req = (v: string) => (submitted && !v.trim() ? t('admin.faq.required') : null);
  const valid = form.category.trim() && form.question.trim() && form.answer.trim();
  function submit() {
    setSubmitted(true);
    if (valid) void save.run();
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
      ) : total === 0 && query.hasNextPage ? null : total === 0 ? (
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
                        loading={togglingId === f.id}
                        onClick={() => void toggleItem(f)}
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

      {query.hasNextPage && !query.isError && (
        <div className={styles.more}>
          <p className={styles.moreHint}>
            {total === 0 ? t('admin.p05.faq.moreOtherLang') : t('admin.p05.faq.moreHint')}
          </p>
          <Button variant="secondary" loading={query.isFetchingNextPage} onClick={() => void query.fetchNextPage()}>
            {t('admin.p05.faq.loadMore')}
          </Button>
        </div>
      )}
      {unsaved.dialog}

      <Modal
        open={editing !== null}
        onClose={closeEditor}
        title={editing === 'new' ? t('admin.faq.modal.add') : t('admin.faq.modal.edit')}
        size="lg"
        footer={
          <>
            <Button variant="secondary" onClick={closeEditor}>
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

      <GuardedDialog
        open={!!deleting}
        onClose={() => setDeleting(null)}
        danger
        irreversible
        title={t('admin.faq.delete.title')}
        message={<strong dir="auto">{deleting?.question}</strong>}
        confirmLabel={t('common.delete')}
        successMessage={t('admin.faq.deleted')}
        invalidateKeys={faqKeys}
        onConfirm={({ idempotencyKey }) => faqApi.deleteFaq(deleting!.id, { idempotencyKey })}
      />
    </>
  );
}
