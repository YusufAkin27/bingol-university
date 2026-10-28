import type { ReactNode } from 'react';
import { useI18n } from '../../../i18n/I18nProvider';
import { Icon } from '../../ui/Icon';
import styles from './guard.module.css';

/**
 * "Ne olacak, geri alınabilir mi" notu. `irreversible` true ise kırmızı uyarı satırı eklenir,
 * false ise nötr "geri alınabilir" satırı; verilmezse yalnız metin gösterilir.
 */
export function ConsequenceNote({
  id,
  irreversible,
  children,
}: {
  id?: string;
  irreversible?: boolean;
  children?: ReactNode;
}) {
  const { t } = useI18n();
  return (
    <div id={id} className={`${styles.consequence} ${irreversible ? styles.consequenceDanger : ''}`}>
      {children && <p className={styles.consequenceText}>{children}</p>}
      {irreversible === true && (
        <p className={styles.irreversible}>
          <Icon name="alert" size={16} aria-hidden="true" />
          <strong>{t('admin.guard.consequence.irreversible')}</strong>
        </p>
      )}
      {irreversible === false && (
        <p className={styles.reversible}>{t('admin.guard.consequence.reversible')}</p>
      )}
    </div>
  );
}
