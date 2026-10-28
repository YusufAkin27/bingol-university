// SAYFA: Akademik takvim (/admin/academic/calendar)
// API: /api/admin/academic/events (liste/POST/PATCH/DELETE, publish|unpublish, import) -> api/academic.ts.
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState, type FormEvent } from 'react';
import {
  acdKeys,
  CALENDAR_KINDS,
  createEvent,
  deleteEvent,
  importEvents,
  listEvents,
  setEventPublished,
  updateEvent,
  type AcademicEvent,
  type AcademicEventInput,
  type CalendarKind,
  type EventImportResult,
} from '../../../api/academic';
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
  Modal,
  PageHeader,
  Pagination,
  Select,
  Skeleton,
  StatusPill,
  Tabs,
  Textarea,
  useToast,
} from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { useDebouncedValue, usePageTitle } from '../../../lib/hooks';
import { BULK_MAX, exportAcademicCsv } from '../../../api/adminBulk';
import { AcademicBulkBar } from '../bulk/BulkBars';
import { BulkCsvButton, RowPick, SelectPage, useIdSelection } from '../bulk/BulkParts';
import { adminErrorMessage } from '../campaigns/shared';
import styles from './academic.module.css';
import {
  allDayRange,
  emptyToNull,
  endAfterStart,
  eventsByDay,
  monthGrid,
  shiftMonth,
  summarizeImport,
  toDateInput,
  toDateTimeInput,
  totalPages,
} from './logic';

const PAGE_SIZE = 20;
const MONTH_FETCH = 100;
const MONTH_MAX_PAGES = 5;
const TITLE_MAX = 150;
const FORM_ID = 'acd-event-form';

