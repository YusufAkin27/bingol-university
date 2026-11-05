// SAYFA: Forum kategorileri (/admin/forum/categories)
// API: GET|POST|PATCH|DELETE /api/admin/forum/categories (DELETE = arşivle, active=false), POST .../reorder {ids} (api/adminForum.ts).
// Okuma herkese açık değil: `forum.categories` izni gerekir; izinsiz profil sayfayı açamaz. Arşivlenen kategoride konular silinmez.
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import {
  archiveCategory,
  createCategory,
  forumKeys,
  listCategories,
  reorderCategories,
  updateCategory,
  type ForumCategory,
} from '../../../api/adminForum';
import {
  Badge,
  Button,
  Card,
  Checkbox,
  ConfirmDialog,
  EmptyState,
  ErrorState,
  FormField,
  Input,
  PageHeader,
  Skeleton,
  useToast,
} from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { usePageTitle } from '../../../lib/hooks';
import { useSearchReveal } from '../../../search/anchor';
import styles from '../moderation/moderation.module.css';
import { useForumCan } from './shared';
import { forumError, tf } from './tf';

const SLUG_RE = /^[a-z0-9]+(-[a-z0-9]+)*$/; // sunucu ile aynı kural (en çok 60 karakter)

interface FormState {
  slug: string;
  nameTr: string;
  nameEn: string;
  nameAr: string;
  active: boolean;
}
const EMPTY: FormState = { slug: '', nameTr: '', nameEn: '', nameAr: '', active: true };

