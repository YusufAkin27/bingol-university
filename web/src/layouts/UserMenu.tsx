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
    document.addEventListener('mousedown', onDown);
    document.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('mousedown', onDown);
      document.removeEventListener('keydown', onKey);
    };
  }, [open]);

  if (!user) return null;
  return (
    <div className={styles.wrap} ref={ref}>
      <button
        ref={btn}
        type="button"
        className={styles.trigger}
        aria-haspopup="true"
        aria-expanded={open}
        aria-controls={menuId}
        aria-label={t('admin.layout.userMenu')}
        onClick={() => setOpen((v) => !v)}
      >
        <Avatar name={user.displayName || user.email} size={32} />
        <span className={styles.name}>{user.displayName}</span>
        <Icon name="chevronDown" size={16} />
      </button>
      {open && (
        <div id={menuId} className={styles.menu}>
          <div className={styles.who}>
            <strong>{user.displayName}</strong>
            <span className="ltr">{user.email}</span>
            <span className={styles.role}>{t('admin.layout.roleAdmin')}</span>
          </div>
          <Link to={paths.site.home} className={styles.item} onClick={() => setOpen(false)}>
            <Icon name="external" size={18} />
            {t('admin.layout.viewSite')}
          </Link>
          <button
            type="button"
            className={styles.item}
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
