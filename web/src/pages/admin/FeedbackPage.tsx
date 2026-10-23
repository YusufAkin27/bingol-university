// SAYFA: Geri bildirim ve öneriler (/admin/support/feedback)
// API: GET /api/admin/feedback?status=&category=&cursor=&size= (imeç tabanlı), PATCH /api/admin/feedback/{id}
//      {status, adminResponse, publicVisible} (api/feedback.ts). Yanıt/durum değişince kullanıcıya bildirim gider.
import { useInfiniteQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useEffect, useMemo, useState } from 'react';
import { feedbackApi, qk } from '../../api';
import type { AdminFeedbackView, FeedbackCategory, FeedbackStatus } from '../../api/types';
import {
  Badge,
  Button,
  DataToolbar,
  Drawer,
  EmptyState,
  ErrorState,
  FormField,
  Icon,
  LoadMore,
  PageHeader,
  Select,
  Skeleton,
  StatusPill,
  Switch,
  Textarea,
  toneFor,
  useToast,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { errorMessage } from '../../lib/errors';
import { usePageTitle } from '../../lib/hooks';
import styles from './support/Support.module.css';
import {
  FEEDBACK_STATUSES,
  MAX_FEEDBACK_RESPONSE,
  canPublish,
  feedbackPatch,
  type FeedbackDraft,
} from './support/supportLogic';

const CATEGORIES: FeedbackCategory[] = ['BUG', 'SUGGESTION', 'COMPLAINT', 'PRAISE', 'OTHER'];

function FeedbackDrawer({ item, onClose }: { item: AdminFeedbackView; onClose: () => void }) {
  const i18n = useI18n();
  const { t, formatDateTime } = i18n;
  const toast = useToast();
  const qc = useQueryClient();
  const [draft, setDraft] = useState<FeedbackDraft>({
    status: item.status,
    adminResponse: item.adminResponse ?? '',
    publicVisible: item.publicVisible,
  });
  const patch = feedbackPatch(item, draft);
  const publishable = canPublish(item.category);

  const save = useMutation({
    mutationFn: () => feedbackApi.updateFeedback(item.id, patch ?? {}),
    onSuccess: () => {
      const notifies = !!patch && (patch.status !== undefined || patch.adminResponse !== undefined);
      toast.success(t(notifies ? 'admin.feedback.saved' : 'admin.feedback.savedQuiet'));
      void qc.invalidateQueries({ queryKey: qk.feedback.all });
      void qc.invalidateQueries({ queryKey: qk.analytics.all });
      onClose();
    },
    onError: (e) => toast.error(errorMessage(i18n, e)),
  });

  return (
    <Drawer
      open
      onClose={onClose}
      title={t('admin.feedback.drawer.title')}
      size="md"
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>
            {t('common.cancel')}
          </Button>
          <Button onClick={() => save.mutate()} disabled={!patch} loading={save.isPending}>
            {t('common.save')}
          </Button>
        </>
      }
    >
      <div className={styles.drawerForm}>
        <div>
          <div className={styles.fbHead}>
            <Badge tone="primary">{t(`admin.feedback.category.${item.category}`)}</Badge>
            <span className={styles.fbMeta}>{formatDateTime(item.createdAt)}</span>
          </div>
          <h3 className={styles.fbSubject} dir="auto">
            {item.subject}
          </h3>
        </div>
        <p className={styles.quote} dir="auto">
          {item.message}
        </p>

        <FormField label={t('admin.feedback.field.status')}>
          <Select
            value={draft.status}
            onChange={(e) => setDraft({ ...draft, status: e.target.value as FeedbackStatus })}
          >
            {FEEDBACK_STATUSES.map((s) => (
              <option key={s} value={s}>
                {t(`admin.feedback.status.${s}`)}
              </option>
            ))}
          </Select>
        </FormField>

        <FormField
          label={t('admin.feedback.field.response')}
          hint={t('admin.feedback.counter', { n: draft.adminResponse.length, max: MAX_FEEDBACK_RESPONSE })}
        >
          <Textarea
            rows={5}
            dir="auto"
            value={draft.adminResponse}
            maxLength={MAX_FEEDBACK_RESPONSE}
            placeholder={t('admin.feedback.field.responsePlaceholder')}
            onChange={(e) => setDraft({ ...draft, adminResponse: e.target.value })}
          />
        </FormField>
        <p className={styles.notice}>
          <Icon name="bell" size={18} />
          <span>{t('admin.feedback.notify')}</span>
        </p>

        <div>
          <Switch
            checked={publishable && draft.publicVisible}
            disabled={!publishable}
            onChange={(v) => setDraft({ ...draft, publicVisible: v })}
            label={t('admin.feedback.public.label')}
          />
          <p className={styles.disabledNote}>
            {publishable ? t('admin.feedback.public.hint') : t('admin.feedback.public.disabled')}
          </p>
        </div>
      </div>
    </Drawer>
  );
}

