// Denetim kaydı: hızlı süzgeç çipleri (Bugün, Reddedilenler...) + etkin süzgeçlerin kaldırılabilir çipleri.
// Süzgeç paneli kapalıyken de görünür; durum URL'dedir (AuditPage.update).
import { useQuery } from '@tanstack/react-query';
import { listUsers } from '../../../api/users';
import { qk } from '../../../api/queryKeys';
import { Icon } from '../../../components/ui';
import type { AuditFilters } from './auditLogic';
import {
  activeChips,
  presetActive,
  presetClearPatch,
  presetPatch,
  QUICK_PRESETS,
} from './auditQuick';
import { istanbulToday } from './auditStats';
import { useGt } from '../sys2Dict';
import styles from './audit2.module.css';

export function AuditQuickChips({
  value,
  onChange,
}: {
  value: AuditFilters;
  onChange: (patch: Partial<AuditFilters>) => void;
}) {
  const gt = useGt();
  const today = istanbulToday();
  // Yönetici adı çipte okunur olsun; aynı sorgu süzgeç çubuğunda da kullanılır (önbellekten gelir)
  const admins = useQuery({
    queryKey: qk.users.list({ role: 'ADMIN', size: 100 }),
    queryFn: () => listUsers({ role: 'ADMIN', size: 100 }),
    staleTime: 60_000,
  });
  const chips = activeChips(value, (id) => admins.data?.items.find((a) => a.id === id)?.email ?? `#${id}`);
  return (
    <div className={styles.quick} data-search-anchor="quick-filters">
      <div className={styles.chipRow} role="group" aria-label={gt('admin.sys2.audit.quick.label')}>
        {QUICK_PRESETS.map((id) => {
          const on = presetActive(id, value, today);
          return (
            <button
              key={id}
              type="button"
              className={`${styles.chip} ${on ? styles.chipOn : ''}`}
              aria-pressed={on}
              onClick={() => onChange(on ? presetClearPatch(id) : presetPatch(id, today))}
              data-testid={`audit-quick-${id}`}
            >
              {on && <Icon name="check" size={14} />}
              {gt(`admin.sys2.audit.quick.${id}`)}
            </button>
          );
        })}
      </div>
      {chips.length > 0 && (
        <ul className={styles.chipRow} aria-label={gt('admin.sys2.audit.active.label')} data-testid="audit-active-chips">
          {chips.map((c) => (
            <li key={c.id}>
              <button
                type="button"
                className={`${styles.chip} ${styles.chipActive}`}
                onClick={() => onChange(c.clear)}
                aria-label={gt('admin.sys2.audit.active.remove', { name: gt(c.nameKey), value: c.value })}
              >
                <span className={styles.chipName}>{gt(c.nameKey)}:</span> <span dir="auto">{c.value}</span>
                <Icon name="x" size={14} />
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
