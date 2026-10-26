// SAYFA: Mesaj çözme ve şifreleme durumu (/admin/crypto)
// API: GET /api/admin/crypto/status (anahtar kimlikleri, ana anahtar başına DEK sayısı; sır yok),
//      POST /api/admin/messages/decrypt {conversationId, fromMessageId, toMessageId?, reason>=10} (api/crypto.ts).
// Her çözme isteği düz metin dönmeden ÖNCE değiştirilemez erişim denetim kaydına yazılır; yalnızca JWT'li ADMIN (saatte 30 istek).
// Düz metin yalnızca bileşen durumunda tutulur (önbelleğe/depoya yazılmaz) ve sayfadan çıkınca silinir.
import { useMutation, useQuery } from '@tanstack/react-query';
import { useEffect, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { cryptoApi, qk } from '../../api';
import {
  Badge,
  Button,
  Card,
  Checkbox,
  EmptyState,
  ErrorState,
  FormField,
  Input,
  PageHeader,
  Skeleton,
  Textarea,
  useToast,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import { adminErrorMessage, Callout } from './campaigns/shared';
import {
  DECRYPT_MAX_MESSAGES,
  DECRYPT_MAX_REASON,
  DECRYPT_MIN_REASON,
  buildDecryptRequest,
  validateDecrypt,
  type DecryptForm,
} from './moderation/modLogic';
import styles from './moderation/moderation.module.css';

export default function CryptoPage() {
  const i18n = useI18n();
  const { t, formatDateTime, formatNumber } = i18n;
  usePageTitle(t('admin.crypto.title'));
  const toast = useToast();
  const [params] = useSearchParams();
  const [form, setForm] = useState<DecryptForm>({
    conversationId: params.get('conversationId') ?? '',
    fromMessageId: params.get('from') ?? '',
    toMessageId: params.get('to') ?? '',
    reason: '',
  });
  const [ack, setAck] = useState(false);
  const [touched, setTouched] = useState(false);

  const status = useQuery({ queryKey: qk.crypto.status(), queryFn: cryptoApi.getCryptoStatus });
  const disabled = status.data ? !status.data.adminDecryptEnabled : false;

  const decrypt = useMutation({
    mutationFn: () => cryptoApi.decryptMessages(buildDecryptRequest(form)),
    onError: (e) => toast.error(adminErrorMessage(i18n, e)),
  });
  // Sayfadan çıkınca düz metin bellekten atılır
  const { reset } = decrypt;
  useEffect(() => () => reset(), [reset]);

  const err = validateDecrypt(form);
  const set = (k: keyof DecryptForm) => (e: { target: { value: string } }) =>
    setForm((f) => ({ ...f, [k]: e.target.value }));
  const errFor = (field: 'reason' | 'conversation' | 'range') => {
    if (!touched || !err) return null;
    if (field === 'reason' && (err === 'reasonShort' || err === 'reasonLong')) {
      return t(err === 'reasonShort' ? 'admin.crypto.err.reasonShort' : 'admin.crypto.err.reasonLong', {
        min: DECRYPT_MIN_REASON,
        max: DECRYPT_MAX_REASON,
      });
    }
    if (field === 'conversation' && err === 'conversation') return t('admin.crypto.err.conversation');
    if (field === 'range' && err === 'range') return t('admin.crypto.err.range');
    return null;
  };

  const data = decrypt.data;

  return (
    <>
      <PageHeader title={t('admin.crypto.title')} />
      <div className={styles.stack}>
        <section className={styles.warnBox} aria-labelledby="crypto-warn" data-testid="decrypt-warning">
          <h2 id="crypto-warn">{t('admin.crypto.warn.title')}</h2>
          <p>{t('admin.crypto.warn.body')}</p>
          <p>{t('admin.crypto.warn.audit')}</p>
        </section>

        <Card title={t('admin.crypto.status.title')}>
          {status.isError ? (
            <ErrorState compact description={adminErrorMessage(i18n, status.error)} onRetry={() => void status.refetch()} />
          ) : status.isLoading || !status.data ? (
            <Skeleton height="6rem" width="100%" />
          ) : (
            <>
              <dl className={styles.statGrid}>
                <div>
                  <dt className={styles.muted}>{t('admin.crypto.status.active')}</dt>
                  <dd className="ltr">
                    <code>{status.data.activeKeyId}</code>
                  </dd>
                </div>
                <div>
                  <dt className={styles.muted}>{t('admin.crypto.status.keys')}</dt>
                  <dd className="ltr">{status.data.keyIds.join(', ')}</dd>
                </div>
                <div>
                  <dt className={styles.muted}>{t('admin.crypto.status.decrypt')}</dt>
                  <dd>
                    <Badge tone={status.data.adminDecryptEnabled ? 'success' : 'danger'}>
                      {t(status.data.adminDecryptEnabled ? 'admin.crypto.status.on' : 'admin.crypto.status.off')}
                    </Badge>
                  </dd>
                </div>
              </dl>
              {status.data.devKey && (
                <Callout tone="danger" role="alert" title={t('admin.crypto.status.devKeyTitle')}>
                  {t('admin.crypto.status.devKey')}
                </Callout>
              )}
              <h3 className={styles.muted}>{t('admin.crypto.status.deks')}</h3>
              <ul className={styles.msgList}>
                {Object.entries(status.data.dekCountsByMasterKey).map(([k, n]) => (
                  <li key={k} className={styles.msgMeta}>
                    <code className="ltr">{k}</code>
                    <strong>{formatNumber(n)}</strong>
                    {k !== status.data.activeKeyId && <Badge tone="warning">{t('admin.crypto.status.rewrapNeeded')}</Badge>}
                  </li>
                ))}
              </ul>
            </>
          )}
        </Card>

        <Card title={t('admin.crypto.form.title')}>
          {disabled && (
            <Callout tone="warning" role="status">
              {t('admin.crypto.disabled')}
            </Callout>
          )}
          <form
            className={styles.formGrid}
            onSubmit={(e) => {
              e.preventDefault();
              setTouched(true);
              if (!err && ack && !disabled) decrypt.mutate();
            }}
          >
            <FormField label={t('admin.crypto.form.conversation')} error={errFor('conversation')} required>
              <Input className="ltr" inputMode="numeric" value={form.conversationId} onChange={set('conversationId')} />
            </FormField>
            <FormField label={t('admin.crypto.form.from')} error={errFor('range')} required>
              <Input className="ltr" inputMode="numeric" value={form.fromMessageId} onChange={set('fromMessageId')} />
            </FormField>
            <FormField
              label={t('admin.crypto.form.to')}
              hint={t('admin.crypto.form.toHint', { max: DECRYPT_MAX_MESSAGES })}
            >
              <Input className="ltr" inputMode="numeric" value={form.toMessageId} onChange={set('toMessageId')} />
            </FormField>
            <div className={styles.wide}>
              <FormField
                label={t('admin.crypto.form.reason')}
                hint={t('admin.crypto.form.reasonHint', { min: DECRYPT_MIN_REASON })}
                error={errFor('reason')}
                required
              >
                <Textarea rows={3} dir="auto" value={form.reason} maxLength={DECRYPT_MAX_REASON + 50} onChange={set('reason')} />
              </FormField>
            </div>
            <div className={styles.wide}>
              <Checkbox
                checked={ack}
                onChange={(e) => setAck(e.target.checked)}
                label={t('admin.crypto.form.ack')}
              />
            </div>
            <div className={styles.wide}>
              <Button type="submit" variant="danger" loading={decrypt.isPending} disabled={!ack || disabled}>
                {t('admin.crypto.form.submit')}
              </Button>
            </div>
          </form>
        </Card>

        {data && (
          <Card title={t('admin.crypto.result.title', { n: formatNumber(data.count) })}>
            <p className={styles.muted} role="status">
              {t('admin.crypto.result.audit', { id: data.auditId })}
            </p>
            {data.messages.length === 0 ? (
              <EmptyState compact icon="message" title={t('admin.crypto.result.empty')} description=" " />
            ) : (
              <ul className={styles.msgList}>
                {data.messages.map((m) => (
                  <li key={m.id} className={styles.msg}>
                    <div className={styles.msgMeta}>
                      <span className="ltr">#{m.id}</span>
                      <span>{t('admin.crypto.result.sender', { id: m.senderId })}</span>
                      <span>{formatDateTime(m.createdAt)}</span>
                    </div>
                    {m.text !== null ? (
                      <p className={styles.body} dir="auto">
                        {m.text}
                      </p>
                    ) : (
                      <p className={styles.muted}>{t('admin.crypto.result.failed', { reason: m.error ?? '?' })}</p>
                    )}
                  </li>
                ))}
              </ul>
            )}
            <div className={styles.actions}>
              <Button variant="secondary" onClick={() => decrypt.reset()}>
                {t('admin.crypto.result.clear')}
              </Button>
            </div>
          </Card>
        )}
      </div>
    </>
  );
}
