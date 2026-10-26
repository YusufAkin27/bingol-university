// SAYFA: Destek talebi durumu (/support/track?token=...)
// API: POST /api/public/support/track {token}, POST /api/public/support/track/messages {token,text} (api/publicSupport.ts).
// Anahtar yalnızca e-postadaki bağlantıda bulunur; indekslenmez (noindex).
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState, type FormEvent } from 'react';
import { useSearchParams } from 'react-router-dom';
import { MESSAGE_MAX, replyPublicTicket, trackPublicTicket } from '../../api/publicSupport';
import { Button, EmptyState, ErrorState, Skeleton, StatusPill, Textarea, toneFor } from '../../components/ui';
import type { TranslationKey } from '../../i18n';
import { useI18n } from '../../i18n/I18nProvider';
import { errorMessage } from '../../lib/errors';
import { isApiError } from '../../api/client';
import { PageHero } from './components/PageHero';
import { usePageMeta } from './components/usePageMeta';
import shared from './components/site.module.css';
import styles from './SupportTrackPage.module.css';

export default function SupportTrackPage() {
  const i18n = useI18n();
  const { t, formatDateTime } = i18n;
  const token = useSearchParams()[0].get('token')?.trim() ?? '';
  const qc = useQueryClient();
  const [text, setText] = useState('');
  const [sent, setSent] = useState(false);
  usePageMeta({ title: t('site.track.title'), noindex: true });

  const query = useQuery({
    queryKey: ['public', 'support', 'track', token],
    queryFn: () => trackPublicTicket(token),
    enabled: token.length > 0,
    retry: false,
  });
  const reply = useMutation({
    mutationFn: () => replyPublicTicket(token, text.trim()),
    onSuccess: (d) => {
      qc.setQueryData(['public', 'support', 'track', token], d);
      setText('');
      setSent(true);
    },
  });

  function onSubmit(e: FormEvent) {
    e.preventDefault();
    setSent(false);
    if (text.trim()) reply.mutate();
  }

  const ticket = query.data?.ticket;
  const notFound = query.isError && isApiError(query.error) && query.error.status === 404;

  return (
    <>
      <PageHero title={t('site.track.title')} lead={t('site.track.lead')} />
      <section className={`${shared.section} ${shared.sectionTop}`}>
        <div className={`container ${styles.wrap}`}>
          {!token && <EmptyState icon="info" title={t('site.track.noToken')} />}
          {token && query.isLoading && (
            <div role="status" aria-label={t('common.loading')} className={styles.skel}>
              <Skeleton height="3rem" />
              <Skeleton height="3rem" width="70%" />
            </div>
          )}
          {notFound && <EmptyState icon="info" title={t('site.track.notFound')} description={t('site.track.notFoundHint')} />}
          {query.isError && !notFound && (
            <ErrorState
              title={t('site.track.error')}
              description={errorMessage(i18n, query.error)}
              onRetry={() => void query.refetch()}
            />
          )}
          {ticket && query.data && (
            <>
              <header className={styles.head}>
                <h2 className={styles.subject} dir="auto">
                  {ticket.subject}
                </h2>
                <StatusPill tone={toneFor(ticket.status)}>{t(`site.track.status.${ticket.status}` as TranslationKey)}</StatusPill>
                <span className={styles.meta}>
                  #{ticket.id} · {formatDateTime(ticket.createdAt)}
                </span>
              </header>
              <ol className={styles.thread} aria-label={t('site.track.chat')}>
                {query.data.messages.map((m) => (
                  <li key={m.id} className={`${styles.msg} ${m.fromStaff ? styles.staff : styles.me}`}>
                    <span className={styles.who}>
                      {t(m.fromStaff ? 'site.track.staff' : 'site.track.you')} · {formatDateTime(m.createdAt)}
                    </span>
                    <p dir="auto">{m.text}</p>
                  </li>
                ))}
              </ol>
              {ticket.status === 'CLOSED' && <p className={styles.note}>{t('site.track.closedNote')}</p>}
              <form className={styles.form} onSubmit={onSubmit}>
                <label htmlFor="track-reply" className={styles.formLabel}>
                  {t('site.track.replyLabel')}
                </label>
                <Textarea
                  id="track-reply"
                  rows={4}
                  dir="auto"
                  value={text}
                  maxLength={MESSAGE_MAX}
                  onChange={(e) => setText(e.target.value)}
                />
                {reply.error && (
                  <p className={styles.err} role="alert">
                    {errorMessage(i18n, reply.error)}
                  </p>
                )}
                {sent && (
                  <p className={styles.ok} role="status">
                    {t('site.track.sent')}
                  </p>
                )}
                <Button type="submit" disabled={!text.trim()} loading={reply.isPending}>
                  {t('site.track.send')}
                </Button>
              </form>
            </>
          )}
        </div>
      </section>
    </>
  );
}
