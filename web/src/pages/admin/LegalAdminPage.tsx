// SAYFA: Sözleşmeler (/admin/content/legal)
// API: GET /api/legal, GET /api/admin/legal/{type}/versions, GET /api/admin/legal/acceptance-stats,
//      POST /api/admin/legal/{type} {tr, en?, ar?, requireReaccept} (api/legal.ts). Yayın geri alınamaz.
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { legalApi, qk } from '../../api';
import type { Lang, LegalType, LegalVersionRow } from '../../api/types';
import {
  Badge,
  Button,
  EmptyState,
  ErrorState,
  FormField,
  Input,
  MarkdownText,
  Modal,
  PageHeader,
  Skeleton,
  StatusPill,
  Switch,
  Table,
  Tabs,
  useToast,
  type Column,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { errorMessage } from '../../lib/errors';
import { usePageTitle } from '../../lib/hooks';
import { MarkdownEditor } from './content/MarkdownEditor';
import { useUnsavedGuard } from './content/useUnsavedGuard';
import {
  LEGAL_LANGS,
  LEGAL_TYPES,
  MAX_CONTENT,
  MAX_TITLE,
  acceptanceRatio,
  activeVersion,
  buildPublishRequest,
  emptyDrafts,
  isDirty,
  isFilled,
  nextVersion,
  type LegalDrafts,
} from './content/legalLogic';
import styles from './content/Legal.module.css';

export default function LegalAdminPage() {
  const i18n = useI18n();
  const { t, formatDate, formatNumber } = i18n;
  usePageTitle(t('admin.legal.title'));
  const toast = useToast();
  const qc = useQueryClient();

  const [type, setType] = useState<LegalType>('TERMS');
  const [tab, setTab] = useState<'history' | 'editor'>('history');
  const [lang, setLang] = useState<Lang>('tr');
  const [drafts, setDrafts] = useState<LegalDrafts>(emptyDrafts);
  const [reaccept, setReaccept] = useState(true);
  const [showErrors, setShowErrors] = useState(false);
  const [publishOpen, setPublishOpen] = useState(false);
  const [viewRow, setViewRow] = useState<LegalVersionRow | null>(null);

  const summaries = useQuery({ queryKey: qk.legal.list(), queryFn: legalApi.listLegal });
  const stats = useQuery({ queryKey: qk.legal.acceptance(), queryFn: legalApi.getLegalAcceptanceStats });
  const versions = useQuery({ queryKey: qk.legal.versions(type), queryFn: () => legalApi.listLegalVersions(type) });

  const dirty = isDirty(drafts);
  useUnsavedGuard(dirty, t('admin.legal.leaveConfirm'));

  const built = useMemo(() => buildPublishRequest(drafts, reaccept), [drafts, reaccept]);
  const rows = versions.data ?? [];

  const publish = useMutation({
    mutationFn: () => legalApi.publishLegal(type, built.request!),
    onSuccess: (r) => {
      toast.success(t('admin.legal.publish.done', { n: r.version }));
      setPublishOpen(false);
      setDrafts(emptyDrafts());
      setShowErrors(false);
      setTab('history');
      void qc.invalidateQueries({ queryKey: qk.legal.all });
    },
    onError: (e) => {
      toast.error(errorMessage(i18n, e));
      setPublishOpen(false);
    },
  });

  function selectType(next: LegalType) {
    if (next === type) return;
    if (dirty && !window.confirm(t('admin.legal.leaveConfirm'))) return;
    setDrafts(emptyDrafts());
    setShowErrors(false);
    setLang('tr');
    setType(next);
  }

  function setField(field: 'title' | 'content', v: string) {
    setDrafts((d) => ({ ...d, [lang]: { ...d[lang], [field]: v } }));
  }

  function copyPrevious() {
    const prev = activeVersion(rows, lang) ?? rows.find((r) => r.lang === lang) ?? null;
    if (!prev) {
      toast.info(t('admin.legal.copyPrev.none'));
      return;
    }
    setDrafts((d) => ({ ...d, [lang]: { title: prev.title, content: prev.content } }));
    toast.success(t('admin.legal.copyPrev.done'));
  }

  function requestPublish() {
    setShowErrors(true);
    if (built.request) setPublishOpen(true);
  }

  const columns: Column<LegalVersionRow>[] = [
    { key: 'version', header: t('admin.legal.history.col.version'), render: (r) => <strong>{r.version}</strong>, width: '5rem' },
    { key: 'lang', header: t('admin.legal.history.col.lang'), render: (r) => t(`admin.legal.lang.${r.lang}`) },
    { key: 'title', header: t('admin.legal.history.col.title'), render: (r) => <span dir="auto">{r.title}</span> },
    {
      key: 'reaccept',
      header: t('admin.legal.history.col.reaccept'),
      render: (r) => (r.requireReaccept ? t('common.yes') : t('common.no')),
    },
    { key: 'published', header: t('admin.legal.history.col.published'), render: (r) => formatDate(r.publishedAt, { dateStyle: 'medium', timeStyle: 'short' }) },
    {
      key: 'status',
      header: t('admin.legal.history.col.status'),
      render: (r) =>
        r.active ? (
          <StatusPill tone="success">{t('admin.legal.history.active')}</StatusPill>
        ) : (
          <StatusPill tone="neutral">{t('admin.legal.history.old')}</StatusPill>
        ),
    },
    {
      key: 'view',
      header: <span className="sr-only">{t('common.actions')}</span>,
      align: 'end',
      render: (r) => (
        <Button size="sm" variant="ghost" onClick={() => setViewRow(r)}>
          {t('admin.legal.history.view')}
        </Button>
      ),
    },
  ];

  const errorText = (code: string) => t(`admin.legal.err.${code}` as 'admin.legal.err.trRequired');
  const d = drafts[lang];
  const dirAttr = lang === 'ar' ? 'rtl' : 'ltr';
  const langLabel = (l: Lang) => t(`admin.legal.lang.${l}`);

  return (
    <>
      <PageHeader title={t('admin.legal.title')} />

      {summaries.isError && (
        <ErrorState compact onRetry={() => void summaries.refetch()} description={errorMessage(i18n, summaries.error)} />
      )}

      <div className={styles.cards} role="group" aria-label={t('admin.legal.types')}>
        {LEGAL_TYPES.map((ty) => {
          const sum = summaries.data?.find((s) => s.type === ty);
          const st = stats.data?.find((s) => s.type === ty);
          const ratio = st ? acceptanceRatio(st.accepted, st.totalActiveUsers) : 0;
          const pct = Math.round(ratio * 100);
          return (
            <button
              key={ty}
              type="button"
              className={`${styles.typeCard} ${ty === type ? styles.selected : ''}`}
              aria-pressed={ty === type}
              onClick={() => selectType(ty)}
              data-type={ty}
            >
              <span className={styles.typeName}>{t(`admin.legal.type.${ty}`)}</span>
              {summaries.isLoading ? (
                <Skeleton width="50%" />
              ) : sum ? (
                <span className={styles.typeMeta}>
                  <Badge tone="primary">{t('admin.legal.version', { n: sum.version })}</Badge>
                  <span>{t('admin.legal.publishedAt', { date: formatDate(sum.publishedAt) })}</span>
                </span>
              ) : (
                <span className={styles.typeMeta}>{t('admin.legal.noVersion')}</span>
              )}
              <span className={styles.accept}>
                <span className={styles.acceptHead}>
                  <span>{t('admin.legal.acceptance')}</span>
                  <strong className="ltr">{st ? `${formatNumber(pct)}%` : '—'}</strong>
                </span>
                <span
                  className={styles.bar}
                  role="progressbar"
                  aria-label={`${t('admin.legal.acceptance')}: ${t(`admin.legal.type.${ty}`)}`}
                  aria-valuemin={0}
                  aria-valuemax={100}
                  aria-valuenow={pct}
                >
                  <span className={styles.barFill} style={{ inlineSize: `${pct}%` }} />
                </span>
                {st && (
                  <span className={styles.acceptCount}>
                    {t('admin.legal.acceptanceCount', {
                      accepted: formatNumber(st.accepted),
                      total: formatNumber(st.totalActiveUsers),
                    })}
                  </span>
                )}
              </span>
            </button>
          );
        })}
      </div>

      <div className={styles.section}>
        <Tabs
          label={t('admin.legal.tabs')}
          value={tab}
          onChange={(id) => setTab(id as 'history' | 'editor')}
          tabs={[
            { id: 'history', label: t('admin.legal.tab.history') },
            {
              id: 'editor',
              label: (
                <span className={styles.tabLabel}>
                  {t('admin.legal.tab.editor')}
                  {dirty && <span className={styles.dot} aria-hidden="true" />}
                </span>
              ),
            },
          ]}
        />

        {/* Düzenleyici açık kalır: sekme değişince taslak kaybolmaz */}
        <div hidden={tab !== 'history'} className={styles.pane}>
          {versions.isError ? (
            <ErrorState onRetry={() => void versions.refetch()} description={errorMessage(i18n, versions.error)} />
          ) : (
            <Table
              caption={t('admin.legal.tab.history')}
              columns={columns}
              rows={rows}
              rowKey={(r) => `${r.version}-${r.lang}`}
              loading={versions.isLoading}
              empty={<EmptyState compact icon="file" title={t('admin.legal.history.empty')} description=" " />}
            />
          )}
        </div>

        <div hidden={tab !== 'editor'} className={styles.pane}>
          <div className={styles.editorTop}>
            <Tabs
              label={t('admin.legal.editor.langs')}
              value={lang}
              onChange={(id) => setLang(id as Lang)}
              tabs={LEGAL_LANGS.map((l) => ({
                id: l,
                label: (
                  <span className={styles.tabLabel}>
                    {langLabel(l)}
                    {l === 'tr' ? (
                      <small className={styles.req}>{t('admin.legal.editor.required')}</small>
                    ) : isFilled(drafts[l]) ? (
                      <Badge tone="success">{l.toUpperCase()}</Badge>
                    ) : null}
                  </span>
                ),
              }))}
            />
            <div className={styles.topActions}>
              <Button size="sm" variant="secondary" onClick={copyPrevious} disabled={versions.isLoading}>
                {t('admin.legal.copyPrev')}
              </Button>
              <Button size="sm" variant="ghost" onClick={() => setDrafts(emptyDrafts())} disabled={!dirty}>
                {t('admin.legal.clear')}
              </Button>
            </div>
          </div>

          <FormField label={t('admin.legal.editor.title')} required={lang === 'tr'}>
            <Input
              value={d.title}
              dir={dirAttr}
              maxLength={MAX_TITLE}
              onChange={(e) => setField('title', e.target.value)}
            />
          </FormField>

          <div className={styles.split}>
            <div className={styles.col}>
              <label htmlFor="legal-content" className={styles.colLabel}>
                {t('admin.legal.editor.content')}
                <span className={styles.chars}>{t('admin.legal.editor.chars', { n: formatNumber(d.content.length) })}</span>
              </label>
              <MarkdownEditor
                id="legal-content"
                value={d.content}
                dir={dirAttr}
                maxLength={MAX_CONTENT}
                onChange={(v) => setField('content', v)}
              />
            </div>
            <div className={styles.col}>
              <span className={styles.colLabel}>{t('admin.legal.editor.preview')}</span>
              <div className={styles.preview} dir={dirAttr} aria-label={t('admin.legal.editor.preview')}>
                {d.title.trim() && <h2 className={styles.previewTitle}>{d.title}</h2>}
                {d.content.trim() ? (
                  <MarkdownText text={d.content} />
                ) : (
                  <p className={styles.previewEmpty}>{t('admin.legal.editor.previewEmpty')}</p>
                )}
              </div>
            </div>
          </div>

          <div className={styles.reaccept}>
            <Switch checked={reaccept} onChange={setReaccept} label={t('admin.legal.reaccept.label')} />
            <p className={styles.hint}>{t('admin.legal.reaccept.hint')}</p>
          </div>

          {dirty && <p className={styles.warn}>{t('admin.legal.dirty')}</p>}
          {showErrors && built.errors.length > 0 && (
            <ul className={styles.errors} role="alert">
              {built.errors.map((e) => (
                <li key={e}>{errorText(e)}</li>
              ))}
            </ul>
          )}

          <div className={styles.publishRow}>
            <Button onClick={requestPublish} disabled={!dirty} loading={publish.isPending}>
              {t('admin.legal.publish')}
            </Button>
          </div>
        </div>
      </div>

      <Modal
        open={publishOpen}
        onClose={() => setPublishOpen(false)}
        title={t('admin.legal.publish.title')}
        size="md"
        footer={
          <>
            <Button variant="secondary" onClick={() => setPublishOpen(false)}>
              {t('common.cancel')}
            </Button>
            <Button variant="danger" loading={publish.isPending} onClick={() => publish.mutate()} data-autofocus>
              {t('admin.legal.publish.confirm')}
            </Button>
          </>
        }
      >
        <dl className={styles.summary}>
          <div>
            <dt>{t('admin.legal.publish.type')}</dt>
            <dd>{t(`admin.legal.type.${type}`)}</dd>
          </div>
          <div>
            <dt>{t('admin.legal.publish.newVersion')}</dt>
            <dd>{nextVersion(rows)}</dd>
          </div>
          <div>
            <dt>{t('admin.legal.publish.langs')}</dt>
            <dd>{built.included.map(langLabel).join(', ')}</dd>
          </div>
          <div>
            <dt>{t('admin.legal.publish.fallbackLangs')}</dt>
            <dd>{built.fallbackLangs.length ? built.fallbackLangs.map(langLabel).join(', ') : t('admin.legal.publish.none')}</dd>
          </div>
          <div>
            <dt>{t('admin.legal.publish.reacceptLabel')}</dt>
            <dd>{reaccept ? t('admin.legal.publish.reacceptOn') : t('admin.legal.publish.reacceptOff')}</dd>
          </div>
        </dl>
        <p className={styles.irreversible}>{t('admin.legal.publish.irreversible')}</p>
      </Modal>

      <Modal
        open={!!viewRow}
        onClose={() => setViewRow(null)}
        size="lg"
        title={
          viewRow
            ? t('admin.legal.history.viewTitle', { n: viewRow.version, lang: langLabel(viewRow.lang) })
            : ''
        }
      >
        {viewRow && (
          <div dir={viewRow.lang === 'ar' ? 'rtl' : 'ltr'}>
            <h3>{viewRow.title}</h3>
            <MarkdownText text={viewRow.content} />
          </div>
        )}
      </Modal>
    </>
  );
}
