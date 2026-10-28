import { useCan } from '../../../auth/permissions';
import { useI18n } from '../../../i18n/I18nProvider';
import { Button, type ButtonProps } from '../../ui/Button';
import { Tooltip } from '../../ui/Tooltip';

/**
 * Yönetici izni (P16) gerektiren düğme: izin yoksa devre dışı kalır ve nedenini ipucunda söyler. Onay diyaloğu
 * olmayan tetikleyiciler (GuardedDialog/ConfirmDialog açan düğmeler) için; GuardedAction'ın kendi `permission` prop'u vardır.
 * UI gizlemesi güvenlik değildir; asıl denetim sunucudadır (403 ADMIN_PERMISSION_DENIED).
 */
export function PermissionButton({ permission, disabled, ...rest }: ButtonProps & { permission?: string }) {
  const { t } = useI18n();
  const allowed = useCan(permission);
  if (allowed) return <Button disabled={disabled} {...rest} />;
  return (
    <Tooltip text={t('admin.p16.noPermission', { perm: permission ?? '' })}>
      <Button {...rest} disabled />
    </Tooltip>
  );
}
