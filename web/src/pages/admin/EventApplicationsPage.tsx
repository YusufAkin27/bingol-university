// SAYFA: Etkinlik başvuruları, yönetici özeti (/admin/events/applications?eventId=)
// API: GET /api/events/{id}/applications/summary (ADMIN, salt okunur; durum sayıları + doluluk) (api/admission.ts).
// Başvuran kişilerin ayrıntısı bu görünümde YOK; kabul/ret kararını etkinliği düzenleyen kişi verir.
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { admissionApi, qk } from '../../api';
import { Button, Card, EmptyState, ErrorState, FormField, Input, PageHeader, Skeleton, StatCard } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import { paths } from '../../paths';
import { adminErrorMessage } from './campaigns/shared';
import { parseId } from './moderation/modLogic';
import styles from './moderation/moderation.module.css';

export default function EventApplicationsPage() {
  const i18n = useI18n();
  const { t, formatNumber } = i18n;
  usePageTitle(t('admin.admission.title'));
  const [params, setParams] = useSearchParams();
  const eventId = parseId(params.get('eventId') ?? '');
  const [input, setInput] = useState(params.get('eventId') ?? '');
  const [invalid, setInvalid] = useState(false);

  const summary = useQuery({
    queryKey: qk.admission.summary(eventId ?? 0),
    queryFn: () => admissionApi.getAdmissionSummary(eventId as number),
    enabled: eventId !== null,
    retry: false,
  });
  const s = summary.data;
  const n = (v: number | undefined) => (v === undefined ? '' : formatNumber(v));

  return (
    <>
      <PageHeader title={t('admin.admission.title')} />
      <div className={styles.stack}>
        <form
          className={styles.toolbar}
          onSubmit={(e) => {
            e.preventDefault();
            const id = parseId(input);
            setInvalid(id === null);
            if (id !== null) setParams({ eventId: String(id) });
          }}
        >
          <FormField label={t('admin.admission.eventId')} error={invalid ? t('admin.admission.invalidId') : null}>
            <Input className="ltr" inputMode="numeric" value={input} onChange={(e) => setInput(e.target.value)} />
          </FormField>
          <Button type="submit">{t('admin.admission.show')}</Button>
          <Link to={paths.admin.events}>{t('admin.admission.openEvents')}</Link>
        </form>

        {eventId === null ? (
          <EmptyState icon="calendar" title={t('admin.admission.empty.title')} description={t('admin.admission.empty.hint')} />
        ) : summary.isError ? (
          <ErrorState description={adminErrorMessage(i18n, summary.error)} onRetry={() => void summary.refetch()} />
        ) : summary.isLoading ? (
          <Skeleton height="6rem" width="100%" />
        ) : (
          s && (
            <Card title={t('admin.admission.summary', { id: s.eventId })}>
              <p className={styles.muted}>
                {t('admin.admission.mode')}: {t(s.mode === 'APPROVAL' ? 'admin.admission.mode.APPROVAL' : 'admin.admission.mode.OPEN')}
                {' · '}
                {t('admin.admission.capacity')}: {s.capacity === null ? t('admin.admission.unlimited') : formatNumber(s.capacity)}
              </p>
              <div className={styles.statGrid}>
                <StatCard title={t('admin.admission.going')} value={n(s.goingCount)} />
                <StatCard title={t('admin.admission.pending')} value={n(s.pending)} />
                <StatCard title={t('admin.admission.accepted')} value={n(s.accepted)} />
                <StatCard title={t('admin.admission.waitlisted')} value={n(s.waitlisted)} />
                <StatCard title={t('admin.admission.rejected')} value={n(s.rejected)} />
                <StatCard title={t('admin.admission.cancelled')} value={n(s.cancelled)} />
              </div>
            </Card>
          )
        )}
      </div>
    </>
  );
}
