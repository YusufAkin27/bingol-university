import { useEffect, useId, useMemo, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Icon, Modal } from '../components/ui';
import { usePermissions } from '../auth/permissions';
import { useI18n } from '../i18n/I18nProvider';
import { adminNav, navMatches } from './adminNav';
import styles from './QuickNav.module.css';

/** Ctrl/Cmd+K ile açılan sayfa arama penceresi. */
export function QuickNav({ open, onClose }: { open: boolean; onClose: () => void }) {
  const { t } = useI18n();
  const perms = usePermissions();
  const navigate = useNavigate();
  const [q, setQ] = useState('');
  const [active, setActive] = useState(0);

  const listId = useId();
  const listRef = useRef<HTMLUListElement>(null);

  const items = useMemo(
    () =>
      adminNav
        .flatMap((g) => g.items.map((i) => ({ ...i, label: t(i.labelKey), group: t(g.labelKey) })))
        .filter((i) => perms.can(i.perm))
        .filter((i) => navMatches(`${i.label} ${i.group}`, q)),
    [q, t, perms],
  );

  useEffect(() => {
    if (open) {
      setQ('');
      setActive(0);
    }
  }, [open]);

  // Ok tuşlarıyla seçilen satır görünür kalsın
  useEffect(() => {
    listRef.current?.querySelector<HTMLElement>('[data-active="true"]')?.scrollIntoView?.({ block: 'nearest' });
  }, [active]);

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
        role="combobox"
        aria-expanded="true"
        aria-controls={listId}
        aria-autocomplete="list"
        aria-activedescendant={items[active] ? `${listId}-${items[active].id}` : undefined}
        autoComplete="off"
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
        <ul className={styles.list} id={listId} role="listbox" aria-label={t('admin.layout.search')} ref={listRef}>
          {items.map((i, idx) => (
            <li
              key={i.id}
              id={`${listId}-${i.id}`}
              role="option"
              aria-selected={idx === active}
              data-active={idx === active}
              className={`${styles.item} ${idx === active ? styles.on : ''}`}
              onClick={() => go(i.to)}
              onMouseEnter={() => setActive(idx)}
            >
              <Icon name={i.icon} size={18} />
              <span className={styles.label}>{i.label}</span>
              <span className={styles.group}>{i.group}</span>
            </li>
          ))}
        </ul>
      )}
    </Modal>
  );
}
