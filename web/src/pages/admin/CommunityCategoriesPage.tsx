// SAYFA: Kulüp kategorileri (/admin/community-categories)
// API: /api/admin/community-categories (liste/ekle/güncelle/aktif-pasif/sil/sıra) -> api/communityCategories.ts.
// Kategori sınırlıdır (en çok maxActive aktif); kullanımda olan silinemez, pasife alınır.
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import {
  communityCategoryKeys,
  createCommunityCategory,
  deleteCommunityCategory,
  listCommunityCategories,
  reorderCommunityCategories,
  setCommunityCategoryActive,
  updateCommunityCategory,
  type CommunityCategory,
  type CommunityCategoryInput,
} from '../../api/communityCategories';
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
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import { adminErrorMessage } from './campaigns/shared';
import styles from './moderation/moderation.module.css';

const KEY_RE = /^[a-z0-9][a-z0-9-]{0,39}$/;

interface FormState {
  key: string;
  nameTr: string;
  nameEn: string;
  nameAr: string;
  icon: string;
  active: boolean;
}

const EMPTY: FormState = { key: '', nameTr: '', nameEn: '', nameAr: '', icon: '', active: true };

export default function CommunityCategoriesPage() {
  const i18n = useI18n();
  const { t, formatNumber } = i18n;
  usePageTitle(t('admin.ccat.title'));
  const toast = useToast();
  const qc = useQueryClient();
  const [editing, setEditing] = useState<CommunityCategory | 'new' | null>(null);
  const [form, setForm] = useState<FormState>(EMPTY);
  const [touched, setTouched] = useState(false);
  const [removing, setRemoving] = useState<CommunityCategory | null>(null);

  const list = useQuery({ queryKey: communityCategoryKeys.list(), queryFn: listCommunityCategories });
  const items = list.data?.items ?? [];
  const refresh = () => void qc.invalidateQueries({ queryKey: communityCategoryKeys.all });
  const fail = (e: unknown) => toast.error(adminErrorMessage(i18n, e));

  const open = (c: CommunityCategory | 'new') => {
    setEditing(c);
    setTouched(false);
    setForm(
      c === 'new'
        ? EMPTY
        : {
            key: c.key,
            nameTr: c.nameTr,
            nameEn: c.nameEn,
            nameAr: c.nameAr,
            icon: c.icon ?? '',
            active: c.active,
          },
    );
  };
  const close = () => setEditing(null);

  const save = useMutation({
    mutationFn: () => {
      const body: CommunityCategoryInput = {
        nameTr: form.nameTr.trim(),
        nameEn: form.nameEn.trim(),
        nameAr: form.nameAr.trim(),
        icon: form.icon.trim(),
        active: form.active,
      };
      if (editing === 'new') return createCommunityCategory({ ...body, key: form.key.trim() });
      return updateCommunityCategory((editing as CommunityCategory).id, body);
    },
    onSuccess: () => {
      toast.success(t(editing === 'new' ? 'admin.ccat.toast.created' : 'admin.ccat.toast.saved'));
      close();
      refresh();
    },
    onError: fail,
  });
  const toggle = useMutation({
    mutationFn: (c: CommunityCategory) => setCommunityCategoryActive(c.id, !c.active),
    onSuccess: refresh,
    onError: (e) => {
      fail(e);
      refresh();
    },
  });
  const remove = useMutation({
    mutationFn: (c: CommunityCategory) => deleteCommunityCategory(c.id),
    onSuccess: () => {
      toast.success(t('admin.ccat.toast.removed'));
      setRemoving(null);
      refresh();
    },
    onError: (e) => {
      fail(e);
      setRemoving(null);
      refresh();
    },
  });
  const reorder = useMutation({
    mutationFn: (ids: number[]) => reorderCommunityCategories(ids),
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

  const nameInvalid = form.nameTr.trim().length === 0;
  const keyInvalid = editing === 'new' && form.key.trim() !== '' && !KEY_RE.test(form.key.trim());
  const full = !!list.data && list.data.activeCount >= list.data.maxActive;

  return (
    <>
      <PageHeader
        title={t('admin.ccat.title')}
        description={t('admin.ccat.intro')}
        actions={
          <Button onClick={() => open('new')} disabled={!!editing}>
            {t('admin.ccat.add')}
          </Button>
        }
      />
      <div className={styles.stack}>
        {list.data && (
          <p className={styles.muted} role="status">
            {t('admin.ccat.limit', {
              active: formatNumber(list.data.activeCount),
              max: formatNumber(list.data.maxActive),
            })}
            {full ? ` ${t('admin.ccat.limitFull')}` : ''}
          </p>
        )}

        {editing && (
          <Card title={t(editing === 'new' ? 'admin.ccat.form.new' : 'admin.ccat.form.edit')}>
            <form
              noValidate
              className={styles.formGrid}
              onSubmit={(e) => {
                e.preventDefault();
                setTouched(true);
                if (!nameInvalid && !keyInvalid) save.mutate();
              }}
            >
              <FormField
                label={t('admin.ccat.field.key')}
                hint={t(editing === 'new' ? 'admin.ccat.field.keyHint' : 'admin.ccat.field.keyLocked')}
                error={touched && keyInvalid ? t('admin.ccat.field.keyInvalid') : null}
              >
                <Input
                  value={form.key}
                  maxLength={40}
                  dir="ltr"
                  autoComplete="off"
                  disabled={editing !== 'new'}
                  onChange={(e) => setForm({ ...form, key: e.target.value })}
                />
              </FormField>
              <FormField label={t('admin.ccat.field.icon')} hint={t('admin.ccat.field.iconHint')}>
                <Input
                  value={form.icon}
                  maxLength={40}
                  dir="ltr"
                  autoComplete="off"
                  onChange={(e) => setForm({ ...form, icon: e.target.value })}
                />
              </FormField>
              <FormField
                label={t('admin.ccat.field.nameTr')}
                error={touched && nameInvalid ? t('admin.ccat.field.nameRequired') : null}
                required
              >
                <Input
                  value={form.nameTr}
                  maxLength={80}
                  onChange={(e) => setForm({ ...form, nameTr: e.target.value })}
                />
              </FormField>
              <FormField label={t('admin.ccat.field.nameEn')} hint={t('admin.ccat.field.nameFallback')}>
                <Input
                  value={form.nameEn}
                  maxLength={80}
                  dir="ltr"
                  onChange={(e) => setForm({ ...form, nameEn: e.target.value })}
                />
              </FormField>
              <FormField label={t('admin.ccat.field.nameAr')} hint={t('admin.ccat.field.nameFallback')}>
                <Input
                  value={form.nameAr}
                  maxLength={80}
                  dir="rtl"
                  onChange={(e) => setForm({ ...form, nameAr: e.target.value })}
                />
              </FormField>
              <div className={styles.wide}>
                <Checkbox
                  label={t('admin.ccat.field.active')}
                  checked={form.active}
                  onChange={(e) => setForm({ ...form, active: e.target.checked })}
                />
              </div>
              <div className={styles.actions}>
                <Button type="submit" loading={save.isPending}>
                  {t('common.save')}
                </Button>
                <Button type="button" variant="secondary" onClick={close}>
                  {t('common.cancel')}
                </Button>
              </div>
            </form>
          </Card>
        )}

        {list.isError ? (
          <ErrorState description={adminErrorMessage(i18n, list.error)} onRetry={() => void list.refetch()} />
        ) : list.isLoading ? (
          <Skeleton height="5rem" width="100%" />
        ) : items.length === 0 ? (
          <EmptyState icon="list" title={t('admin.ccat.empty.title')} description={t('admin.ccat.empty.hint')} />
        ) : (
          <ul className={styles.rowList} aria-label={t('admin.ccat.list')}>
            {items.map((c, index) => (
              <li key={c.id} className={styles.item}>
                <div className={styles.itemHead}>
                  <strong dir="auto">{c.nameTr}</strong>
                  <Badge tone={c.active ? 'success' : 'neutral'}>
                    {t(c.active ? 'admin.ccat.status.active' : 'admin.ccat.status.inactive')}
                  </Badge>
                  <span className={styles.spacer} />
                  <span className={styles.muted}>{t('admin.ccat.usage', { n: formatNumber(c.usageCount) })}</span>
                </div>
                <p className={styles.muted} dir="auto">
                  <code className={`${styles.mono} ltr`}>{c.key}</code> · EN: {c.nameEn} · AR: <span dir="rtl">{c.nameAr}</span>
                  {c.icon ? ` · ${c.icon}` : ''}
                </p>
                <div className={styles.actions}>
                  <Button
                    size="sm"
                    variant="secondary"
                    aria-label={t('admin.ccat.moveUp', { name: c.nameTr })}
                    disabled={index === 0 || reorder.isPending}
                    onClick={() => move(index, -1)}
                  >
                    ↑
                  </Button>
                  <Button
                    size="sm"
                    variant="secondary"
                    aria-label={t('admin.ccat.moveDown', { name: c.nameTr })}
                    disabled={index === items.length - 1 || reorder.isPending}
                    onClick={() => move(index, 1)}
                  >
                    ↓
                  </Button>
                  <Button size="sm" variant="secondary" onClick={() => open(c)}>
                    {t('admin.ccat.edit')}
                  </Button>
                  <Button
                    size="sm"
                    variant="secondary"
                    loading={toggle.isPending && toggle.variables?.id === c.id}
                    onClick={() => toggle.mutate(c)}
                  >
                    {t(c.active ? 'admin.ccat.deactivate' : 'admin.ccat.activate')}
                  </Button>
                  <Button size="sm" variant="danger" onClick={() => setRemoving(c)}>
                    {t('admin.ccat.remove')}
                  </Button>
                </div>
              </li>
            ))}
          </ul>
        )}
      </div>
      <ConfirmDialog
        open={!!removing}
        onClose={() => setRemoving(null)}
        onConfirm={() => removing && remove.mutate(removing)}
        loading={remove.isPending}
        danger
        title={t('admin.ccat.removeTitle')}
        message={t('admin.ccat.removeBody', { name: removing?.nameTr ?? '' })}
        confirmLabel={t('admin.ccat.remove')}
      />
    </>
  );
}
