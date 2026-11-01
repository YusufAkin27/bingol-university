// SAYFA: Yemek menüsü (/admin/content/menu) — günün menüsüne isteğe bağlı fotoğraf ekle/değiştir/kaldır + yemek kalorisi (kcal) düzenle.
// API: GET /api/admin/menu?from&to, PUT /api/admin/menu/{date}/image (multipart `file`), DELETE .../image (api/adminMenu.ts).
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useRef, useState } from 'react';
import { adminMenuApi, qk } from '../../api';
import type { AdminMenuDay } from '../../api/adminMenu';
import {
  Badge,
  Button,
  ConfirmDialog,
  EmptyState,
  ErrorState,
  FormField,
  Input,
  Insight,
  PageHeader,
  Skeleton,
  StatTile,
  useToast,
} from '../../components/ui';
import { SummaryStrip } from './community/Summary';
import { useI18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import { adminErrorMessage } from './campaigns/shared';
import { MENU_BULK_MAX, exportMenuCsv } from '../../api/adminBulk';
import { MenuBulkBar } from './bulk/BulkBars';
import { BulkCsvButton, RowPick, SelectPage, useIdSelection, type IdSelection } from './bulk/BulkParts';
import { CalorieBulkImport } from './menu/CalorieBulkImport';
import { CalorieEditor } from './menu/CalorieEditor';
import { MenuGaps } from './menu/MenuGaps';
import { currentMonth, dishesOf, isMonth, monthRange, shiftMonthValue, sumKcal, validateMenuImage } from './menu/menuLogic';
import styles from './menu/menu.module.css';

/** Bugünden itibaren 7 gün içindeki günler açık başlar; geçmiş ve uzak günler katlanır (30 günlük ay ~9000 px olmasın). */
function isNear(date: string, now: Date = new Date()): boolean {
  const p = (n: number) => String(n).padStart(2, '0');
  const ymd = (d: Date) => `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
  const end = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 7);
  return date >= ymd(now) && date <= ymd(end);
}

function DayRow({
  day,
  onChanged,
  selection,
  maxKcal,
}: {
  day: AdminMenuDay;
  onChanged: () => void;
  selection: IdSelection<string>;
  maxKcal: number;
}) {
  const i18n = useI18n();
  const { t, formatDate } = i18n;
  const toast = useToast();
  const fileRef = useRef<HTMLInputElement>(null);
  const [problem, setProblem] = useState<string | null>(null);
  const [confirm, setConfirm] = useState(false);
  const label = formatDate(day.date, { dateStyle: 'full' });
  const dishes = dishesOf(day);
  const sum = sumKcal(dishes.map((d) => d.kcal));
  const missingKcal = dishes.length - sum.known;

  const upload = useMutation({
    mutationFn: (file: File) => adminMenuApi.uploadMenuImage(day.date, file),
    onSuccess: () => {
      toast.success(t('admin.menu.uploaded'));
      onChanged();
    },
    onError: (e) => setProblem(adminErrorMessage(i18n, e)),
  });
  const remove = useMutation({
    mutationFn: () => adminMenuApi.deleteMenuImage(day.date),
    onSuccess: () => {
      toast.success(t('admin.menu.removed'));
      setConfirm(false);
      onChanged();
    },
    onError: (e) => {
      setConfirm(false);
      setProblem(adminErrorMessage(i18n, e));
    },
  });

  const pick = (file: File | undefined) => {
    setProblem(null);
    if (!file) return;
    const p = validateMenuImage(file);
    if (p) {
      setProblem(t(`admin.menu.err.${p}` as 'admin.menu.err.type'));
      return;
    }
    upload.mutate(file);
  };

  return (
    <li className={styles.row} data-testid="menu-row">
      <details className={styles.dayDetails} open={isNear(day.date)}>
        <summary className={styles.daySummary}>
          <span className={styles.dayTitle}>{label}</span>
          <span className={styles.dayChips}>
            {sum.total !== null && <Badge tone="info">{t('admin.v2.menu.totalChip', { kcal: sum.total })}</Badge>}
            {missingKcal > 0 && <Badge tone="warning">{t('admin.v2.menu.missingChip', { n: missingKcal })}</Badge>}
            {!day.imageUrl && <Badge>{t('admin.v2.menu.noPhotoChip')}</Badge>}
          </span>
        </summary>
        <div className={styles.dayBody}>
      <div className={styles.info}>
        <h3 className={styles.date}>
          <RowPick id={day.date} label={t('admin.p15.menu.select', { date: label })} selection={selection} />
          {label}
        </h3>
        <CalorieEditor day={day} onSaved={onChanged} maxKcal={maxKcal} />
      </div>
      <div className={styles.media}>
        {day.imageUrl ? (
          <img className={styles.thumb} src={day.imageUrl} alt={t('admin.menu.imageAlt', { date: label })} loading="lazy" />
        ) : (
          <div className={styles.placeholder}>{t('admin.menu.noImage')}</div>
        )}
        <input
          ref={fileRef}
          className={styles.file}
          type="file"
          accept="image/jpeg,image/png,image/webp"
          tabIndex={-1}
          aria-label={t('admin.menu.fileInput', { date: label })}
          data-testid="menu-file"
          onChange={(e) => {
            pick(e.target.files?.[0]);
            e.target.value = '';
          }}
        />
        <div className={styles.actions}>
          <Button
            size="sm"
            variant="secondary"
            loading={upload.isPending}
            disabled={remove.isPending}
            onClick={() => fileRef.current?.click()}
            aria-label={`${day.imageUrl ? t('admin.menu.replace') : t('admin.menu.add')} — ${label}`}
          >
            {upload.isPending ? t('admin.menu.uploading') : day.imageUrl ? t('admin.menu.replace') : t('admin.menu.add')}
          </Button>
          {day.imageUrl && (
            <Button
              size="sm"
              variant="danger"
              disabled={upload.isPending}
              onClick={() => setConfirm(true)}
              aria-label={`${t('admin.menu.remove')} — ${label}`}
            >
              {t('admin.menu.remove')}
            </Button>
          )}
        </div>
        {problem && (
          <p className={styles.error} role="alert">
            {problem}
          </p>
        )}
      </div>
      <ConfirmDialog
        open={confirm}
        onClose={() => setConfirm(false)}
        onConfirm={() => remove.mutate()}
        title={t('admin.menu.removeTitle')}
        message={t('admin.menu.removeMsg', { date: label })}
        confirmLabel={t('admin.menu.remove')}
        danger
        loading={remove.isPending}
      />
        </div>
      </details>
    </li>
  );
}

export default function MenuAdminPage() {
  const i18n = useI18n();
  const { t } = i18n;
  usePageTitle(t('admin.menu.title'));
  const qc = useQueryClient();
  const [month, setMonth] = useState(currentMonth());
  const valid = isMonth(month);
  const range = valid ? monthRange(month) : null;

  const q = useQuery({
    queryKey: qk.adminMenu.month(range?.from ?? '', range?.to ?? ''),
    queryFn: () => adminMenuApi.listMenu(range!.from, range!.to),
    enabled: valid,
    staleTime: 15_000,
  });
  const days = [...(q.data ?? [])].sort((a, b) => a.date.localeCompare(b.date));
  const maxKcal = Math.max(1, ...days.flatMap((d) => dishesOf(d).map((x) => x.kcal ?? 0)));
  const daysMissingKcal = days.filter((d) => dishesOf(d).some((x) => x.kcal === null)).length;
  const daysNoImage = days.filter((d) => !d.imageUrl).length;
  // P15 toplu silme seçimi: ay değişince sıfırlanır
  const selection = useIdSelection<string>(month, MENU_BULK_MAX);

  return (
    <>
      <PageHeader
        title={t('admin.menu.title')}
        description={t('admin.menu.subtitle')}
        actions={
          <span data-search-anchor="menu-csv"><BulkCsvButton
            filename="yemek-menusu.csv"
            fetchCsv={() => exportMenuCsv(range ? { from: range.from, to: range.to } : {})}
          /></span>
        }
      />
      <div className={styles.filters} role="search" aria-label={t('admin.menu.filters')} data-search-anchor="menu-month">
        <Button size="sm" variant="secondary" disabled={!valid} onClick={() => setMonth(shiftMonthValue(month, -1))}>
          {t('admin.v2.menu.prev')}
        </Button>
        <FormField label={t('admin.menu.month')}>
          <Input type="month" value={month} onChange={(e) => setMonth(e.target.value)} />
        </FormField>
        <Button size="sm" variant="secondary" disabled={!valid} onClick={() => setMonth(shiftMonthValue(month, 1))}>
          {t('admin.v2.menu.next')}
        </Button>
        <Button size="sm" variant="ghost" onClick={() => setMonth(currentMonth())}>
          {t('admin.v2.menu.thisMonth')}
        </Button>
      </div>
      {valid && days.length > 0 && (
        <SummaryStrip
          insight={
            <Insight
              tone={daysMissingKcal > 0 ? 'warn' : 'good'}
              parts={t(daysMissingKcal > 0 ? 'admin.v2.menu.insightMissing' : 'admin.v2.menu.insightOk', {
                n: days.length,
                missing: daysMissingKcal,
              })}
            />
          }
        >
          <StatTile icon="cup" label={t('admin.v2.menu.sum.days')} value={days.length} caption={t('admin.v2.menu.sum.daysCap')} />
          <StatTile icon="alert" label={t('admin.v2.menu.sum.missing')} value={daysMissingKcal} caption={t('admin.v2.menu.sum.missingCap')} />
          <StatTile icon="image" label={t('admin.v2.menu.sum.noPhoto')} value={daysNoImage} caption={t('admin.v2.menu.sum.noPhotoCap')} />
        </SummaryStrip>
      )}
      <details className={styles.help} data-search-anchor="menu-photo-help">
        <summary>{t('admin.v2.menu.helpTitle')}</summary>
        <ul>
          <li>{t('admin.menu.hint')}</li>
          <li>{t('admin.menu.kcal.hint')}</li>
        </ul>
      </details>
      <CalorieBulkImport onDone={() => void qc.invalidateQueries({ queryKey: ['adminMenu'] })} />

      {!valid ? (
        <EmptyState icon="calendar" title={t('admin.menu.pickMonth')} description=" " />
      ) : q.isError ? (
        <ErrorState description={adminErrorMessage(i18n, q.error)} onRetry={() => void q.refetch()} />
      ) : q.isLoading ? (
        <Skeleton height="12rem" width="100%" />
      ) : days.length === 0 ? (
        <EmptyState icon="calendar" title={t('admin.menu.empty')} description=" " />
      ) : (
        <>
          <MenuGaps days={days} />
          <SelectPage ids={days.map((d) => d.date)} selection={selection} label={t('admin.p15.menu.selectAll')} />
          <ul className={styles.list} data-testid="menu-list">
            {days.map((d) => (
              <DayRow
                key={d.date}
                day={d}
                selection={selection}
                maxKcal={maxKcal}
                onChanged={() => void qc.invalidateQueries({ queryKey: ['adminMenu'] })}
              />
            ))}
          </ul>
        </>
      )}
      <MenuBulkBar dates={[...selection.selected]} onClear={selection.clear} />
    </>
  );
}