export default function AcademicCalendarPage() {
  const i18n = useI18n();
  const { t, formatDate, formatDateTime } = i18n;
  usePageTitle(t('admin.acd.cal.title'));
  const toast = useToast();
  const qc = useQueryClient();

  const [view, setView] = useState<'list' | 'month'>('list');
  const [kind, setKind] = useState('');
  const [status, setStatus] = useState('');
  const [qText, setQText] = useState('');
  const q = useDebouncedValue(qText, 300);
  const [page, setPage] = useState(0);
  const now = new Date();
  const [ym, setYm] = useState({ year: now.getFullYear(), month0: now.getMonth() });
  const [editing, setEditing] = useState<AcademicEvent | 'new' | null>(null);
  const [removing, setRemoving] = useState<AcademicEvent | null>(null);
  const [importing, setImporting] = useState(false);
  // P15 toplu işlem seçimi (liste görünümü): süzgeç/sayfa/görünüm değişince sıfırlanır
  const selection = useIdSelection<number>(`${view}|${kind}|${status}|${q}|${page}`, BULK_MAX);

  const published = status === '' ? undefined : status === 'true';
  const listParams = { page, size: PAGE_SIZE, kind, q, published };
  const list = useQuery({
    queryKey: acdKeys.events(listParams),
    queryFn: () => listEvents(listParams),
    enabled: view === 'list',
  });
  const monthQuery = useQuery({
    queryKey: acdKeys.events({ month: true, kind, published }),
    enabled: view === 'month',
    queryFn: async () => {
      const all: AcademicEvent[] = [];
      let total = 0;
      for (let p = 0; p < MONTH_MAX_PAGES; p++) {
        const r = await listEvents({ page: p, size: MONTH_FETCH, kind, published });
        all.push(...r.items);
        total = r.total;
        if (all.length >= total || r.items.length === 0) break;
      }
      return { items: all, total };
    },
  });

  const refresh = () => void qc.invalidateQueries({ queryKey: acdKeys.all });
  const onError = (e: unknown) => toast.error(adminErrorMessage(i18n, e));

  const save = useMutation({
    mutationFn: (v: { id: number | null; body: AcademicEventInput }) =>
      v.id === null ? createEvent(v.body) : updateEvent(v.id, v.body),
    onSuccess: () => {
      toast.success(t('admin.acd.saved'));
      setEditing(null);
      refresh();
    },
    onError,
  });
  const toggle = useMutation({
    mutationFn: (ev: AcademicEvent) => setEventPublished(ev.id, !ev.published),
    onSuccess: (_r, ev) => {
      toast.success(t(ev.published ? 'admin.acd.unpublishedToast' : 'admin.acd.publishedToast'));
      refresh();
    },
    onError,
  });
  const remove = useMutation({
    mutationFn: (ev: AcademicEvent) => deleteEvent(ev.id),
    onSuccess: () => {
      toast.success(t('admin.acd.deleted'));
      setRemoving(null);
      refresh();
    },
    onError: (e) => {
      onError(e);
      setRemoving(null);
    },
  });

  const kindLabel = (k: CalendarKind) => t(`admin.acd.cal.kind.${k}` as const);
  const when = (ev: AcademicEvent) => {
    const fmt = ev.allDay ? (v: string) => formatDate(`${v.slice(0, 10)}T12:00:00`) : formatDateTime;
    const a = fmt(ev.startsAt);
    return ev.endsAt && ev.endsAt.slice(0, 16) !== ev.startsAt.slice(0, 16) ? `${a} – ${fmt(ev.endsAt)}` : a;
  };

  const byDay = useMemo(() => eventsByDay(monthQuery.data?.items ?? []), [monthQuery.data]);
  const weeks = useMemo(() => monthGrid(ym.year, ym.month0), [ym]);
  // Pazartesi (2024-01-01) tabanlı yerelleştirilmiş gün adları
  const dows = Array.from({ length: 7 }, (_, i) =>
    formatDate(`2024-01-0${i + 1}T12:00:00`, { weekday: 'short' }),
  );
  const todayKey = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;

  const rowActions = (ev: AcademicEvent) => (
    <div className={styles.actions}>
      <Button size="sm" variant="secondary" onClick={() => setEditing(ev)}>
        {t('common.edit')}
      </Button>
      <Button
        size="sm"
        variant="secondary"
        loading={toggle.isPending && toggle.variables?.id === ev.id}
        onClick={() => toggle.mutate(ev)}
      >
        {t(ev.published ? 'admin.acd.unpublish' : 'admin.acd.publish')}
      </Button>
      <Button size="sm" variant="danger" onClick={() => setRemoving(ev)}>
        {t('common.delete')}
      </Button>
    </div>
  );

  return (
    <>
      <PageHeader
        title={t('admin.acd.cal.title')}
        description={t('admin.acd.cal.intro')}
        actions={
          <>
            <BulkCsvButton
              filename="akademik-takvim.csv"
              fetchCsv={() => exportAcademicCsv({ entity: 'CALENDAR', q, kind, published })}
            />
            <Button variant="secondary" onClick={() => setImporting(true)}>
              {t('admin.acd.cal.import')}
            </Button>
            <Button onClick={() => setEditing('new')}>{t('admin.acd.cal.add')}</Button>
          </>
        }
      />
      <div className={styles.stack}>
        <div className={styles.toolbar}>
          <FormField label={t('admin.acd.cal.kind')}>
            <Select
              value={kind}
              onChange={(e) => {
                setKind(e.target.value);
                setPage(0);
              }}
            >
              <option value="">{t('admin.acd.cal.kindAll')}</option>
              {CALENDAR_KINDS.map((k) => (
                <option key={k} value={k}>
                  {kindLabel(k)}
                </option>
              ))}
            </Select>
          </FormField>
          <FormField label={t('admin.acd.statusLabel')}>
            <Select
              value={status}
              onChange={(e) => {
                setStatus(e.target.value);
                setPage(0);
              }}
            >
              <option value="">{t('admin.acd.statusAll')}</option>
              <option value="true">{t('admin.acd.published')}</option>
              <option value="false">{t('admin.acd.draft')}</option>
            </Select>
          </FormField>
          {view === 'list' && (
            <FormField label={t('admin.acd.search')}>
              <Input
                value={qText}
                maxLength={80}
                dir="auto"
                onChange={(e) => {
                  setQText(e.target.value);
                  setPage(0);
                }}
              />
            </FormField>
          )}
        </div>

        <Tabs
          label={t('admin.acd.cal.view')}
          value={view}
          onChange={(id) => setView(id as 'list' | 'month')}
          tabs={[
            { id: 'list', label: t('admin.acd.cal.viewList') },
            { id: 'month', label: t('admin.acd.cal.viewMonth') },
          ]}
        />

        {view === 'list' ? (
          list.isError ? (
            <ErrorState
              description={adminErrorMessage(i18n, list.error)}
              onRetry={() => void list.refetch()}
            />
          ) : list.isLoading ? (
            <Skeleton height="6rem" width="100%" />
          ) : (list.data?.items.length ?? 0) === 0 ? (
            <EmptyState
              icon="calendar"
              title={t('admin.acd.cal.emptyTitle')}
              description={t('admin.acd.cal.emptyHint')}
            />
          ) : (
            <>
              <SelectPage
                ids={list.data!.items.map((x) => x.id)}
                selection={selection}
                label={t('admin.p15.select.page')}
              />
              <ul className={styles.rowList} aria-label={t('admin.acd.rows')}>
                {list.data!.items.map((ev) => (
                  <li key={ev.id} className={styles.item}>
                    <div className={styles.itemHead}>
                      <RowPick id={ev.id} label={t('admin.p15.select.row', { title: ev.title })} selection={selection} />
                      <Badge tone="info">{kindLabel(ev.kind)}</Badge>
                      <StatusPill tone={ev.published ? 'success' : 'neutral'}>
                        {t(ev.published ? 'admin.acd.published' : 'admin.acd.draft')}
                      </StatusPill>
                      <span className={styles.spacer} />
                      {rowActions(ev)}
                    </div>
                    <h3 className={styles.itemTitle} dir="auto">
                      {ev.title}
                    </h3>
                    <p className={styles.muted}>
                      {when(ev)}
                      {ev.allDay ? ` · ${t('admin.acd.cal.allDay')}` : ''}
                      {ev.scopeDepartment ? ` · ${ev.scopeDepartment}` : ''}
                    </p>
                    {ev.note && (
                      <p className={styles.body} dir="auto">
                        {ev.note}
                      </p>
                    )}
                  </li>
                ))}
              </ul>
              <Pagination
                page={page}
                totalPages={totalPages(list.data!.total, PAGE_SIZE)}
                totalItems={list.data!.total}
                onPageChange={setPage}
              />
            </>
          )
        ) : monthQuery.isError ? (
          <ErrorState
            description={adminErrorMessage(i18n, monthQuery.error)}
            onRetry={() => void monthQuery.refetch()}
          />
        ) : (
          <Card>
            <div className={styles.stack}>
              <div className={styles.monthNav}>
                <Button
                  size="sm"
                  variant="secondary"
                  onClick={() => setYm(shiftMonth(ym.year, ym.month0, -1))}
                >
                  {t('admin.acd.cal.prev')}
                </Button>
                <h3 className={styles.monthTitle} aria-live="polite">
                  {formatDate(new Date(Date.UTC(ym.year, ym.month0, 15, 12)), {
                    month: 'long',
                    year: 'numeric',
                  })}
                </h3>
                <Button
                  size="sm"
                  variant="secondary"
                  onClick={() => setYm(shiftMonth(ym.year, ym.month0, 1))}
                >
                  {t('admin.acd.cal.next')}
                </Button>
                <Button
                  size="sm"
                  variant="ghost"
                  onClick={() => setYm({ year: now.getFullYear(), month0: now.getMonth() })}
                >
                  {t('admin.acd.cal.today')}
                </Button>
              </div>
              {monthQuery.isLoading ? (
                <Skeleton height="16rem" width="100%" />
              ) : (
                <>
                  {monthQuery.data && monthQuery.data.total > monthQuery.data.items.length && (
                    <p className={styles.muted} role="status">
                      {t('admin.acd.cal.truncated', { n: monthQuery.data.items.length })}
                    </p>
                  )}
                  <div className={styles.grid} role="grid" aria-label={t('admin.acd.cal.title')}>
                    {dows.map((d, i) => (
                      <div key={i} className={styles.dow} role="columnheader">
                        {d}
                      </div>
                    ))}
                    {weeks.flat().map((c) => (
                      <div
                        key={c.date}
                        role="gridcell"
                        className={`${styles.cell} ${c.inMonth ? '' : styles.cellOut}`}
                        aria-current={c.date === todayKey ? 'date' : undefined}
                      >
                        <span className={styles.dayNum}>{c.day}</span>
                        {(byDay.get(c.date) ?? []).map((ev) => (
                          <button
                            key={ev.id}
                            type="button"
                            className={`${styles.chip} ${ev.published ? '' : styles.chipDraft}`}
                            title={`${kindLabel(ev.kind)}: ${ev.title}`}
                            onClick={() => setEditing(ev)}
                          >
                            {ev.title}
                          </button>
                        ))}
                      </div>
                    ))}
                  </div>
                </>
              )}
            </div>
          </Card>
        )}
      </div>

      <AcademicBulkBar entity="CALENDAR" ids={[...selection.selected]} onClear={selection.clear} />
      {editing && (
        <EventFormModal
          key={editing === 'new' ? 'new' : editing.id}
          event={editing === 'new' ? null : editing}
          saving={save.isPending}
          onClose={() => setEditing(null)}
          onSubmit={(body) => save.mutate({ id: editing === 'new' ? null : editing.id, body })}
        />
      )}
      {importing && <ImportModal onClose={() => setImporting(false)} onDone={refresh} />}
      <ConfirmDialog
        open={!!removing}
        onClose={() => setRemoving(null)}
        onConfirm={() => removing && remove.mutate(removing)}
        loading={remove.isPending}
        danger
        title={t('admin.acd.deleteTitle')}
        message={t('admin.acd.deleteBody')}
        confirmLabel={t('common.delete')}
      />
    </>
  );
}

