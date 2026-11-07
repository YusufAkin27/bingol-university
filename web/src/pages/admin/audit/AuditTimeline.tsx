// Denetim kaydı zaman çizelgesi görünümü: işlemler gün gün, saat damgası + eylem türü simgesi + insan diliyle işlem adı.
// Her satır bir düğmedir (klavyeyle açılır); ayrıntı çekmecesini açar. Reddedilen (403) ve hatalı işlemler renk + metinle ayrılır.
import { useMemo } from 'react';
import type { AuditRowV2 } from '../../../api/audit';
import { Icon, type IconName } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { describeAction } from './auditLogic';
import { groupByDay, istanbulParts, verbClass, type VerbClass } from './auditStats';
import { isDenied } from './status';
import { useGt } from '../sys2Dict';
import styles from './audit2.module.css';

const VERB_ICON: Record<VerbClass, IconName> = {
  READ: 'search',
  CREATE: 'plus',
  CHANGE: 'pencil',
  DELETE: 'ban',
};

export function AuditTimeline({ rows, onOpen }: { rows: readonly AuditRowV2[]; onOpen: (r: AuditRowV2) => void }) {
  const { t, td, formatDate } = useI18n();
  const gt = useGt();
  const groups = useMemo(() => groupByDay(rows), [rows]);
  return (
    <div className={styles.timeline} data-testid="audit-timeline">
      {groups.map((g) => (
        <section key={g.day} aria-label={g.day} className={styles.tlDay}>
          <h3 className={styles.tlDayTitle}>
            {g.day === '—' ? g.day : formatDate(`${g.day}T12:00:00+03:00`, { day: 'numeric', month: 'long', weekday: 'long' })}
            <span className={styles.tlCount}>{gt('admin.sys2.audit.tl.count', { n: g.rows.length })}</span>
          </h3>
          <ol className={styles.tlList}>
            {g.rows.map((r) => {
              const a = describeAction(td, r.method, r.path);
              const v = verbClass(r.method);
              const denied = isDenied(r.status);
              const bad = r.status >= 400;
              const time = istanbulParts(r.at);
              const clock = new Date(r.at).toLocaleTimeString('tr-TR', {
                hour: '2-digit',
                minute: '2-digit',
                timeZone: 'Europe/Istanbul',
              });
              return (
                <li key={r.id} className={styles.tlItem} data-tone={denied ? 'denied' : bad ? 'bad' : 'ok'}>
                  <span className={styles.tlDot} aria-hidden="true">
                    <Icon name={denied ? 'shield' : VERB_ICON[v]} size={14} />
                  </span>
                  <button
                    type="button"
                    className={styles.tlBtn}
                    onClick={() => onOpen(r)}
                    aria-label={t('admin.wp02.audit.openRow', { action: a.label })}
                  >
                    <span className={styles.tlTime}>{time ? clock : '—'}</span>
                    <span className={styles.tlMain}>
                      <span className={styles.tlAction}>{a.label}</span>
                      <span className={styles.tlMeta}>
                        {r.adminEmail === 'basic-admin' ? 'basic-admin' : (r.adminEmail ?? t('admin.audit.noAdmin'))}
                        {r.targetType ? ` · ${r.targetType}${r.targetId ? ` #${r.targetId}` : ''}` : ''}
                      </span>
                    </span>
                    {(denied || bad) && (
                      <span className={styles.tlStatus}>
                        {denied ? t('admin.audit.denied') : gt('admin.sys2.audit.tl.failed')} <span className="ltr">{r.status}</span>
                      </span>
                    )}
                  </button>
                </li>
              );
            })}
          </ol>
        </section>
      ))}
    </div>
  );
}
