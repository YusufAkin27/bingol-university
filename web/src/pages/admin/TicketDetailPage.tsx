// SAYFA: Talep ayrıntısı (/admin/support/tickets/:id)
// API: GET /api/admin/support/tickets/{id}, POST .../{id}/reply {text}, POST .../{id}/close (api/support.ts).
// Hazır yanıtlar yalnızca bu tarayıcının localStorage'ındadır (support/supportLogic.ts).
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useRef, useState, type KeyboardEvent } from 'react';
import { useLocation, useNavigate, useParams } from 'react-router-dom';
import { qk, supportAdminApi, supportApi } from '../../api';
import { TICKET_PRIORITIES, messageKey, type AdminTicketDetail, type TicketPriority } from '../../api/supportAdmin';
import type { StaffReplyResult } from '../../api/types';
import {
  Badge,
  Button,
  Card,
  ConfirmDialog,
  ErrorState,
  FormField,
  GuardedAction,
  Icon,
  IconButton,
  Input,
  PageHeader,
  Select,
  Skeleton,
  StatusPill,
  Tabs,
  Textarea,
  toneFor,
  useToast,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { errorMessage } from '../../lib/errors';
import { usePageTitle } from '../../lib/hooks';
import { paths } from '../../paths';
import { adminError } from '../../lib/errors';
import { internalNotes, mergeThread, parseAssignee, threadMessages } from './moderation/p11Logic';
import p11 from './moderation/p11.module.css';
import { ChatThread } from './support/ChatThread';
import styles from './support/Support.module.css';
import {
  MAX_REPLY,
  MAX_TEMPLATES,
  addTemplate,
  canClose,
  canReply,
  isSubmitShortcut,
  loadTemplates,
  removeTemplate,
  saveTemplates,
  type ReplyTemplate,
} from './support/supportLogic';

export default function TicketDetailPage() {
  const i18n = useI18n();
  const { t, formatDateTime } = i18n;
  const id = Number(useParams().id);
  const location = useLocation();
  const stateEmail = (location.state as { email?: string } | null)?.email;
  const toast = useToast();
  const qc = useQueryClient();
  usePageTitle(t('admin.tickets.detail.title'));

  const [text, setText] = useState('');
  const [closeOpen, setCloseOpen] = useState(false);
  const navigate = useNavigate();
  const [tab, setTab] = useState<'thread' | 'notes'>('thread');
  const [noteText, setNoteText] = useState('');
  const [assignee, setAssignee] = useState('');
  const [templates, setTemplates] = useState<ReplyTemplate[]>(loadTemplates);
  const [newTpl, setNewTpl] = useState('');
  const replyRef = useRef<HTMLTextAreaElement>(null);

  const query = useQuery({
    queryKey: qk.tickets.detail(id),
    queryFn: () => supportAdminApi.getTicketAdmin(id),
    enabled: Number.isFinite(id),
  });

  function applyDetail(d: StaffReplyResult) {
    // Yanıt sonucu müşteri görünümüdür (iç not yok): mevcut iç notları koruyarak birleştir
    qc.setQueryData<AdminTicketDetail>(qk.tickets.detail(id), (old) =>
      old ? { ...old, ticket: d.ticket, messages: mergeThread(d.messages, old.messages) } : old,
    );
    void qc.invalidateQueries({ queryKey: ['tickets', 'list'] });
    void qc.invalidateQueries({ queryKey: qk.analytics.all });
  }

  const reply = useMutation({
    mutationFn: () => supportApi.replyTicket(id, text.trim()),
    onSuccess: (d) => {
      if (d.emailStatus === 'FAILED') toast.error(t('admin.tickets.reply.mailFailed'));
      else toast.success(t(d.emailStatus === 'SENT' ? 'admin.tickets.reply.sentMail' : 'admin.tickets.reply.sent'));
      setText('');
      applyDetail(d);
    },
    onError: (e) => toast.error(errorMessage(i18n, e)),
  });
  const close = useMutation({
    mutationFn: () => supportApi.closeTicket(id),
    onSuccess: async () => {
      toast.success(t('admin.tickets.close.done'));
      setCloseOpen(false);
      await qc.invalidateQueries({ queryKey: qk.tickets.detail(id) });
      void qc.invalidateQueries({ queryKey: ['tickets', 'list'] });
    },
    onError: (e) => {
      toast.error(errorMessage(i18n, e));
      setCloseOpen(false);
    },
  });

  const afterChange = (d: AdminTicketDetail) => {
    qc.setQueryData(qk.tickets.detail(id), d);
    void qc.invalidateQueries({ queryKey: ['tickets', 'list'] });
  };
  const reopen = useMutation({
    mutationFn: () => supportAdminApi.reopenTicket(id),
    onSuccess: (d) => {
      toast.success(t('admin.p12.reopen.done'));
      afterChange(d);
    },
    onError: (e) => toast.error(adminError(i18n, e)),
  });
  const patch = useMutation({
    mutationFn: (p: Parameters<typeof supportAdminApi.patchTicket>[1]) => supportAdminApi.patchTicket(id, p),
    onSuccess: (d) => {
      toast.success(t('admin.p12.patch.done'));
      setAssignee('');
      afterChange(d);
    },
    onError: (e) => toast.error(adminError(i18n, e)),
  });
  const addNote = useMutation({
    mutationFn: () => supportAdminApi.addTicketNote(id, noteText),
    onSuccess: () => {
      toast.success(t('admin.p12.notes.added'));
      setNoteText('');
      void qc.invalidateQueries({ queryKey: qk.tickets.detail(id) });
    },
    onError: (e) => toast.error(adminError(i18n, e)),
  });

  const ticket = query.data?.ticket;
  const email = query.data?.userEmail ?? stateEmail;
  const isPublic = !!ticket?.publicTicket;
  const open = ticket ? canReply(ticket.status) : false;
  const canSend = open && text.trim().length > 0 && text.length <= MAX_REPLY && !reply.isPending;

  function send() {
    if (canSend) reply.mutate();
  }
  function onKeyDown(e: KeyboardEvent<HTMLTextAreaElement>) {
    if (isSubmitShortcut(e)) {
      e.preventDefault();
      send();
    }
  }

  function updateTemplates(next: ReplyTemplate[]) {
    setTemplates(next);
    saveTemplates(next);
  }
  function insert(tpl: ReplyTemplate) {
    setText((cur) => (cur.trim() ? `${cur.replace(/\s+$/, '')}\n\n${tpl.text}` : tpl.text).slice(0, MAX_REPLY));
    replyRef.current?.focus();
  }

  const crumbs = [{ label: t('admin.tickets.title'), to: paths.admin.tickets }, { label: `#${Number.isFinite(id) ? id : ''}` }];

  if (query.isError) {
    return (
      <>
        <PageHeader title={t('admin.tickets.detail.title')} breadcrumbs={crumbs} />
        <ErrorState onRetry={() => void query.refetch()} description={errorMessage(i18n, query.error)} />
      </>
    );
  }

  return (
    <>
      <PageHeader
        breadcrumbs={crumbs}
        title={ticket ? <span dir="auto">{ticket.subject}</span> : t('admin.tickets.detail.title')}
        description={
          ticket ? (
            <span className={styles.meta}>
              <StatusPill tone={toneFor(ticket.status)}>{t(`admin.tickets.status.${ticket.status}`)}</StatusPill>
              <span>{t(`admin.tickets.category.${ticket.category}`)}</span>
              <span>{t('admin.tickets.detail.opened', { date: formatDateTime(ticket.createdAt) })}</span>
              {email && <span className="ltr">{t('admin.tickets.detail.user', { email })}</span>}
              {isPublic && <Badge tone="info">{t('admin.tickets.public.badge')}</Badge>}
            </span>
          ) : undefined
        }
        actions={
          ticket ? (
            <>
              {canClose(ticket.status) ? (
                <Button variant="secondary" onClick={() => setCloseOpen(true)}>
                  {t('admin.tickets.close.button')}
                </Button>
              ) : (
                <Button variant="secondary" loading={reopen.isPending} onClick={() => reopen.mutate()}>
                  {t('admin.p12.reopen.button')}
                </Button>
              )}
              <GuardedAction
                variant="ghost"
                danger
                irreversible
                requireReason
                typeToConfirm={t('admin.p12.delete.confirmWord')}
                title={t('admin.p12.delete.title')}
                confirmLabel={t('admin.p12.delete.button')}
                message={<strong dir="auto">{ticket.subject}</strong>}
                consequence={t(isPublic ? 'admin.p12.delete.consequencePublic' : 'admin.p12.delete.consequence')}
                successMessage={t('admin.p12.delete.done')}
                errorMessage={(e) => adminError(i18n, e)}
                invalidateKeys={[qk.tickets.all]}
                onSuccess={() => navigate(paths.admin.tickets)}
                onConfirm={({ reason, idempotencyKey }) => supportAdminApi.deleteTicket(id, { reason, idempotencyKey })}
              >
                {t('admin.p12.delete.button')}
              </GuardedAction>
            </>
          ) : undefined
        }
      />

      <div className={styles.detailGrid}>
        <div className={styles.main}>
          <Tabs
            label={t('admin.p12.tabs')}
            value={tab}
            onChange={(v) => setTab(v as 'thread' | 'notes')}
            tabs={[
              { id: 'thread', label: t('admin.p12.tab.thread') },
              {
                id: 'notes',
                label: t('admin.p12.tab.notes', { n: query.data ? internalNotes(query.data.messages).length : 0 }),
              },
            ]}
          />
          {tab === 'thread' ? (
            <Card>
              {query.isLoading || !query.data ? (
                <div style={{ display: 'grid', gap: 12 }}>
                  <Skeleton height="4rem" radius="var(--radius-lg)" />
                  <Skeleton height="4rem" radius="var(--radius-lg)" />
                </div>
              ) : (
                <ChatThread messages={threadMessages(query.data.messages)} />
              )}
            </Card>
          ) : (
            <Card>
              <p className={`${p11.callout} ${p11.calloutWarn}`} role="note">
                {t('admin.p12.notes.warning')}
              </p>
              {query.data && internalNotes(query.data.messages).length > 0 ? (
                <ul className={p11.noteList} aria-label={t('admin.p12.notes.list')}>
                  {internalNotes(query.data.messages).map((n) => (
                    <li key={messageKey(n)} className={p11.note}>
                      <p className={p11.noteText} dir="auto">
                        {n.text}
                      </p>
                      <time className={p11.noteTime} dateTime={n.createdAt}>
                        {formatDateTime(n.createdAt)}
                      </time>
                    </li>
                  ))}
                </ul>
              ) : (
                <p className={styles.hint}>{t('admin.p12.notes.empty')}</p>
              )}
              <form
                className={p11.sideForm}
                onSubmit={(e) => {
                  e.preventDefault();
                  if (noteText.trim() && !addNote.isPending) addNote.mutate();
                }}
              >
                <FormField
                  label={t('admin.p12.notes.label')}
                  hint={<span className="ltr">{t('admin.tickets.reply.counter', { n: noteText.length, max: 2000 })}</span>}
                >
                  <Textarea
                    rows={3}
                    dir="auto"
                    maxLength={2000}
                    value={noteText}
                    placeholder={t('admin.p12.notes.placeholder')}
                    onChange={(e) => setNoteText(e.target.value)}
                  />
                </FormField>
                <div>
                  <Button type="submit" variant="secondary" disabled={!noteText.trim()} loading={addNote.isPending}>
                    {t('admin.p12.notes.add')}
                  </Button>
                </div>
              </form>
            </Card>
          )}

          <Card>
            {open ? (
              <div className={styles.compose}>
                <label htmlFor="ticket-reply" className={styles.composeLabel}>
                  {t('admin.tickets.reply.label')}
                </label>
                <Textarea
                  id="ticket-reply"
                  ref={replyRef}
                  rows={5}
                  dir="auto"
                  value={text}
                  maxLength={MAX_REPLY}
                  placeholder={t('admin.tickets.reply.placeholder')}
                  onChange={(e) => setText(e.target.value)}
                  onKeyDown={onKeyDown}
                />
                <div className={styles.composeFoot}>
                  <span className={styles.hint}>
                    {t(isPublic ? 'admin.tickets.reply.hintMail' : 'admin.tickets.reply.hint')}
                  </span>
                  <span
                    className={`${styles.counter} ${text.length > MAX_REPLY - 100 ? styles.counterWarn : ''} ltr`}
                    aria-live="polite"
                  >
                    {t('admin.tickets.reply.counter', { n: text.length, max: MAX_REPLY })}
                  </span>
                  <Button onClick={send} disabled={!canSend} loading={reply.isPending}>
                    {t('admin.tickets.reply.send')}
                  </Button>
                </div>
              </div>
            ) : (
              ticket && <p className={styles.closedNote}>{t('admin.tickets.reply.closed')}</p>
            )}
          </Card>
        </div>

        <aside className={styles.aside} aria-label={t('admin.tickets.tpl.title')}>
          {query.data && (
            <Card title={t('admin.p12.triage.title')}>
              <div className={p11.sideForm}>
                <FormField label={t('admin.p12.triage.priority')}>
                  <Select
                    value={query.data.priority ?? 'NORMAL'}
                    disabled={patch.isPending}
                    onChange={(e) => patch.mutate({ priority: e.target.value as TicketPriority })}
                  >
                    {TICKET_PRIORITIES.map((p) => (
                      <option key={p} value={p}>
                        {t(`admin.p12.priority.${p}`)}
                      </option>
                    ))}
                  </Select>
                </FormField>
                <p className={styles.hint} data-testid="assignee-now">
                  {query.data.assigneeId
                    ? t('admin.p12.triage.assigned', { name: query.data.assigneeName ?? `#${query.data.assigneeId}` })
                    : t('admin.p12.triage.unassigned')}
                </p>
                <div className={p11.inlineRow}>
                  <FormField label={t('admin.p12.triage.assigneeId')} hint={t('admin.p12.triage.assigneeHint')}>
                    <Input
                      inputMode="numeric"
                      className="ltr"
                      value={assignee}
                      onChange={(e) => setAssignee(e.target.value)}
                    />
                  </FormField>
                  <Button
                    size="sm"
                    variant="secondary"
                    disabled={parseAssignee(assignee) === null}
                    loading={patch.isPending}
                    onClick={() => {
                      const a = parseAssignee(assignee);
                      if (a !== null) patch.mutate({ assigneeId: a });
                    }}
                  >
                    {t('admin.p12.triage.assign')}
                  </Button>
                  {query.data.assigneeId && (
                    <Button size="sm" variant="ghost" disabled={patch.isPending} onClick={() => patch.mutate({ unassign: true })}>
                      {t('admin.p12.triage.unassign')}
                    </Button>
                  )}
                </div>
              </div>
            </Card>
          )}
          <Card title={t('admin.tickets.tpl.title')}>
            <p className={styles.hint}>{t('admin.tickets.tpl.hint')}</p>
            {templates.length === 0 ? (
              <p className={styles.hint}>{t('admin.tickets.tpl.empty')}</p>
            ) : (
              <ul className={styles.tplList}>
                {templates.map((tpl) => (
                  <li key={tpl.id} className={styles.tpl}>
                    <button
                      type="button"
                      className={styles.tplInsert}
                      disabled={!open}
                      title={t('admin.tickets.tpl.insert', { text: tpl.text })}
                      aria-label={t('admin.tickets.tpl.insert', { text: tpl.text })}
                      onClick={() => insert(tpl)}
                    >
                      <span dir="auto">{tpl.text}</span>
                    </button>
                    <IconButton
                      label={t('admin.tickets.tpl.remove')}
                      size="sm"
                      onClick={() => updateTemplates(removeTemplate(templates, tpl.id))}
                    >
                      <Icon name="x" size={16} />
                    </IconButton>
                  </li>
                ))}
              </ul>
            )}
            <form
              className={styles.tplForm}
              onSubmit={(e) => {
                e.preventDefault();
                updateTemplates(addTemplate(templates, newTpl));
                setNewTpl('');
              }}
            >
              <Input
                value={newTpl}
                dir="auto"
                maxLength={MAX_REPLY}
                aria-label={t('admin.tickets.tpl.placeholder')}
                placeholder={t('admin.tickets.tpl.placeholder')}
                onChange={(e) => setNewTpl(e.target.value)}
              />
              <div className={styles.tplActions}>
                <Button
                  type="submit"
                  size="sm"
                  variant="secondary"
                  disabled={!newTpl.trim() || templates.length >= MAX_TEMPLATES}
                  leftIcon={<Icon name="plus" size={16} />}
                >
                  {t('admin.tickets.tpl.add')}
                </Button>
                <Button
                  size="sm"
                  variant="ghost"
                  disabled={!text.trim() || templates.length >= MAX_TEMPLATES}
                  onClick={() => updateTemplates(addTemplate(templates, text))}
                >
                  {t('admin.tickets.tpl.saveCurrent')}
                </Button>
              </div>
              {templates.length >= MAX_TEMPLATES && <p className={styles.hint}>{t('admin.tickets.tpl.full')}</p>}
            </form>
          </Card>
        </aside>
      </div>

      <ConfirmDialog
        open={closeOpen}
        onClose={() => setCloseOpen(false)}
        onConfirm={() => close.mutate()}
        loading={close.isPending}
        danger
        title={t('admin.tickets.close.title')}
        message={t('admin.tickets.close.body')}
        confirmLabel={t('admin.tickets.close.confirm')}
      />
    </>
  );
}
