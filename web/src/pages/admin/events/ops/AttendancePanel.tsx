import { useQuery } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import {
  exportEventAttendanceCsv,
  getEventAttendance,
  markEventAttendance,
  type AdminAttendanceRow,
} from '../../../../api/adminEvents';
import { Badge, GuardedAction, Input, Select } from '../../../../components/ui';
import { useI18n } from '../../../../i18n/I18nProvider';
import { eventErrorMessage } from '../errors';
import { CsvButton, PanelState, opsInvalidate, opsKey } from './opsParts';
import styles from './ops.module.css';

type Filter = '' | 'present' | 'absent' | 'unmarked';

function stateOf(r: AdminAttendanceRow): Exclude<Filter, ''> {
  return r.present === true ? 'present' : r.present === false ? 'absent' : 'unmarked';
}

/** Yoklama: liste + özet + elle düzeltme (sebep zorunlu; sertifika etkisi onay metninde yazar). */
export function AttendancePanel({ eventId }: { eventId: number }) {
  const i18n = useI18n();
  const { t, formatDateTime, formatNumber } = i18n;
  const [filter, setFilter] = useState<Filter>('');
  const [needle, setNeedle] = useState('');
  const q = useQuery({ queryKey: opsKey(eventId, 'attendance'), queryFn: () => getEventAttendance(eventId) });
  const data = q.data;
  const rows = useMemo(() => {
    const n = needle.trim().toLocaleLowerCase('tr');
    return (data?.rows ?? []).filter(
      (r) => (!filter || stateOf(r) === filter) && (!n || r.displayName.toLocaleLowerCase('tr').includes(n)),
    );
  }, [data, filter, needle]);
  const sm = data?.summary;

  function correct(r: AdminAttendanceRow, present: boolean) {
    const certNote =
      r.hasCertificate && !present
        ? t('admin.p07.att.certInvalidates')
        : r.certificateRevoked && present
          ? t('admin.p07.att.certStaysRevoked')
          : null;
    return (
      <GuardedAction
        size="sm"
        variant="secondary"
        title={t(present ? 'admin.p07.att.markPresent.title' : 'admin.p07.att.markAbsent.title', {
          name: r.displayName,
        })}
        consequence={
          <>
            {t('admin.p07.att.consequence')}
            {certNote && (
              <>
                <br />
                {certNote}
              </>
            )}
          </>
        }
        irreversible={false}
        requireReason
        confirmLabel={t('admin.p07.att.confirm')}
        errorMessage={(e) => eventErrorMessage(i18n, e)}
        successMessage={t('admin.p07.att.done')}
        invalidateKeys={opsInvalidate(eventId)}
        onConfirm={({ reason, idempotencyKey }) =>
          markEventAttendance(eventId, r.userId, present, { reason, idempotencyKey })
        }
      >
        {t(present ? 'admin.p07.att.markPresent' : 'admin.p07.att.markAbsent')}
      </GuardedAction>
    );
  }

  return (
    <section
      className={styles.panel}
      aria-label={t('admin.p07.tab.attendance')}
      data-testid="panel-attendance"
    >
      <div className={styles.bar}>
        <label>
          {t('admin.p07.att.search')}
          <Input value={needle} onChange={(e) => setNeedle(e.target.value)} />
        </label>
        <label>
          {t('admin.p07.att.filter')}
          <Select value={filter} onChange={(e) => setFilter(e.target.value as Filter)}>
            <option value="">{t('admin.p07.att.all')}</option>
            <option value="present">{t('admin.p07.att.state.present')}</option>
            <option value="absent">{t('admin.p07.att.state.absent')}</option>
            <option value="unmarked">{t('admin.p07.att.state.unmarked')}</option>
          </Select>
        </label>
        <CsvButton
          fetchCsv={() => exportEventAttendanceCsv(eventId)}
          filename={`event-${eventId}-attendance.csv`}
        />
      </div>
      {sm && (
        <dl className={styles.chips} data-testid="att-summary">
          {(['going', 'present', 'absent', 'unmarked', 'walkIns'] as const).map((k) => (
            <div key={k} className={styles.chip}>
              <dt>{t(`admin.p07.att.sum.${k}`)}</dt>
              <dd>{formatNumber(sm[k])}</dd>
            </div>
          ))}
        </dl>
      )}
      {data?.truncated && <p className={styles.muted}>{t('admin.p07.att.truncated')}</p>}
      <PanelState
        loading={q.isLoading}
        error={q.error}
        onRetry={() => void q.refetch()}
        empty={(data?.rows.length ?? 0) === 0}
        emptyTitle={t('admin.p07.att.empty')}
      >
        <div className={styles.scroll}>
          <table className={styles.table}>
            <thead>
              <tr>
                <th>{t('admin.p07.col.person')}</th>
                <th>{t('admin.p07.col.status')}</th>
                <th>{t('admin.p07.att.col.marked')}</th>
                <th>{t('admin.p07.col.actions')}</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => {
                const st = stateOf(r);
                return (
                  <tr key={r.userId} data-testid={`att-${r.userId}`}>
                    <td>
                      <div className={styles.name} dir="auto">
                        {r.displayName}
                      </div>
                      <div className={`${styles.sub} ltr`}>{r.emailMasked ?? '—'}</div>
                      <div className={styles.sub}>
                        {r.rsvp === 'WALK_IN' ? t('admin.p07.att.walkIn') : (r.department ?? '')}
                      </div>
                    </td>
                    <td>
                      <Badge tone={st === 'present' ? 'success' : st === 'absent' ? 'danger' : 'neutral'}>
                        {t(`admin.p07.att.state.${st}`)}
                      </Badge>
                      {r.hasCertificate && (
                        <div className={styles.sub}>
                          {t(
                            r.certificateRevoked ? 'admin.p07.att.cert.revoked' : 'admin.p07.att.cert.issued',
                          )}
                        </div>
                      )}
                    </td>
                    <td>
                      {r.markedAt ? (
                        <>
                          <div>{formatDateTime(r.markedAt)}</div>
                          <div className={styles.sub}>
                            {r.method === 'QR'
                              ? t('admin.p07.att.method.QR')
                              : t('admin.p07.att.method.MANUAL')}
                            {r.markedByName && r.method === 'MANUAL' ? ` · ${r.markedByName}` : ''}
                          </div>
                        </>
                      ) : (
                        '—'
                      )}
                    </td>
                    <td>
                      <div className={styles.actions}>
                        {st !== 'present' && correct(r, true)}
                        {st !== 'absent' && correct(r, false)}
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </PanelState>
    </section>
  );
}
