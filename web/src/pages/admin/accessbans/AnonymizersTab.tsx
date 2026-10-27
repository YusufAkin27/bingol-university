// VPN/Tor listeleri: GET/POST /api/admin/access-bans/anonymizers, DELETE .../anonymizers/{id}. Ayar bayrağı salt okunurdur.
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import {
  accessBanKeys,
  addAnonymizers,
  listAnonymizers,
  removeAnonymizerSource,
  type AnonymizerSource,
  type BulkResult,
} from '../../../api/accessBans';
import {
  Badge,
  Button,
  Card,
  ConfirmDialog,
  ErrorState,
  FormField,
  Input,
  Skeleton,
  Textarea,
  useToast,
} from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminErrorMessage, Callout } from '../campaigns/shared';
import styles from './accessBans.module.css';
import { BulkResultView } from './BulkTab';
import { parseLines } from './logic';

export function AnonymizersTab() {
  const i18n = useI18n();
  const { t, formatNumber } = i18n;
  const toast = useToast();
  const qc = useQueryClient();
  const [source, setSource] = useState('');
  const [text, setText] = useState('');
  const [touched, setTouched] = useState(false);
  const [result, setResult] = useState<BulkResult | null>(null);
  const [removing, setRemoving] = useState<AnonymizerSource | null>(null);

  const list = useQuery({ queryKey: accessBanKeys.anonymizers(), queryFn: listAnonymizers });
  const lines = parseLines(text);

  const upload = useMutation({
    mutationFn: () => addAnonymizers({ text: lines.join('\n'), source: source.trim() }),
    onSuccess: (r) => {
      setResult(r);
      toast.success(t('admin.ab.toast.added'));
      void qc.invalidateQueries({ queryKey: accessBanKeys.anonymizers() });
    },
    onError: (e) => toast.error(adminErrorMessage(i18n, e)),
  });
  const remove = useMutation({
    mutationFn: (s: AnonymizerSource) => removeAnonymizerSource(s.source),
    onSuccess: () => {
      toast.success(t('admin.ab.anon.toast.removed'));
      setRemoving(null);
      void qc.invalidateQueries({ queryKey: accessBanKeys.anonymizers() });
    },
    onError: (e) => {
      toast.error(adminErrorMessage(i18n, e));
      setRemoving(null);
    },
  });

  const sourceMissing = source.trim() === '';

  return (
    <div className={styles.stack}>
      <Callout tone="info">{t('admin.ab.anon.info')}</Callout>

      <Card title={t('admin.ab.anon.setting')}>
        {list.data ? (
          <p>
            <Badge tone={list.data.enforced ? 'success' : 'neutral'}>
              {list.data.enforced ? t('admin.ab.anon.on') : t('admin.ab.anon.off')}
            </Badge>{' '}
            <span className={styles.muted}>{t('admin.ab.anon.settingHint')}</span>
          </p>
        ) : (
          <Skeleton width="40%" />
        )}
      </Card>

      <Card title={t('admin.ab.anon.upload')}>
        <form
          noValidate
          className={styles.form}
          onSubmit={(e) => {
            e.preventDefault();
            setTouched(true);
            if (!sourceMissing && lines.length > 0) upload.mutate();
          }}
        >
          <FormField
            label={t('admin.ab.anon.source')}
            error={touched && sourceMissing ? t('admin.ab.anon.sourceRequired') : null}
            required
          >
            <Input
              className="ltr"
              value={source}
              maxLength={64}
              placeholder={t('admin.ab.anon.sourcePh')}
              onChange={(e) => setSource(e.target.value)}
            />
          </FormField>
          <FormField label={t('admin.ab.anon.lines')} hint={t('admin.ab.bulk.preview', { n: formatNumber(lines.length) })}>
            <Textarea
              className={`${styles.textarea} ltr`}
              rows={8}
              spellCheck={false}
              value={text}
              onChange={(e) => {
                setText(e.target.value);
                setResult(null);
              }}
            />
          </FormField>
          <div>
            <Button type="submit" loading={upload.isPending} disabled={lines.length === 0}>
              {t('admin.ab.anon.submit')}
            </Button>
          </div>
        </form>
        {result && <BulkResultView result={result} />}
      </Card>

      <Card title={t('admin.ab.anon.current')}>
        {list.isError ? (
          <ErrorState compact description={adminErrorMessage(i18n, list.error)} onRetry={() => void list.refetch()} />
        ) : list.isLoading ? (
          <Skeleton height="4rem" width="100%" />
        ) : list.data && list.data.items.length === 0 ? (
          <p className={styles.muted}>{t('admin.ab.anon.empty')}</p>
        ) : (
          <ul className={styles.list}>
            {list.data?.items.map((s) => (
              <li key={s.source}>
                <span>
                  <strong className="ltr">{s.source || t('admin.ab.anon.noLabel')}</strong>{' '}
                  <span className={styles.muted}>{t('admin.ab.anon.count', { n: formatNumber(s.count) })}</span>
                </span>
                <Button size="sm" variant="danger" onClick={() => setRemoving(s)}>
                  {t('admin.ab.remove')}
                </Button>
              </li>
            ))}
          </ul>
        )}
      </Card>

      <ConfirmDialog
        open={!!removing}
        onClose={() => setRemoving(null)}
        onConfirm={() => removing && remove.mutate(removing)}
        loading={remove.isPending}
        danger
        title={t('admin.ab.anon.removeTitle')}
        message={t('admin.ab.anon.removeBody')}
        confirmLabel={t('admin.ab.remove')}
      />
    </div>
  );
}
