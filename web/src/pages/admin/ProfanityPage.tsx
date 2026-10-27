// SAYFA: Uygunsuz ifade filtresi (/admin/profanity)
// API: /api/admin/profanity (liste/ekle/toplu/sil/check/info/stats/export.csv) -> api/profanity.ts.
// Yerleşik liste kaynak dosyadadır ve silinemez; yönetici BLOCK/ALLOW kayıtları buradan yönetilir.
import { useInfiniteQuery, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import {
  addBulk,
  addTerm,
  checkText,
  exportCsv,
  getInfo,
  getStats,
  listTerms,
  PROFANITY_LANGS,
  profanityKeys,
  removeTerm,
  type ProfanityKind,
  type ProfanityLang,
  type ProfanityTerm,
} from '../../api/profanity';
import {
  Button,
  Card,
  ConfirmDialog,
  EmptyState,
  ErrorState,
  FormField,
  Input,
  LoadMore,
  PageHeader,
  Select,
  Skeleton,
  StatCard,
  Tabs,
  Textarea,
  useToast,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import { adminErrorMessage } from './campaigns/shared';
import styles from './moderation/moderation.module.css';
import { downloadBlob } from './users/filters';

const NOTE_MAX = 200;

export default function ProfanityPage() {
  const i18n = useI18n();
  const { t, formatDateTime, formatNumber } = i18n;
  usePageTitle(t('admin.prf.title'));
  const toast = useToast();
  const qc = useQueryClient();
  const [kind, setKind] = useState<ProfanityKind>('BLOCK');
  const [q, setQ] = useState('');
  const [term, setTerm] = useState('');
  const [lang, setLang] = useState<ProfanityLang>('ALL');
  const [note, setNote] = useState('');
  const [bulk, setBulk] = useState('');
  const [touched, setTouched] = useState(false);
  const [removing, setRemoving] = useState<ProfanityTerm | null>(null);
  const [tryText, setTryText] = useState('');

  const info = useQuery({ queryKey: profanityKeys.info(), queryFn: getInfo });
  const stats = useQuery({ queryKey: profanityKeys.stats(), queryFn: getStats });
  const list = useInfiniteQuery({
    queryKey: profanityKeys.list(kind, q),
    queryFn: ({ pageParam }) => listTerms({ kind, q, cursor: pageParam, size: 50 }),
    initialPageParam: null as number | null,
    getNextPageParam: (p) => p.nextCursor ?? undefined,
  });
  const items = list.data?.pages.flatMap((p) => p.items) ?? [];

  const refresh = () => void qc.invalidateQueries({ queryKey: profanityKeys.all });

  const add = useMutation({
    mutationFn: () => addTerm({ term: term.trim(), kind, lang, note: note.trim() }),
    onSuccess: () => {
      toast.success(t('admin.prf.toast.added'));
      setTerm('');
      setNote('');
      setTouched(false);
      refresh();
    },
    onError: (e) => toast.error(adminErrorMessage(i18n, e)),
  });
  const addMany = useMutation({
    mutationFn: () => addBulk({ text: bulk, kind, lang }),
    onSuccess: (r) => {
      toast.success(t('admin.prf.bulkResult', { added: r.added, skipped: r.skipped, invalid: r.invalid }));
      setBulk('');
      refresh();
    },
    onError: (e) => toast.error(adminErrorMessage(i18n, e)),
  });
  const remove = useMutation({
    mutationFn: (x: ProfanityTerm) => removeTerm(x.id),
    onSuccess: () => {
      toast.success(t('admin.prf.toast.removed'));
      setRemoving(null);
      refresh();
    },
    onError: (e) => {
      toast.error(adminErrorMessage(i18n, e));
      setRemoving(null);
      refresh();
    },
  });
  const check = useMutation({ mutationFn: () => checkText(tryText), onError: (e) => toast.error(adminErrorMessage(i18n, e)) });
  const exporter = useMutation({
    mutationFn: () => exportCsv(kind),
    onSuccess: (blob) => downloadBlob(blob, `profanity-${kind.toLowerCase()}.csv`),
    onError: (e) => toast.error(adminErrorMessage(i18n, e)),
  });

  const termInvalid = term.trim().length < 2 || term.trim().length > 80;
  const b = info.data?.builtIn;

  return (
    <>
      <PageHeader title={t('admin.prf.title')} description={t('admin.prf.intro')} />
      <div className={styles.stack}>
        {info.isError ? (
          <ErrorState compact description={adminErrorMessage(i18n, info.error)} onRetry={() => void info.refetch()} />
        ) : (
          <Card>
            {info.isLoading || !b ? (
              <Skeleton height="3rem" width="100%" />
            ) : (
              <div className={styles.stack}>
                <p>
                  {t('admin.prf.builtIn', {
                    total: formatNumber(b.tr + b.en + b.ar),
                    tr: b.tr,
                    en: b.en,
                    ar: b.ar,
                    source: b.source,
                  })}
                </p>
                <p className={styles.muted}>{t('admin.prf.builtInAllow', { n: b.allow })}</p>
                <p className={styles.muted}>
                  {t('admin.prf.adminCount', { block: info.data!.adminBlock, allow: info.data!.adminAllow })}
                </p>
                <p className={styles.muted}>
                  {t('admin.prf.settings', {
                    state: t(info.data!.settings.enabled ? 'admin.prf.enabled' : 'admin.prf.disabled'),
                    mode: t(`admin.prf.mode.${info.data!.settings.mode}` as const),
                  })}
                </p>
              </div>
            )}
          </Card>
        )}

        <div className={styles.toolbar}>
          <StatCard
            title={t('admin.prf.stat.24h')}
            loading={stats.isLoading}
            value={formatNumber(stats.data?.last24h.total ?? 0)}
          />
          <StatCard
            title={t('admin.prf.stat.7d')}
            loading={stats.isLoading}
            value={formatNumber(stats.data?.last7d.total ?? 0)}
          />
        </div>
        {stats.data && (
          <Card title={t('admin.prf.stat.byField')}>
            {stats.data.last7d.byField.length === 0 ? (
              <p className={styles.muted}>{t('admin.prf.stat.none')}</p>
            ) : (
              <ul className={styles.rowList}>
                {stats.data.last7d.byField.map((r) => (
                  <li key={`${r.entity}.${r.field}`} className={styles.itemHead}>
                    <code className={`${styles.mono} ltr`}>
                      {r.entity} / {r.field}
                    </code>
                    <span className={styles.spacer} />
                    <strong>{formatNumber(r.count)}</strong>
                  </li>
                ))}
              </ul>
            )}
          </Card>
        )}

        <Card title={t('admin.prf.try')}>
          <form
            className={styles.formGrid}
            onSubmit={(e) => {
              e.preventDefault();
              if (tryText.trim()) check.mutate();
            }}
          >
            <div className={styles.wide}>
              <FormField label={t('admin.prf.tryText')} hint={t('admin.prf.tryHint')}>
                <Textarea value={tryText} maxLength={20000} dir="auto" onChange={(e) => setTryText(e.target.value)} />
              </FormField>
            </div>
            <div>
              <Button type="submit" loading={check.isPending} disabled={!tryText.trim()}>
                {t('admin.prf.tryBtn')}
              </Button>
            </div>
          </form>
          {check.data && (
            <div className={styles.stack} role="status">
              <strong>{t(check.data.blocked ? 'admin.prf.tryBlocked' : 'admin.prf.tryClean')}</strong>
              {check.data.blocked && (
                <p className={styles.body} dir="auto">
                  {t('admin.prf.tryMatches')}: {check.data.matches.join(', ')}
                </p>
              )}
              <p className={styles.muted} dir="auto">
                {t('admin.prf.tryNormalized')}: {check.data.normalized}
              </p>
            </div>
          )}
        </Card>

        <Tabs
          label={t('admin.prf.tabs')}
          value={kind}
          onChange={(id) => setKind(id as ProfanityKind)}
          tabs={[
            { id: 'BLOCK', label: t('admin.prf.tab.BLOCK') },
            { id: 'ALLOW', label: t('admin.prf.tab.ALLOW') },
          ]}
        />

        <Card title={t('admin.prf.add')}>
          <form
            className={styles.formGrid}
            onSubmit={(e) => {
              e.preventDefault();
              setTouched(true);
              if (!termInvalid) add.mutate();
            }}
          >
            <div className={styles.wide}>
              <FormField
                label={t('admin.prf.term')}
                hint={t('admin.prf.termHint')}
                error={touched && termInvalid ? t('admin.prf.termInvalid') : null}
                required
              >
                <Input value={term} maxLength={80} dir="auto" autoComplete="off" onChange={(e) => setTerm(e.target.value)} />
              </FormField>
            </div>
            <FormField label={t('admin.prf.language')}>
              <Select value={lang} onChange={(e) => setLang(e.target.value as ProfanityLang)}>
                {PROFANITY_LANGS.map((l) => (
                  <option key={l} value={l}>
                    {t(`admin.prf.lang.${l}` as const)}
                  </option>
                ))}
              </Select>
            </FormField>
            <div className={styles.wide}>
              <FormField label={t('admin.prf.note')}>
                <Input value={note} maxLength={NOTE_MAX} dir="auto" onChange={(e) => setNote(e.target.value)} />
              </FormField>
            </div>
            <div>
              <Button type="submit" loading={add.isPending}>
                {t('admin.prf.addBtn')}
              </Button>
            </div>
          </form>
          <form
            className={styles.formGrid}
            onSubmit={(e) => {
              e.preventDefault();
              if (bulk.trim()) addMany.mutate();
            }}
          >
            <div className={styles.wide}>
              <FormField label={t('admin.prf.bulk')}>
                <Textarea value={bulk} maxLength={20000} dir="auto" rows={5} onChange={(e) => setBulk(e.target.value)} />
              </FormField>
            </div>
            <div>
              <Button type="submit" variant="secondary" loading={addMany.isPending} disabled={!bulk.trim()}>
                {t('admin.prf.bulkBtn')}
              </Button>
            </div>
          </form>
        </Card>

        <div className={styles.toolbar}>
          <FormField label={t('admin.prf.search')}>
            <Input value={q} maxLength={80} dir="auto" onChange={(e) => setQ(e.target.value)} />
          </FormField>
          <Button variant="secondary" loading={exporter.isPending} onClick={() => exporter.mutate()}>
            {t('admin.prf.export')}
          </Button>
        </div>

        {list.isError ? (
          <ErrorState description={adminErrorMessage(i18n, list.error)} onRetry={() => void list.refetch()} />
        ) : list.isLoading ? (
          <Skeleton height="5rem" width="100%" />
        ) : items.length === 0 ? (
          <EmptyState icon="shield" title={t('admin.prf.empty.title')} description={t('admin.prf.empty.hint')} />
        ) : (
          <>
            <ul className={styles.rowList} aria-label={t(`admin.prf.tab.${kind}` as const)}>
              {items.map((e) => (
                <li key={e.id} className={styles.item}>
                  <div className={styles.itemHead}>
                    <code className={`${styles.mono} ltr`} dir="auto">
                      {e.term}
                    </code>
                    <span className={styles.muted}>{t(`admin.prf.lang.${e.lang}` as const)}</span>
                    <span className={styles.spacer} />
                    <Button size="sm" variant="danger" onClick={() => setRemoving(e)}>
                      {t('admin.prf.remove')}
                    </Button>
                  </div>
                  {e.note && (
                    <p className={styles.body} dir="auto">
                      {e.note}
                    </p>
                  )}
                  <p className={styles.muted}>
                    {formatDateTime(e.createdAt)}
                    {e.createdBy ? ` · ${t('admin.prf.by', { id: e.createdBy })}` : ''}
                  </p>
                </li>
              ))}
            </ul>
            <LoadMore
              hasMore={!!list.hasNextPage}
              loading={list.isFetchingNextPage}
              onLoadMore={() => void list.fetchNextPage()}
            />
          </>
        )}
      </div>
      <ConfirmDialog
        open={!!removing}
        onClose={() => setRemoving(null)}
        onConfirm={() => removing && remove.mutate(removing)}
        loading={remove.isPending}
        danger
        title={t('admin.prf.removeTitle')}
        message={t('admin.prf.removeBody')}
        confirmLabel={t('admin.prf.remove')}
      />
    </>
  );
}