export default function ForumCategoriesPage() {
  const i18n = useI18n();
  const { formatNumber } = i18n;
  const f = tf(i18n);
  usePageTitle(f('admin.forum.cat.title'));
  const toast = useToast();
  const qc = useQueryClient();
  const canEdit = useForumCan('forum.categories');
  const [editing, setEditing] = useState<ForumCategory | 'new' | null>(null);
  const [form, setForm] = useState<FormState>(EMPTY);
  const [touched, setTouched] = useState(false);
  const [archiving, setArchiving] = useState<ForumCategory | null>(null);

  const list = useQuery({ queryKey: forumKeys.categories(), queryFn: listCategories });
  const items = list.data ?? [];
  const refresh = () => void qc.invalidateQueries({ queryKey: forumKeys.all });
  const fail = (e: unknown) => toast.error(forumError(i18n, e));

  const open = (c: ForumCategory | 'new') => {
    setEditing(c);
    setTouched(false);
    setForm(
      c === 'new'
        ? EMPTY
        : { slug: c.slug, nameTr: c.nameTr, nameEn: c.nameEn, nameAr: c.nameAr, active: c.active },
    );
  };
  const close = () => setEditing(null);

  const save = useMutation({
    mutationFn: () => {
      // boş EN/AR adı gönderilmez: oluştururken sunucu Türkçe ada düşer, güncellerken mevcut çeviri kalır
      const names = {
        nameTr: form.nameTr.trim(),
        nameEn: form.nameEn.trim() || undefined,
        nameAr: form.nameAr.trim() || undefined,
        active: form.active,
      };
      if (editing === 'new') return createCategory({ ...names, slug: form.slug.trim() || undefined });
      return updateCategory((editing as ForumCategory).id, names);
    },
    onSuccess: () => {
      toast.success(f(editing === 'new' ? 'admin.forum.cat.toast.created' : 'admin.forum.cat.toast.saved'));
      close();
      refresh();
    },
    onError: fail,
  });
  const archive = useMutation({
    mutationFn: (c: ForumCategory) => archiveCategory(c.id),
    onSuccess: () => {
      toast.success(f('admin.forum.cat.toast.archived'));
      setArchiving(null);
      refresh();
    },
    onError: (e) => {
      fail(e);
      setArchiving(null);
      refresh();
    },
  });
  const restore = useMutation({
    mutationFn: (c: ForumCategory) => updateCategory(c.id, { active: true }),
    onSuccess: () => {
      toast.success(f('admin.forum.cat.toast.restored'));
      refresh();
    },
    onError: fail,
  });
  const reorder = useMutation({
    mutationFn: (ids: number[]) => reorderCategories(ids),
    onSuccess: refresh,
    onError: (e) => {
      fail(e);
      refresh();
    },
  });

  const move = (index: number, delta: -1 | 1) => {
    const ids = items.map((c) => c.id);
    const j = index + delta;
    if (j < 0 || j >= ids.length) return;
    [ids[index], ids[j]] = [ids[j]!, ids[index]!];
    reorder.mutate(ids);
  };

  // Arama: form alanları yalnız form açıkken çizilir; "yeni kategori" formunu açtır
  useSearchReveal((anchor) => {
    if (['fcat-form', 'fcat-names'].includes(anchor) && canEdit && !editing) open('new');
  });

  const nameInvalid = form.nameTr.trim().length === 0;
  const slugInvalid =
    editing === 'new' && form.slug.trim() !== '' && (form.slug.trim().length > 60 || !SLUG_RE.test(form.slug.trim()));

  return (
    <>
      <PageHeader
        title={f('admin.forum.cat.title')}
        description={f('admin.forum.cat.intro')}
        actions={
          canEdit ? (
            <Button data-search-anchor="fcat-add" onClick={() => open('new')} disabled={!!editing}>
              {f('admin.forum.cat.add')}
            </Button>
          ) : undefined
        }
      />
      <div className={styles.stack}>
        {!canEdit && (
          <p className={styles.muted} role="status">
            {f('admin.forum.readOnly')}
          </p>
        )}

        {editing && canEdit && (
          <Card title={f(editing === 'new' ? 'admin.forum.cat.form.new' : 'admin.forum.cat.form.edit')}>
            <form
              noValidate
              className={styles.formGrid}
              data-search-anchor="fcat-form"
              onSubmit={(e) => {
                e.preventDefault();
                setTouched(true);
                if (!nameInvalid && !slugInvalid) save.mutate();
              }}
            >
              <FormField
                label={f('admin.forum.cat.field.nameTr')}
                error={touched && nameInvalid ? f('admin.forum.cat.field.nameRequired') : null}
                required
              >
                <Input
                  data-search-anchor="fcat-names"
                  value={form.nameTr}
                  maxLength={80}
                  onChange={(e) => setForm({ ...form, nameTr: e.target.value })}
                />
              </FormField>
              <FormField label={f('admin.forum.cat.field.nameEn')} hint={f('admin.forum.cat.field.nameFallback')}>
                <Input value={form.nameEn} maxLength={80} dir="ltr" onChange={(e) => setForm({ ...form, nameEn: e.target.value })} />
              </FormField>
              <FormField label={f('admin.forum.cat.field.nameAr')} hint={f('admin.forum.cat.field.nameFallback')}>
                <Input value={form.nameAr} maxLength={80} dir="rtl" onChange={(e) => setForm({ ...form, nameAr: e.target.value })} />
              </FormField>
              <FormField
                label={f('admin.forum.cat.field.slug')}
                hint={f(editing === 'new' ? 'admin.forum.cat.field.slugHint' : 'admin.forum.cat.field.slugLocked')}
                error={touched && slugInvalid ? f('admin.forum.cat.field.slugInvalid') : null}
              >
                <Input
                  value={form.slug}
                  maxLength={60}
                  dir="ltr"
                  autoComplete="off"
                  disabled={editing !== 'new'}
                  onChange={(e) => setForm({ ...form, slug: e.target.value })}
                />
              </FormField>
              <div className={styles.wide}>
                <Checkbox
                  label={f('admin.forum.cat.field.active')}
                  checked={form.active}
                  onChange={(e) => setForm({ ...form, active: e.target.checked })}
                />
              </div>
              <div className={styles.actions}>
                <Button type="submit" loading={save.isPending}>
                  {f('admin.forum.save')}
                </Button>
                <Button type="button" variant="secondary" onClick={close}>
                  {f('admin.forum.cancel')}
                </Button>
              </div>
            </form>
          </Card>
        )}

        {list.isError ? (
          <ErrorState description={forumError(i18n, list.error)} onRetry={() => void list.refetch()} />
        ) : list.isLoading ? (
          <Skeleton height="5rem" width="100%" />
        ) : items.length === 0 ? (
          <EmptyState icon="list" title={f('admin.forum.cat.empty.title')} description={f('admin.forum.cat.empty.hint')} />
        ) : (
          <ul className={styles.rowList} aria-label={f('admin.forum.cat.list')} data-search-anchor="fcat-list">
            {items.map((c, index) => (
              <li key={c.id} className={styles.item} data-testid="forum-cat-row">
                <div className={styles.itemHead}>
                  <strong dir="auto">{c.nameTr}</strong>
                  <Badge tone={c.active ? 'success' : 'neutral'}>
                    {f(c.active ? 'admin.forum.cat.status.active' : 'admin.forum.cat.status.archived')}
                  </Badge>
                  <span className={styles.spacer} />
                  <span className={styles.muted}>{f('admin.forum.cat.topicCount', { n: formatNumber(c.topicCount) })}</span>
                </div>
                <p className={styles.muted} dir="auto">
                  <code className={`${styles.mono} ltr`}>{c.slug}</code> · EN: {c.nameEn || f('admin.forum.cat.noTranslation')} · AR:{' '}
                  {c.nameAr ? <span dir="rtl">{c.nameAr}</span> : f('admin.forum.cat.noTranslation')}
                </p>
                {canEdit && (
                  <div className={styles.actions}>
                    <Button
                      size="sm"
                      variant="secondary"
                      className={styles.arrowBtn}
                      aria-label={f('admin.forum.cat.moveUp', { name: c.nameTr })}
                      disabled={index === 0 || reorder.isPending}
                      onClick={() => move(index, -1)}
                    >
                      ↑
                    </Button>
                    <Button
                      size="sm"
                      variant="secondary"
                      className={styles.arrowBtn}
                      aria-label={f('admin.forum.cat.moveDown', { name: c.nameTr })}
                      disabled={index === items.length - 1 || reorder.isPending}
                      onClick={() => move(index, 1)}
                    >
                      ↓
                    </Button>
                    <Button size="sm" variant="secondary" onClick={() => open(c)}>
                      {f('admin.forum.cat.edit')}
                    </Button>
                    {c.active ? (
                      <Button size="sm" variant="danger" onClick={() => setArchiving(c)}>
                        {f('admin.forum.cat.archive')}
                      </Button>
                    ) : (
                      <Button
                        size="sm"
                        variant="secondary"
                        loading={restore.isPending && restore.variables?.id === c.id}
                        onClick={() => restore.mutate(c)}
                      >
                        {f('admin.forum.cat.unarchive')}
                      </Button>
                    )}
                  </div>
                )}
              </li>
            ))}
          </ul>
        )}
      </div>
      <ConfirmDialog
        open={!!archiving}
        onClose={() => setArchiving(null)}
        onConfirm={() => archiving && archive.mutate(archiving)}
        loading={archive.isPending}
        danger
        title={f('admin.forum.cat.archiveTitle')}
        message={f('admin.forum.cat.archiveBody', { name: archiving?.nameTr ?? '' })}
        confirmLabel={f('admin.forum.cat.archive')}
      />
    </>
  );
}
