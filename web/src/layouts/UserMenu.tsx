import { useEffect, useId, useRef, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../auth/AuthProvider';
import { Avatar, Icon } from '../components/ui';
import { useI18n } from '../i18n/I18nProvider';
import { paths } from '../paths';
import styles from './UserMenu.module.css';

export function UserMenu() {
  const { t } = useI18n();
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  const btn = useRef<HTMLButtonElement>(null);
  const menuId = useId();

  useEffect(() => {
    if (!open) return;
    const onDown = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    };
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        setOpen(false);
        btn.current?.focus();
      }
    };
    // açılınca ilk öğeye odaklan (klavye ile erişim)
    ref.current?.querySelector<HTMLElement>('[data-menuitem]')?.focus();
    document.addEventListener('mousedown', onDown);
    document.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('mousedown', onDown);
      document.removeEventListener('keydown', onKey);
    };
  }, [open]);

  if (!user) return null;
  return (
    <div
      className={styles.wrap}
      ref={ref}
      onBlur={(e) => {
        // odak bileşenin dışına çıkınca kapat (Tab ile ayrılma)
        if (open && !e.currentTarget.contains(e.relatedTarget as Node | null)) setOpen(false);
      }}
    >
      <button
        ref={btn}
        type="button"
        className={styles.trigger}
        aria-expanded={open}
        aria-controls={menuId}
        onClick={() => setOpen((v) => !v)}
      >
        <span aria-hidden="true" className={styles.avatar}>
          <Avatar name={user.displayName || user.email} size={32} />
        </span>
        <span className={styles.name}>{user.displayName} </span>
        {/* ad dar ekranda gizlenir; erişilebilir ad içerikten gelir (Label in Name sorunu olmasın) */}
        <span className="sr-only">{t('admin.layout.userMenu')}</span>
        <Icon name="chevronDown" size={16} />
      </button>
      {open && (
        <div
          id={menuId}
          className={styles.menu}
          onKeyDown={(e) => {
            if (e.key !== 'ArrowDown' && e.key !== 'ArrowUp') return;
            const items = Array.from(e.currentTarget.querySelectorAll<HTMLElement>('[data-menuitem]'));
            const i = items.indexOf(document.activeElement as HTMLElement);
            e.preventDefault();
            items[(i + (e.key === 'ArrowDown' ? 1 : -1) + items.length) % items.length]?.focus();
          }}
        >
          <div className={styles.who}>
            <strong>{user.displayName}</strong>
            <span className="ltr">{user.email}</span>
            <span className={styles.role}>{t('admin.layout.roleAdmin')}</span>
          </div>
          <Link to={paths.site.home} className={styles.item} data-menuitem onClick={() => setOpen(false)}>
            <Icon name="external" size={18} />
            {t('admin.layout.viewSite')}
          </Link>
          <button
            type="button"
            className={styles.item}
            data-menuitem
            onClick={async () => {
              setOpen(false);
              await logout();
              navigate(paths.admin.login, { replace: true });
            }}
          >
            <Icon name="logout" size={18} />
            {t('admin.layout.logout')}
          </button>
        </div>
      )}
    </div>
  );
}