export default function FeedbackPage() {
  const i18n = useI18n();
  const { t, formatDateTime, formatNumber } = i18n;
  usePageTitle(t('admin.feedback.title'));
  const [status, setStatus] = useState<FeedbackStatus | ''>('');
  const [category, setCategory] = useState<FeedbackCategory | ''>('');
  const [editingId, setEditingId] = useState<number | null>(null);

  const query = useInfiniteQuery({
    queryKey: qk.feedback.list(status || undefined, category || undefined),
    queryFn: ({ pageParam }) =>
      feedbackApi.listFeedback({
        status: status || undefined,
        category: category || undefined,
        cursor: pageParam,
        size: 20,
      }),
    initialPageParam: null as number | null,
    getNextPageParam: (p) => p.nextCursor,
  });
  const items = useMemo(() => query.data?.pages.flatMap((p) => p.items) ?? [], [query.data]);
  const editing = items.find((i) => i.id === editingId) ?? null;

  useEffect(() => {
    if (editingId !== null && !editing && !query.isFetching) setEditingId(null);
  }, [editingId, editing, query.isFetching]);

  return (
    <>
      <PageHeader title={t('admin.feedback.title')} description={t('admin.feedback.subtitle')} />
      <DataToolbar
        filters={
          <div className={styles.filterRow}>
            <Select className={styles.filter}
              aria-label={t('admin.feedback.filter.status')}
              value={status}
              onChange={(e) => setStatus(e.target.value as FeedbackStatus | '')}
            >
              <option value="">{t('admin.feedback.filter.allStatus')}</option>
              {FEEDBACK_STATUSES.map((s) => (
                <option key={s} value={s}>
                  {t(`admin.feedback.status.${s}`)}
                </option>
              ))}
            </Select>
            <Select className={styles.filter}
              aria-label={t('admin.feedback.filter.category')}
              value={category}
              onChange={(e) => setCategory(e.target.value as FeedbackCategory | '')}
            >
              <option value="">{t('admin.feedback.filter.allCategory')}</option>
              {CATEGORIES.map((c) => (
                <option key={c} value={c}>
                  {t(`admin.feedback.category.${c}`)}
                </option>
              ))}
            </Select>
          </div>
        }
      />

      {query.isError ? (
        <ErrorState onRetry={() => void query.refetch()} description={errorMessage(i18n, query.error)} />
      ) : query.isLoading ? (
        <ul className={styles.fbList}>
          {[0, 1, 2].map((i) => (
            <li key={i}>
              <Skeleton height="7rem" radius="var(--radius-md)" />
            </li>
          ))}
        </ul>
      ) : items.length === 0 ? (
        <EmptyState
          icon="message"
          title={t('admin.feedback.empty.title')}
          description={t('admin.feedback.empty.hint')}
        />
      ) : (
        <>
          <ul className={styles.fbList}>
            {items.map((f) => (
              <li key={f.id} className={styles.fb}>
                <div className={styles.votes} aria-label={`${t('admin.feedback.votesLabel')}: ${f.voteCount}`}>
                  <span className={styles.votesNum}>{formatNumber(f.voteCount)}</span>
                  <span className={styles.votesLbl}>{t('admin.feedback.votes', { n: '' }).trim()}</span>
                </div>
                <div className={styles.fbBody}>
                  <div className={styles.fbHead}>
                    <Badge tone="primary">{t(`admin.feedback.category.${f.category}`)}</Badge>
                    <StatusPill tone={toneFor(f.status)}>{t(`admin.feedback.status.${f.status}`)}</StatusPill>
                    {f.publicVisible && <Badge tone="info">{t('admin.feedback.public')}</Badge>}
                  </div>
                  <h3 className={styles.fbSubject} dir="auto">
                    {f.subject}
                  </h3>
                  <p className={styles.fbMessage} dir="auto">
                    {f.message}
                  </p>
                  {f.adminResponse && (
                    <p className={styles.response} dir="auto">
                      <span className={styles.responseLabel}>{t('admin.feedback.myResponse')}</span>
                      {f.adminResponse}
                    </p>
                  )}
                  <div className={styles.fbMeta}>
                    <span className="ltr">{f.userEmail ?? `#${f.userId}`}</span>
                    <span>{formatDateTime(f.createdAt)}</span>
                    {f.platform && <span className="ltr">{f.platform}</span>}
                    {f.appVersion && <span className="ltr">v{f.appVersion}</span>}
                  </div>
                </div>
                <div className={styles.fbAct}>
                  <Button variant="secondary" size="sm" onClick={() => setEditingId(f.id)}>
                    {t('admin.feedback.edit')}
                  </Button>
                </div>
              </li>
            ))}
          </ul>
          <LoadMore
            hasMore={!!query.hasNextPage}
            loading={query.isFetchingNextPage}
            onLoadMore={() => void query.fetchNextPage()}
          />
        </>
      )}
      {editing && <FeedbackDrawer key={editing.id} item={editing} onClose={() => setEditingId(null)} />}
    </>
  );
}
