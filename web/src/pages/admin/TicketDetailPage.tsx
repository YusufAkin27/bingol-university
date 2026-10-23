// SAYFA: Talep ayrıntısı (/admin/support/tickets/:id)
// API: GET /api/admin/support/tickets/{id}, POST .../{id}/reply {text}, POST .../{id}/close (api/support.ts).
// Hazır yanıtlar yalnızca bu tarayıcının localStorage'ındadır (support/supportLogic.ts).
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useRef, useState, type KeyboardEvent } from 'react';
import { useLocation, useParams } from 'react-router-dom';
import { qk, supportApi } from '../../api';
import type { TicketDetail } from '../../api/types';
import {
  Button,
  Card,
  ConfirmDialog,
  ErrorState,
  Icon,
  IconButton,
  Input,
  PageHeader,
  Skeleton,
  StatusPill,
  Textarea,
  toneFor,
  useToast,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { errorMessage } from '../../lib/errors';
import { usePageTitle } from '../../lib/hooks';
import { paths } from '../../paths';
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
  const email = (location.state as { email?: string } | null)?.email;
  const toast = useToast();
  const qc = useQueryClient();
  usePageTitle(t('admin.tickets.detail.title'));

  const [text, setText] = useState('');
  const [closeOpen, setCloseOpen] = useState(false);
  const [templates, setTemplates] = useState<ReplyTemplate[]>(loadTemplates);
  const [newTpl, setNewTpl] = useState('');
  const replyRef = useRef<HTMLTextAreaElement>(null);

  const query = useQuery({
    queryKey: qk.tickets.detail(id),
    queryFn: () => supportApi.getTicket(id),
    enabled: Number.isFinite(id),
  });

  function applyDetail(d: TicketDetail) {
    qc.setQueryData(qk.tickets.detail(id), d);
    void qc.invalidateQueries({ queryKey: ['tickets', 'list'] });
    void qc.invalidateQueries({ queryKey: qk.analytics.all });
  }

  const reply = useMutation({
    mutationFn: () => supportApi.replyTicket(id, text.trim()),
    onSuccess: (d) => {
      toast.success(t('admin.tickets.reply.sent'));
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

  const ticket = query.data?.ticket;
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
            </span>
          ) : undefined
        }
        actions={
          ticket && canClose(ticket.status) ? (
            <Button variant="secondary" onClick={() => setCloseOpen(true)}>
              {t('admin.tickets.close.button')}
            </Button>
          ) : undefined
        }
      />

      <div className={styles.detailGrid}>
        <div className={styles.main}>
          <Card>
            {query.isLoading || !query.data ? (
              <div style={{ display: 'grid', gap: 12 }}>
                <Skeleton height="4rem" radius="var(--radius-lg)" />
                <Skeleton height="4rem" radius="var(--radius-lg)" />
              </div>
            ) : (
              <ChatThread messages={query.data.messages} />
            )}
          </Card>

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
                  <span className={styles.hint}>{t('admin.tickets.reply.hint')}</span>
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
