// Denetim kaydı süzgeç çubuğu: serbest metin, yönetici, yöntem, durum, tarih aralığı, hedef türü/kimliği.
import { useQuery } from '@tanstack/react-query';
import { listUsers } from '../../../api/users';
import { qk } from '../../../api/queryKeys';
import { Button, FormField, Input, SearchInput, Select } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { DebouncedInput } from '../users/DebouncedInput';
import {
  AUDIT_METHODS,
  AUDIT_STATUS_OPTIONS,
  AUDIT_TARGET_TYPES,
  activeFilterCount,
  type AuditFilters,
} from './auditLogic';
import styles from './audit.module.css';

export function AuditFilterBar({
  value,
  onChange,
  onReset,
  resetKey = 0,
}: {
  value: AuditFilters;
  onChange: (patch: Partial<AuditFilters>) => void;
  onReset: () => void;
  /** Artınca serbest metin alanı sıfırlanır (filtreleri temizle). */
  resetKey?: number;
}) {
  const { t, td } = useI18n();
  const admins = useQuery({
    queryKey: qk.users.list({ role: 'ADMIN', size: 100 }),
    queryFn: () => listUsers({ role: 'ADMIN', size: 100 }),
    staleTime: 60_000,
  });
  const active = activeFilterCount(value);
  const knownTypes = (AUDIT_TARGET_TYPES as readonly string[]).includes(value.targetType) || !value.targetType
    ? AUDIT_TARGET_TYPES
    : [...AUDIT_TARGET_TYPES, value.targetType];
  const adminKnown = value.adminId === undefined || admins.data?.items.some((a) => a.id === value.adminId);

  return (
    <div className={styles.filters} role="group" aria-label={t('admin.audit.filters.label')}>
      <div className={styles.bar}>
        <div className={styles.search}>
          <SearchInput
            key={resetKey}
            defaultValue={value.q}
            placeholder={t('admin.wp02.audit.filter.q')}
            label={t('admin.wp02.audit.filter.q')}
            onSearch={(q) => onChange({ q })}
          />
        </div>
        <div className={styles.select}>
          <Select
            aria-label={t('admin.audit.filter.admin')}
            value={value.adminId === undefined ? '' : String(value.adminId)}
            onChange={(e) => onChange({ adminId: e.target.value ? Number(e.target.value) : undefined })}
          >
            <option value="">
              {t('admin.audit.filter.admin')}: {t('common.all')}
            </option>
            {admins.data?.items.map((a) => (
              <option key={a.id} value={a.id}>
                {a.email}
              </option>
            ))}
            {!adminKnown && <option value={value.adminId}>#{value.adminId}</option>}
          </Select>
        </div>
        <div className={styles.select}>
          <Select
            aria-label={t('admin.audit.filter.method')}
            value={value.method}
            onChange={(e) => onChange({ method: e.target.value })}
          >
            <option value="">
              {t('admin.audit.filter.method')}: {t('common.all')}
            </option>
            {AUDIT_METHODS.map((m) => (
              <option key={m} value={m}>
                {m}
              </option>
            ))}
          </Select>
        </div>
        <div className={styles.select}>
          <Select
            aria-label={t('admin.wp02.audit.filter.status')}
            value={value.status}
            onChange={(e) => onChange({ status: e.target.value })}
          >
            <option value="">
              {t('admin.wp02.audit.filter.status')}: {t('common.all')}
            </option>
            {AUDIT_STATUS_OPTIONS.map((s) => (
              <option key={s} value={s}>
                {td(`admin.wp02.audit.status.${s}`, s)}
              </option>
            ))}
          </Select>
        </div>
      </div>
      <div className={styles.bar}>
        <FormField label={t('admin.wp02.audit.filter.from')} className={styles.dateField}>
          <Input type="date" value={value.from} max={value.to || undefined} onChange={(e) => onChange({ from: e.target.value })} />
        </FormField>
        <FormField label={t('admin.wp02.audit.filter.to')} className={styles.dateField}>
          <Input type="date" value={value.to} min={value.from || undefined} onChange={(e) => onChange({ to: e.target.value })} />
        </FormField>
        <div className={styles.select}>
          <Select
            aria-label={t('admin.wp02.audit.filter.targetType')}
            value={value.targetType}
            onChange={(e) => onChange({ targetType: e.target.value })}
          >
            <option value="">
              {t('admin.wp02.audit.filter.targetType')}: {t('common.all')}
            </option>
            {knownTypes.map((ty) => (
              <option key={ty} value={ty}>
                {ty}
              </option>
            ))}
          </Select>
        </div>
        <div className={styles.select}>
          <DebouncedInput
            value={value.targetId}
            label={t('admin.wp02.audit.filter.targetId')}
            onCommit={(targetId) => onChange({ targetId })}
          />
        </div>
        <div className={styles.resetWrap}>
          {active > 0 && <span className={styles.muted}>{t('admin.wp02.audit.filter.activeCount', { n: active })}</span>}
          <Button variant="ghost" size="sm" onClick={onReset} disabled={active === 0}>
            {t('admin.wp02.audit.filter.reset')}
          </Button>
        </div>
      </div>
    </div>
  );
}
