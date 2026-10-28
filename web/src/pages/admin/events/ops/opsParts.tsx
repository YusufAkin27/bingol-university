// P07 etkinlik derin yönetimi: sekmeler için ortak parçalar (sorgu anahtarı, yükleniyor/hata/boş durumu, CSV düğmesi).
import { useMutation } from '@tanstack/react-query';
import type { ReactNode } from 'react';
import { Button, EmptyState, ErrorState, Skeleton, useToast } from '../../../../components/ui';
import { useI18n } from '../../../../i18n/I18nProvider';
import { downloadBlob } from '../../users/filters';
import { eventErrorMessage } from '../errors';

/** Bir etkinliğin P07 sorguları: ['events','ops',id,parça,...]; tümü `opsPrefix` ile geçersiz kılınır. */
export const opsPrefix = (eventId: number) => ['events', 'ops', eventId] as const;
export const opsKey = (eventId: number, part: string, ...rest: unknown[]) =>
  [...opsPrefix(eventId), part, ...rest] as const;

/** Karar/düzeltme sonrası tazelenecek anahtarlar: etkinlik ops sekmeleri + ayrıntı (sayaçlar) + liste. */
export const opsInvalidate = (eventId: number) => [
  opsPrefix(eventId) as unknown as unknown[],
  ['events', 'detail', eventId],
  ['events', 'list'],
];

/** Sorgu durumuna göre iskelet/hata/boş durumu çizer; veri varsa çocukları gösterir. */
export function PanelState({
  loading,
  error,
  onRetry,
  empty,
  emptyTitle,
  emptyHint,
  children,
}: {
  loading: boolean;
  error: unknown;
  onRetry: () => void;
  empty: boolean;
  emptyTitle: string;
  emptyHint?: string;
  children: ReactNode;
}) {
  const i18n = useI18n();
  if (error) return <ErrorState description={eventErrorMessage(i18n, error)} onRetry={onRetry} />;
  if (loading) return <Skeleton width="100%" height="8em" />;
  if (empty) return <EmptyState icon="info" title={emptyTitle} description={emptyHint ?? ' '} compact />;
  return <>{children}</>;
}

/** CSV indirme düğmesi (Blob; yetki başlığı gerektiğinden `<a href>` yetmez). */
export function CsvButton({
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
    onError: (e) => toast.error(eventErrorMessage(i18n, e)),
  });
  return (
    <Button size="sm" variant="secondary" loading={m.isPending} onClick={() => m.mutate()}>
      {label ?? i18n.t('admin.p07.csv')}
    </Button>
  );
}
