import { useInfiniteQuery } from '@tanstack/react-query';
import { useMemo } from 'react';
import {
  listEventCertificates,
  restoreCertificate,
  revokeCertificate,
  type AdminCertificateRow,
} from '../../../../api/adminEvents';
import { Badge, GuardedAction, LoadMore } from '../../../../components/ui';
import { useI18n } from '../../../../i18n/I18nProvider';
import { eventErrorMessage } from '../errors';
import { PanelState, opsInvalidate, opsKey } from './opsParts';
import styles from './ops.module.css';

/** Sertifika yazdırılacak onay metni (büyük/küçük harf ve Türkçe İ/ı farkı yok sayılır). */
const REVOKE_WORD = 'İPTAL';

/** Sertifikalar: iptal (yazarak onay + sebep; geri alınabilir) ve iptali geri alma. */
export function CertificatesPanel({ eventId }: { eventId: number }) {
  const i18n = useI18n();
  const { t, formatDateTime } = i18n;
  const q = useInfiniteQuery({
    queryKey: opsKey(eventId, 'certificates'),
    queryFn: ({ pageParam }) => listEventCertificates(eventId, { cursor: pageParam, size: 50 }),
    initialPageParam: null as number | null,
    getNextPageParam: (last) => last.nextCursor ?? undefined,
  });
  const items = useMemo(() => q.data?.pages.flatMap((p) => p.items) ?? [], [q.data]);

  function status(c: AdminCertificateRow) {
    if (c.revoked) return <Badge tone="danger">{t('admin.p07.cert.revoked')}</Badge>;
    if (!c.attended) return <Badge tone="warning">{t('admin.p07.cert.notAttended')}</Badge>;
    return <Badge tone="success">{t('admin.p07.cert.valid')}</Badge>;
  }

  return (
    <section
      className={styles.panel}
      aria-label={t('admin.p07.tab.certificates')}
      data-testid="panel-certificates"
    >
      <p className={styles.muted}>{t('admin.p07.cert.hint')}</p>
      <PanelState
        loading={q.isLoading}
        error={q.error}
        onRetry={() => void q.refetch()}
        empty={items.length === 0}
        emptyTitle={t('admin.p07.cert.empty')}
      >
        <ul className={styles.cards}>
          {items.map((c) => (
            <li key={c.id} className={styles.card} data-testid={`cert-${c.userId}`}>
              <div className={styles.cardMain}>
                <span className={styles.name} dir="auto">
                  {c.holderName}
                </span>
                <span className={`${styles.sub} ltr`}>{c.emailMasked ?? '—'}</span>
                <span className={styles.sub}>
                  {t('admin.p07.cert.code')}: <span className="ltr">{c.codeHint}</span> ·{' '}
                  {formatDateTime(c.issuedAt)}
                </span>
                {c.revoked && c.revokeReason && (
                  <span className={styles.sub}>
                    {t('admin.p07.cert.reason')}: {c.revokeReason}
                  </span>
                )}
              </div>
              <div className={styles.actions}>
                {status(c)}
                {c.revoked ? (
                  <GuardedAction
                    size="sm"
                    variant="secondary"
                    title={t('admin.p07.cert.restore.title', { name: c.holderName })}
                    consequence={t('admin.p07.cert.restore.consequence')}
                    irreversible={false}
                    requireReason
                    confirmLabel={t('admin.p07.cert.restore.confirm')}
                    errorMessage={(e) => eventErrorMessage(i18n, e)}
                    successMessage={t('admin.p07.cert.restore.done')}
                    invalidateKeys={opsInvalidate(eventId)}
                    onConfirm={({ reason, idempotencyKey }) =>
                      restoreCertificate(eventId, c.userId, { reason, idempotencyKey })
                    }
                  >
                    {t('admin.p07.cert.restore')}
                  </GuardedAction>
                ) : (
                  <GuardedAction
                    size="sm"
                    variant="danger"
                    danger
                    title={t('admin.p07.cert.revoke.title', { name: c.holderName })}
                    consequence={t('admin.p07.cert.revoke.consequence')}
                    irreversible={false}
                    requireReason
                    typeToConfirm={REVOKE_WORD}
                    confirmLabel={t('admin.p07.cert.revoke.confirm')}
                    errorMessage={(e) => eventErrorMessage(i18n, e)}
                    successMessage={t('admin.p07.cert.revoke.done')}
                    invalidateKeys={opsInvalidate(eventId)}
                    onConfirm={({ reason, idempotencyKey }) =>
                      revokeCertificate(eventId, c.userId, { reason, idempotencyKey })
                    }
                  >
                    {t('admin.p07.cert.revoke')}
                  </GuardedAction>
                )}
              </div>
            </li>
          ))}
        </ul>
        <LoadMore
          hasMore={!!q.hasNextPage}
          loading={q.isFetchingNextPage}
          onLoadMore={() => void q.fetchNextPage()}
        />
      </PanelState>
    </section>
  );
}
