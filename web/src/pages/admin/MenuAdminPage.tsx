// SAYFA: Yemek menüsü (/admin/content/menu) — günün menüsüne isteğe bağlı fotoğraf ekle/değiştir/kaldır + yemek kalorisi (kcal) düzenle.
// API: GET /api/admin/menu?from&to, PUT /api/admin/menu/{date}/image (multipart `file`), DELETE .../image (api/adminMenu.ts).
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useRef, useState } from 'react';
import { adminMenuApi, qk } from '../../api';
import type { AdminMenuDay } from '../../api/adminMenu';
import {
  Button,
  ConfirmDialog,
  EmptyState,
  ErrorState,
  FormField,
  Input,
  PageHeader,
  Skeleton,
  useToast,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import { adminErrorMessage } from './campaigns/shared';
import { MENU_BULK_MAX, exportMenuCsv } from '../../api/adminBulk';
import { MenuBulkBar } from './bulk/BulkBars';
import { BulkCsvButton, RowPick, SelectPage, useIdSelection, type IdSelection } from './bulk/BulkParts';
import { CalorieBulkImport } from './menu/CalorieBulkImport';
import { CalorieEditor } from './menu/CalorieEditor';
import { currentMonth, isMonth, monthRange, validateMenuImage } from './menu/menuLogic';
import styles from './menu/menu.module.css';

function DayRow({
  day,
  onChanged,
  selection,
}: {
  day: AdminMenuDay;
  onChanged: () => void;
  selection: IdSelection<string>;
}) {
  const i18n = useI18n();
  const { t, formatDate } = i18n;
  const toast = useToast();
  const fileRef = useRef<HTMLInputElement>(null);
  const [problem, setProblem] = useState<string | null>(null);
  const [confirm, setConfirm] = useState(false);
  const label = formatDate(day.date, { dateStyle: 'full' });

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
      <div className={styles.info}>
        <h3 className={styles.date}>
          <RowPick id={day.date} label={t('admin.p15.menu.select', { date: label })} selection={selection} />
          {label}
        </h3>
        <CalorieEditor day={day} onSaved={onChanged} />
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
  // P15 toplu silme seçimi: ay değişince sıfırlanır
  const selection = useIdSelection<string>(month, MENU_BULK_MAX);

  return (
    <>
      <PageHeader
        title={t('admin.menu.title')}
        description={t('admin.menu.subtitle')}
        actions={
          <BulkCsvButton
            filename="yemek-menusu.csv"
            fetchCsv={() => exportMenuCsv(range ? { from: range.from, to: range.to } : {})}
          />
        }
      />
      <div className={styles.filters} role="search" aria-label={t('admin.menu.filters')}>
        <FormField label={t('admin.menu.month')}>
          <Input type="month" value={month} onChange={(e) => setMonth(e.target.value)} />
        </FormField>
      </div>
      <p className={styles.muted}>{t('admin.menu.hint')}</p>
      <p className={styles.muted}>{t('admin.menu.kcal.hint')}</p>
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
          <SelectPage ids={days.map((d) => d.date)} selection={selection} label={t('admin.p15.menu.selectAll')} />
          <ul className={styles.list} data-testid="menu-list">
            {days.map((d) => (
              <DayRow
                key={d.date}
                day={d}
                selection={selection}
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
