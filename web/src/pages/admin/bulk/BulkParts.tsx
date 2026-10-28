// P15: toplu işlem ortak parçaları (seçim kancası, kısmi başarı raporu, CSV düğmesi). Yönetim paneli yalnız Türkçedir.
import { useMutation } from '@tanstack/react-query';
import { useCallback, useEffect, useState } from 'react';
import type { BulkReport } from '../../../api/adminBulk';
import { Button, Checkbox, Modal, useToast } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminError } from '../../../lib/errors';
import { downloadBlob } from '../users/filters';
import styles from './bulk.module.css';

/** İstemci tarafı toplu işlem hata metni: önce `admin.p15.err.<KOD>`, sonra ortak çeviriler. */
export function bulkError(i18n: ReturnType<typeof useI18n>, e: unknown): string {
  return adminError(i18n, e, 'admin.p15.err');
}

export interface IdSelection<K extends string | number> {
  selected: ReadonlySet<K>;
  count: number;
  has: (id: K) => boolean;
  toggle: (id: K, on: boolean) => void;
  /** Verilen kimliklerin tümünü seçer (en çok `max`); `on=false` seçimi boşaltır. */
  setAll: (ids: K[], on: boolean) => void;
  clear: () => void;
  atMax: boolean;
}

/**
 * Satır seçimi. `resetKey` (süzgeç + sayfa) değişince seçim SIFIRLANIR: görünmeyen kayıt toplu işleme girmesin.
 */
export function useIdSelection<K extends string | number>(resetKey: string, max: number): IdSelection<K> {
  const [selected, setSelected] = useState<Set<K>>(new Set());
  useEffect(() => {
    setSelected(new Set());
  }, [resetKey]);
  const toggle = useCallback(
    (id: K, on: boolean) =>
      setSelected((cur) => {
        if (on && cur.size >= max && !cur.has(id)) return cur;
        const next = new Set(cur);
        if (on) next.add(id);
        else next.delete(id);
        return next;
      }),
    [max],
  );
  const setAll = useCallback(
    (ids: K[], on: boolean) => setSelected(on ? new Set(ids.slice(0, max)) : new Set()),
    [max],
  );
  const clear = useCallback(() => setSelected(new Set()), []);
  return {
    selected,
    count: selected.size,
    has: (id) => selected.has(id),
    toggle,
    setAll,
    clear,
    atMax: selected.size >= max,
  };
}

/** Sayfadaki tümünü seç (liste görünümlerinde, tablo olmayan yerler için). */
export function SelectPage<K extends string | number>({
  ids,
  selection,
  label,
}: {
  ids: K[];
  selection: IdSelection<K>;
  label: string;
}) {
  const all = ids.length > 0 && ids.every((id) => selection.has(id));
  return (
    <div className={styles.selectAll}>
      <Checkbox
        label={label}
        checked={all}
        disabled={ids.length === 0}
        onChange={(e) => selection.setAll(ids, e.target.checked)}
      />
    </div>
  );
}

/** Satır onay kutusu (ekran okuyucu için görünmez etiket). */
export function RowPick<K extends string | number>({
  id,
  label,
  selection,
}: {
  id: K;
  label: string;
  selection: IdSelection<K>;
}) {
  return (
    <span className={styles.pick}>
      <input
        type="checkbox"
        aria-label={label}
        checked={selection.has(id)}
        disabled={!selection.has(id) && selection.atMax}
        onChange={(e) => selection.toggle(id, e.target.checked)}
      />
    </span>
  );
}

/** Kısmi başarı raporu: tamamlanan / atlanan / hatalı sayıları ve atlanan-hatalı kayıtların nedeni. */
export function BulkReportModal({ report, onClose }: { report: BulkReport | null; onClose: () => void }) {
  const i18n = useI18n();
  const { t, formatNumber } = i18n;
  if (!report) return null;
  const problems = report.results.filter((r) => r.status !== 'DONE');
  const text = (code: string | null) => i18n.td(`admin.p15.code.${code ?? ''}`, code ?? '');
  return (
    <Modal
      open
      onClose={onClose}
      title={t('admin.p15.report.title')}
      footer={<Button onClick={onClose}>{t('admin.p15.report.close')}</Button>}
    >
      <div data-testid="bulk-report">
        <div className={styles.summary}>
          <span>{t('admin.p15.report.requested', { n: formatNumber(report.requested) })}</span>
          <strong>{t('admin.p15.report.done', { n: formatNumber(report.done) })}</strong>
          <span>{t('admin.p15.report.skipped', { n: formatNumber(report.skipped) })}</span>
          <span>{t('admin.p15.report.failed', { n: formatNumber(report.failed) })}</span>
        </div>
        {problems.length > 0 && (
          <>
            <p className={styles.muted}>{t('admin.p15.report.problems')}</p>
            <ul className={styles.reportList}>
              {problems.map((r, i) => (
                <li key={`${r.id}-${i}`}>
                  <span className="ltr">{r.id}</span>
                  {': '}
                  {r.status === 'FAILED' ? t('admin.p15.report.failedItem', { code: text(r.code) }) : text(r.code)}
                </li>
              ))}
            </ul>
          </>
        )}
      </div>
    </Modal>
  );
}

/** CSV indirme düğmesi: Blob alınır (yetki başlığı gerektiğinden `<a href>` yetmez), hata toast'la gösterilir. */
export function BulkCsvButton({
  fetchCsv,
  filename,
  label,
}: {
  fetchCsv: () => Promise<Blob>;
  filename: string;
  label?: string;
}) {
  const i18n = useI18n();
  const toast = useToast();
  const m = useMutation({
    mutationFn: fetchCsv,
    onSuccess: (b) => downloadBlob(b, filename),
    onError: (e) => toast.error(bulkError(i18n, e)),
  });
  return (
    <Button size="sm" variant="secondary" loading={m.isPending} onClick={() => m.mutate()}>
      {label ?? i18n.t('admin.p15.csv')}
    </Button>
  );
}
