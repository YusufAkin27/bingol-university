// SAYFA: Etkinlik başvuruları, yönetici özeti (/admin/events/applications?eventId=)
// API: GET /api/events/{id}/applications/summary (ADMIN, salt okunur; durum sayıları + doluluk) (api/admission.ts),
//      etkinlik seçici için GET /api/admin/events?q= (api/adminEvents.ts).
// Başvuran kişilerin ayrıntısı bu görünümde YOK; kabul/ret kararını etkinliği düzenleyen kişi verir.
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { admissionApi, qk } from '../../api';
import { listAdminEvents } from '../../api/adminEvents';
import type { AdmissionSummary, EventView } from '../../api/types';
import {
  Button,
  Card,
  EmptyState,
  ErrorState,
  FormField,
  Input,
  Insight,
  PageHeader,
  ProgressRing,
  Skeleton,
  StatTile,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import { paths } from '../../paths';
import { adminErrorMessage } from './campaigns/shared';
import { EntityPicker, PickedChip } from './community/EntityPicker';
import { StackedBar, SummaryGrid, SummaryStrip } from './community/Summary';
import { parseId } from './moderation/modLogic';
import styles from './moderation/moderation.module.css';

/** Özet cümlesi: kontenjan, doluluk ve karar bekleyen başvuru sayısı. */
function sentence(t: ReturnType<typeof useI18n>['t'], nf: (n: number) => string, s: AdmissionSummary): string {
  if (s.capacity === null) {
    return t('admin.v2.apps.sentence.unlimited', { going: nf(s.goingCount), pending: nf(s.pending) });
  }
  const left = Math.max(0, s.capacity - s.goingCount);
  return t(left === 0 ? 'admin.v2.apps.sentence.full' : 'admin.v2.apps.sentence.limited', {
    cap: nf(s.capacity),
    going: nf(s.goingCount),
    left: nf(left),
    pending: nf(s.pending),
  });
}

export default function EventApplicationsPage() {
  const i18n = useI18n();
  const { t, formatNumber, formatDate } = i18n;
  usePageTitle(t('admin.admission.title'));
  const [params, setParams] = useSearchParams();
  const eventId = parseId(params.get('eventId') ?? '');
  const eventName = params.get('name') ?? '';
  const [input, setInput] = useState('');
  const [invalid, setInvalid] = useState(false);

  const summary = useQuery({
    queryKey: qk.admission.summary(eventId ?? 0),
    queryFn: () => admissionApi.getAdmissionSummary(eventId as number),
    enabled: eventId !== null,
    retry: false,
  });
  const s = summary.data;

  return (
    <>
      <PageHeader title={t('admin.admission.title')} />
      <div className={styles.stack}>
        {eventId === null ? (
          <>
            <EntityPicker<EventView>
              anchor="ea-event"
              label={t('admin.v2.apps.pickLabel')}
              placeholder={t('admin.v2.apps.pickPlaceholder')}
              hint={t('admin.v2.apps.pickHint')}
              noResult={t('admin.v2.apps.pickNone')}
              queryKey="events"
              search={async (q) => (await listAdminEvents({ status: 'ALL', q, size: 8 })).items}
              itemKey={(e) => e.id}
              render={(e) => ({
                title: e.title,
                meta: [formatDate(e.startsAt), e.communityName ?? t('admin.events.standalone')].join(' · '),
              })}
              onPick={(e) => setParams({ eventId: String(e.id), name: e.title })}
              footer={
                <details className={styles.muted}>
                  <summary>{t('admin.v2.apps.byId')}</summary>
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
                  </form>
                </details>
              }
            />
            <Link to={paths.admin.events}>{t('admin.admission.openEvents')}</Link>
            <EmptyState icon="calendar" title={t('admin.admission.empty.title')} description={t('admin.admission.empty.hint')} />
          </>
        ) : (
          <>
            <PickedChip
              title={eventName || t('admin.v2.apps.eventNo', { id: eventId })}
              meta={t('admin.v2.apps.chipMeta')}
              onChange={() => setParams({})}
            />
            <Link to={`${paths.admin.events}?open=${eventId}`}>{t('admin.v2.apps.openEvent')}</Link>
          </>
        )}

        {eventId === null ? null : summary.isError ? (
          <ErrorState description={adminErrorMessage(i18n, summary.error)} onRetry={() => void summary.refetch()} />
        ) : summary.isLoading ? (
          <Skeleton height="6rem" width="100%" />
        ) : (
          s && (
            <Card title={t('admin.admission.summary', { id: s.eventId })} data-search-anchor="ea-stats">
              <SummaryStrip
                insight={<Insight tone={s.pending > 0 ? 'warn' : 'info'} parts={sentence(t, formatNumber, s)} />}
              >
                {s.capacity !== null && (
                  <ProgressRing
                    value={s.goingCount}
                    max={s.capacity}
                    tone={s.goingCount >= s.capacity ? 'warning' : 'info'}
                    label={t('admin.v2.apps.ring', { going: formatNumber(s.goingCount), cap: formatNumber(s.capacity) })}
                    size={110}
                  />
                )}
              </SummaryStrip>
              <p className={styles.muted}>
                {t('admin.admission.mode')}: {t(s.mode === 'APPROVAL' ? 'admin.admission.mode.APPROVAL' : 'admin.admission.mode.OPEN')}
                {' · '}
                {t('admin.admission.capacity')}: {s.capacity === null ? t('admin.admission.unlimited') : formatNumber(s.capacity)}
              </p>
              <StackedBar
                ariaLabel={t('admin.v2.apps.funnel')}
                parts={[
                  { key: 'pending', label: t('admin.admission.pending'), value: s.pending, tone: 'warning' },
                  { key: 'accepted', label: t('admin.admission.accepted'), value: s.accepted, tone: 'success' },
                  { key: 'waitlisted', label: t('admin.admission.waitlisted'), value: s.waitlisted, tone: 'info' },
                  { key: 'rejected', label: t('admin.admission.rejected'), value: s.rejected, tone: 'danger' },
                  { key: 'cancelled', label: t('admin.admission.cancelled'), value: s.cancelled, tone: 'neutral' },
                ]}
              />
              <SummaryGrid label={t('admin.v2.apps.counts')}>
                <StatTile label={t('admin.admission.going')} value={s.goingCount} caption={t('admin.v2.apps.cap.going')} />
                <StatTile label={t('admin.admission.pending')} value={s.pending} caption={t('admin.v2.apps.cap.pending')} />
                <StatTile label={t('admin.admission.accepted')} value={s.accepted} caption={t('admin.v2.apps.cap.accepted')} />
                <StatTile label={t('admin.admission.waitlisted')} value={s.waitlisted} caption={t('admin.v2.apps.cap.waitlisted')} />
                <StatTile label={t('admin.admission.rejected')} value={s.rejected} caption={t('admin.v2.apps.cap.rejected')} />
                <StatTile label={t('admin.admission.cancelled')} value={s.cancelled} caption={t('admin.v2.apps.cap.cancelled')} />
              </SummaryGrid>
            </Card>
          )
        )}
      </div>
    </>
  );
}
