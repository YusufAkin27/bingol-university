import { useEffect, useRef, useState } from 'react';
import { useI18n } from '../../i18n/I18nProvider';
import { useDebouncedValue } from '../../lib/hooks';
import { Icon } from './Icon';
import styles from './SearchInput.module.css';

interface Props {
  /** Debounce sonrası çağrılır. */
  onSearch: (value: string) => void;
  defaultValue?: string;
  placeholder?: string;
  delay?: number;
  label?: string;
}

export function SearchInput({ onSearch, defaultValue = '', placeholder, delay = 300, label }: Props) {
  const { t } = useI18n();
  const [text, setText] = useState(defaultValue);
  const debounced = useDebouncedValue(text, delay);
  const last = useRef(defaultValue);
  const cb = useRef(onSearch);
  cb.current = onSearch;

  useEffect(() => {
    if (debounced !== last.current) {
      last.current = debounced;
      cb.current(debounced.trim());
    }
  }, [debounced]);

  return (
    <div className={styles.wrap} role="search">
      <span className={styles.icon} aria-hidden="true">
        <Icon name="search" size={18} />
      </span>
      <input
        type="search"
        className={styles.input}
        value={text}
        placeholder={placeholder ?? t('common.searchPlaceholder')}
        aria-label={label ?? t('common.search')}
        onChange={(e) => setText(e.target.value)}
      />
      {text && (
        <button
          type="button"
          className={styles.clear}
          aria-label={t('common.clearSearch')}
          onClick={() => {
            setText('');
          }}
        >
          <Icon name="x" size={16} />
        </button>
      )}
    </div>
  );
}