function EventFormModal({
  event,
  saving,
  onClose,
  onSubmit,
}: {
  event: AcademicEvent | null;
  saving: boolean;
  onClose: () => void;
  onSubmit: (b: AcademicEventInput) => void;
}) {
  const { t } = useI18n();
  const [kind, setKind] = useState<CalendarKind>(event?.kind ?? 'DIGER');
  const [title, setTitle] = useState(event?.title ?? '');
  const [allDay, setAllDay] = useState(event?.allDay ?? true);
  const [start, setStart] = useState(
    event ? (event.allDay ? toDateInput(event.startsAt) : toDateTimeInput(event.startsAt)) : '',
  );
  const [end, setEnd] = useState(
    event ? (event.allDay ? toDateInput(event.endsAt) : toDateTimeInput(event.endsAt)) : '',
  );
  const [scope, setScope] = useState(event?.scopeDepartment ?? '');
  const [note, setNote] = useState(event?.note ?? '');
  const [published, setPublished] = useState(event?.published ?? false);
  const [touched, setTouched] = useState(false);

  const titleBad = title.trim().length === 0 || title.trim().length > TITLE_MAX;
  const startBad = !start;
  const endBad = !endAfterStart(start, end);

  function toggleAllDay(on: boolean) {
    setAllDay(on);
    setStart((s) => (on ? s.slice(0, 10) : s ? `${s.slice(0, 10)}T09:00` : s));
    setEnd((s) => (on ? s.slice(0, 10) : s ? `${s.slice(0, 10)}T10:00` : s));
  }
  function submit(e: FormEvent) {
    e.preventDefault();
    setTouched(true);
    if (titleBad || startBad || endBad) return;
    const range = allDay ? allDayRange(start, end) : { startsAt: start, endsAt: end || null };
    onSubmit({
      kind,
      title: title.trim(),
      ...range,
      allDay,
      scopeDepartment: emptyToNull(scope),
      note: emptyToNull(note),
      published,
    });
  }

  return (
    <Modal
      open
      onClose={onClose}
      size="lg"
      title={t(event ? 'admin.acd.cal.editTitle' : 'admin.acd.cal.addTitle')}
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>
            {t('common.cancel')}
          </Button>
          <Button type="submit" form={FORM_ID} loading={saving}>
            {t('common.save')}
          </Button>
        </>
      }
    >
      <form id={FORM_ID} className={styles.formGrid} onSubmit={submit} noValidate>
        <FormField label={t('admin.acd.cal.kind')} required>
          <Select value={kind} onChange={(e) => setKind(e.target.value as CalendarKind)}>
            {CALENDAR_KINDS.map((k) => (
              <option key={k} value={k}>
                {t(`admin.acd.cal.kind.${k}` as const)}
              </option>
            ))}
          </Select>
        </FormField>
        <div className={styles.wide}>
          <FormField
            label={t('admin.acd.titleLabel')}
            required
            error={touched && titleBad ? t('admin.acd.titleReq', { max: TITLE_MAX }) : null}
          >
            <Input
              value={title}
              maxLength={TITLE_MAX}
              dir="auto"
              onChange={(e) => setTitle(e.target.value)}
            />
          </FormField>
        </div>
        <div className={styles.wide}>
          <Checkbox
            label={t('admin.acd.cal.allDay')}
            checked={allDay}
            onChange={(e) => toggleAllDay(e.target.checked)}
          />
        </div>
        <FormField
          label={t('admin.acd.cal.start')}
          required
          error={touched && startBad ? t('admin.acd.startReq') : null}
          hint={allDay ? undefined : t('admin.acd.tzHint')}
        >
          <Input
            type={allDay ? 'date' : 'datetime-local'}
            value={start}
            onChange={(e) => setStart(e.target.value)}
          />
        </FormField>
        <FormField label={t('admin.acd.cal.end')} error={touched && endBad ? t('admin.acd.endBefore') : null}>
          <Input
            type={allDay ? 'date' : 'datetime-local'}
            value={end}
            onChange={(e) => setEnd(e.target.value)}
          />
        </FormField>
        <div className={styles.wide}>
          <FormField label={t('admin.acd.cal.scope')}>
            <Input value={scope} maxLength={120} dir="auto" onChange={(e) => setScope(e.target.value)} />
          </FormField>
        </div>
        <div className={styles.wide}>
          <FormField label={t('admin.acd.note')}>
            <Textarea
              value={note}
              maxLength={500}
              rows={3}
              dir="auto"
              onChange={(e) => setNote(e.target.value)}
            />
          </FormField>
        </div>
        <div className={styles.wide}>
          <Checkbox
            label={t('admin.acd.published')}
            checked={published}
            onChange={(e) => setPublished(e.target.checked)}
          />
        </div>
      </form>
    </Modal>
  );
}

