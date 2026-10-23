import type { ReactNode } from 'react';
import { SearchInput } from './SearchInput';
import styles from './DataToolbar.module.css';

interface Props {
  onSearch?: (value: string) => void;
  searchDefault?: string;
  searchPlaceholder?: string;
  /** Filtre alanları (Select vb.) */
  filters?: ReactNode;
  /** Sağdaki eylemler (dışa aktar, yeni ekle...) */
  actions?: ReactNode;
}

/** Liste sayfaları için arama + filtre + eylem çubuğu. */
export function DataToolbar({ onSearch, searchDefault, searchPlaceholder, filters, actions }: Props) {
  return (
    <div className={styles.bar}>
      {onSearch && (
        <SearchInput onSearch={onSearch} defaultValue={searchDefault} placeholder={searchPlaceholder} />
      )}
      {filters && <div className={styles.filters}>{filters}</div>}
      {actions && <div className={styles.actions}>{actions}</div>}
    </div>
  );
}
