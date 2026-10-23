import { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Icon, Modal } from '../components/ui';
import { useI18n } from '../i18n/I18nProvider';
import { allAdminNavItems } from './adminNav';
import styles from './QuickNav.module.css';

/** Ctrl/Cmd+K ile açılan sayfa arama penceresi. */
export function QuickNav({ open, onClose }: { open: boolean; onClose: () => void }) {
  const { t } = useI18n();
  const navigate = useNavigate();
  const [q, setQ] = useState('');
  const [active, setActive] = useState(0);

  const items = useMemo(() => {
    const needle = q.trim().toLocaleLowerCase();
    return allAdminNavItems
      .map((i) => ({ ...i, label: t(i.labelKey) }))
      .filter((i) => !needle || i.label.toLocaleLowerCase().includes(needle));
  }, [q, t]);

  useEffect(() => {
    if (open) {
      setQ('');
      setActive(0);
    }
  }, [open]);

  function go(to: string) {
    onClose();
    navigate(to);
  }

  return (
    <Modal open={open} onClose={onClose} title={t('admin.layout.search')} size="sm">
      <input
        data-autofocus
        className={styles.input}
        type="search"
        value={q}
        placeholder={t('admin.layout.searchHint')}
        aria-label={t('admin.layout.search')}
        onChange={(e) => {
          setQ(e.target.value);
          setActive(0);
        }}
        onKeyDown={(e) => {
          if (e.key === 'ArrowDown') {
            e.preventDefault();
            setActive((a) => Math.min(a + 1, items.length - 1));
          } else if (e.key === 'ArrowUp') {
            e.preventDefault();
            setActive((a) => Math.max(a - 1, 0));
          } else if (e.key === 'Enter' && items[active]) {
            e.preventDefault();
            go(items[active].to);
          }
        }}
      />
      {items.length === 0 ? (
        <p className={styles.empty}>{t('admin.layout.searchEmpty')}</p>
      ) : (
        <ul className={styles.list}>
          {items.map((i, idx) => (
            <li key={i.id}>
              <button
                type="button"
                className={`${styles.item} ${idx === active ? styles.on : ''}`}
                onClick={() => go(i.to)}
                onMouseEnter={() => setActive(idx)}
              >
                <Icon name={i.icon} size={18} />
                {i.label}
              </button>
            </li>
          ))}
        </ul>
      )}
    </Modal>
  );
}