function ImportModal({ onClose, onDone }: { onClose: () => void; onDone: () => void }) {
  const i18n = useI18n();
  const { t } = i18n;
  const toast = useToast();
  const [text, setText] = useState('');
  const [publish, setPublish] = useState(false);
  const [result, setResult] = useState<EventImportResult | null>(null);
  const sum = summarizeImport(text);

  const run = useMutation({
    mutationFn: () => importEvents({ text, publish }),
    onSuccess: (r) => {
      setResult(r);
      toast.success(t('admin.acd.cal.importResult', { created: r.created, errors: r.errors.length }));
      if (r.created > 0) onDone();
    },
    onError: (e) => toast.error(adminErrorMessage(i18n, e)),
  });

  return (
    <Modal
      open
      onClose={onClose}
      size="lg"
      title={t('admin.acd.cal.import')}
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>
            {t('common.close')}
          </Button>
          <Button
            loading={run.isPending}
            disabled={sum.lines === 0 || sum.tooMany}
            onClick={() => run.mutate()}
          >
            {t('admin.acd.cal.importBtn')}
          </Button>
        </>
      }
    >
      <div className={styles.stack}>
        <FormField
          label={t('admin.acd.cal.importText')}
          hint={t('admin.acd.cal.importHint')}
          error={sum.tooMany ? t('admin.acd.cal.importTooMany') : null}
        >
          <Textarea
            value={text}
            rows={8}
            dir="auto"
            maxLength={50000}
            onChange={(e) => setText(e.target.value)}
          />
        </FormField>
        <p className={styles.muted}>{t('admin.acd.cal.importCount', { n: sum.lines })}</p>
        <Checkbox
          label={t('admin.acd.cal.importPublish')}
          checked={publish}
          onChange={(e) => setPublish(e.target.checked)}
        />
        {result && (
          <div role="status" className={styles.preview}>
            <strong>
              {t('admin.acd.cal.importResult', { created: result.created, errors: result.errors.length })}
            </strong>
            {result.errors.length > 0 && (
              <>
                <p className={styles.muted}>{t('admin.acd.cal.importErrors')}</p>
                <ul className={styles.errorList}>
                  {result.errors.map((er) => (
                    <li key={er.line} dir="auto">
                      {t('admin.acd.cal.importLine', { line: er.line, message: er.message })}
                    </li>
                  ))}
                </ul>
              </>
            )}
          </div>
        )}
      </div>
    </Modal>
  );
}
