import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { listUsers } from '../../../api/users';
import { Icon, IconButton, Input, Spinner } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { useDebouncedValue } from '../../../lib/hooks';
import { MAX_USERS, type PickedUser } from './lib';
import styles from './campaigns.module.css';

/** Kullanıcı arama (`GET /api/admin/users?q=`) + seçilenleri çip olarak gösterme (en çok 500). */
export function UserPicker({ value, onChange }: { value: PickedUser[]; onChange: (u: PickedUser[]) => void }) {
  const { t, formatNumber } = useI18n();
  const [text, setText] = useState('');
  const q = useDebouncedValue(text.trim(), 300);
  const search = useQuery({
    queryKey: ['campaigns', 'user-search', q],
    queryFn: () => listUsers({ q, size: 8, status: 'ACTIVE' }),
    enabled: q.length >= 2,
  });
  const picked = new Set(value.map((u) => u.id));
  const results = (search.data?.items ?? []).filter((u) => !picked.has(u.id));
  const full = value.length >= MAX_USERS;

  function add(u: PickedUser) {
    if (full || picked.has(u.id)) return;
    onChange([...value, u]);
  }

  return (
    <div className={styles.picker}>
      <div className={styles.pickerHead}>
        <label className={styles.fieldLabel} htmlFor="user-search">
          {t('admin.campaigns.users.search')}
        </label>
        <span className={`${styles.pickerCount} ${full ? styles.pickerFull : ''}`}>
          {t('admin.campaigns.users.count', { n: formatNumber(value.length), max: formatNumber(MAX_USERS) })}
        </span>
      </div>
      <Input
        id="user-search"
        type="search"
        autoComplete="off"
        value={text}
        disabled={full}
        placeholder={t('admin.campaigns.users.placeholder')}
        onChange={(e) => setText(e.target.value)}
      />
      {q.length >= 2 && (
        <div className={styles.results} aria-live="polite">
          {search.isFetching && <Spinner size="sm" />}
          {!search.isFetching && results.length === 0 && (
            <p className={styles.muted}>{t('admin.campaigns.users.none')}</p>
          )}
          {results.map((u) => (
            <button
              key={u.id}
              type="button"
              className={styles.resultRow}
              onClick={() => add({ id: u.id, displayName: u.displayName, email: u.email })}
            >
              <span className={styles.resultName}>{u.displayName}</span>
              <span className={`${styles.resultMail} ltr`}>{u.email}</span>
              <Icon name="plus" size={16} />
            </button>
          ))}
        </div>
      )}
      {value.length > 0 && (
        <ul className={styles.chips} aria-label={t('admin.campaigns.users.selected')}>
          {value.map((u) => (
            <li key={u.id} className={styles.chip}>
              <span className={styles.chipText} title={u.email}>
                <span className={styles.chipName}>{u.displayName || u.email}</span>
                <span className={`${styles.chipMail} ltr`}>{u.email}</span>
              </span>
              <IconButton
                label={t('admin.campaigns.users.remove', { name: u.displayName || u.email })}
                size="sm"
                onClick={() => onChange(value.filter((x) => x.id !== u.id))}
              >
                <Icon name="x" size={14} />
              </IconButton>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
