import { useEffect, useId, useRef, type ReactNode, type RefObject } from 'react';
import { createPortal } from 'react-dom';
import { useI18n } from '../../i18n/I18nProvider';
import { Button, IconButton } from './Button';
import { Icon } from './Icon';
import { ConsequenceNote } from '../admin/guard/ConsequenceNote';
import styles from './Overlay.module.css';

const FOCUSABLE =
  'a[href], button:not([disabled]), textarea:not([disabled]), input:not([disabled]), select:not([disabled]), [tabindex]:not([tabindex="-1"])';

/** Odak tuzağı: Tab/Shift+Tab kabın içinde döner, ESC kapatır, kapanınca odak tetikleyiciye döner. */
export function useFocusTrap(ref: RefObject<HTMLElement>, active: boolean, onEscape: () => void) {
  const escRef = useRef(onEscape);
  escRef.current = onEscape;
  useEffect(() => {
    if (!active) return;
    const node = ref.current;
    if (!node) return;
    const previouslyFocused = document.activeElement as HTMLElement | null;
    const first =
      node.querySelector<HTMLElement>('[data-autofocus]') ?? node.querySelector<HTMLElement>(FOCUSABLE);
    (first ?? node).focus();

    function onKey(e: KeyboardEvent) {
      if (e.key === 'Escape') {
        e.stopPropagation();
        escRef.current();
        return;
      }
      if (e.key !== 'Tab' || !node) return;
      const items = Array.from(node.querySelectorAll<HTMLElement>(FOCUSABLE));
      if (items.length === 0) {
        e.preventDefault();
        return;
      }
      const a = items[0];
      const z = items[items.length - 1];
      if (e.shiftKey && (document.activeElement === a || document.activeElement === node)) {
        e.preventDefault();
        z.focus();
      } else if (!e.shiftKey && document.activeElement === z) {
        e.preventDefault();
        a.focus();
      }
    }
    document.addEventListener('keydown', onKey, true);
    const prevOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    return () => {
      document.removeEventListener('keydown', onKey, true);
      document.body.style.overflow = prevOverflow;
      previouslyFocused?.focus?.();
    };
  }, [active, ref]);
}

interface BaseProps {
  open: boolean;
  onClose: () => void;
  title: ReactNode;
  children: ReactNode;
  footer?: ReactNode;
  /** Yıkıcı onaylarda 'alertdialog' (ekran okuyucu içeriği hemen okur). Varsayılan 'dialog'. */
  role?: 'dialog' | 'alertdialog';
  /** aria-describedby: açıklayıcı metin öğelerinin kimlikleri (boşlukla ayrılmış). */
  describedBy?: string;
}

function Panel({
  open,
  onClose,
  title,
  children,
  footer,
  variant,
  size = 'md',
  role = 'dialog',
  describedBy,
}: BaseProps & { variant: 'modal' | 'drawer'; size?: 'sm' | 'md' | 'lg' }) {
  const ref = useRef<HTMLDivElement>(null);
  const titleId = useId();
  const { t } = useI18n();
  useFocusTrap(ref, open, onClose);
  if (!open) return null;
  return createPortal(
    <div className={styles.scrim} onMouseDown={(e) => e.target === e.currentTarget && onClose()}>
      <div
        ref={ref}
        role={role}
        aria-modal="true"
        aria-labelledby={titleId}
        aria-describedby={describedBy}
        tabIndex={-1}
        className={`${styles.panel} ${styles[variant]} ${styles[size]}`}
      >
        <header className={styles.head}>
          <h2 id={titleId} className={styles.title}>
            {title}
          </h2>
          <IconButton label={t('common.close')} size="sm" onClick={onClose}>
            <Icon name="x" size={18} />
          </IconButton>
        </header>
        <div className={styles.body}>{children}</div>
        {footer && <footer className={styles.foot}>{footer}</footer>}
      </div>
    </div>,
    document.body,
  );
}

export function Modal(props: BaseProps & { size?: 'sm' | 'md' | 'lg' }) {
  return <Panel {...props} variant="modal" />;
}

/** Kenardan açılan panel (varsayılan: satır sonu tarafı; RTL'de otomatik tersine döner). */
export function Drawer(props: BaseProps & { size?: 'sm' | 'md' | 'lg' }) {
  return <Panel {...props} variant="drawer" />;
}

interface ConfirmProps {
  open: boolean;
  onClose: () => void;
  onConfirm: () => void;
  title: string;
  message?: ReactNode;
  confirmLabel?: string;
  cancelLabel?: string;
  danger?: boolean;
  loading?: boolean;
  /** Ne olacak / geri alınabilir mi metni. `irreversible` true ise kırmızı 'geri alınamaz' satırı eklenir. */
  consequence?: ReactNode;
  irreversible?: boolean;
  /** Mesajın altına konan ek alanlar (sebep, yazarak onay...). */
  children?: ReactNode;
  /** Onay düğmesini kapatır (alanlar geçerli değilken). */
  confirmDisabled?: boolean;
  /** Yıkıcı eylemlerde 'alertdialog'. Varsayılan 'dialog' (geriye uyumlu). */
  role?: 'dialog' | 'alertdialog';
  /** İlk odak: onay düğmesi (varsayılan), vazgeç düğmesi ya da içerikteki [data-autofocus] alanı. */
  initialFocus?: 'confirm' | 'cancel' | 'content';
}

export function ConfirmDialog({
  open,
  onClose,
  onConfirm,
  title,
  message,
  confirmLabel,
  cancelLabel,
  danger,
  loading,
  consequence,
  irreversible,
  children,
  confirmDisabled,
  role,
  initialFocus = 'confirm',
}: ConfirmProps) {
  const { t } = useI18n();
  const uid = useId();
  const messageId = `${uid}-msg`;
  const consequenceId = `${uid}-cons`;
  const hasConsequence = consequence !== undefined || irreversible !== undefined;
  const describedBy = [message ? messageId : null, hasConsequence ? consequenceId : null].filter(Boolean).join(' ');
  return (
    <Modal
      open={open}
      onClose={onClose}
      title={title}
      size="sm"
      role={role}
      describedBy={describedBy || undefined}
      footer={
        <>
          <Button variant="secondary" onClick={onClose} data-autofocus={initialFocus === 'cancel' ? true : undefined}>
            {cancelLabel ?? t('common.cancel')}
          </Button>
          <Button
            variant={danger ? 'danger' : 'primary'}
            loading={loading}
            disabled={confirmDisabled}
            onClick={onConfirm}
            data-autofocus={initialFocus === 'confirm' ? true : undefined}
          >
            {confirmLabel ?? t('common.confirm')}
          </Button>
        </>
      }
    >
      {message && <p id={messageId}>{message}</p>}
      {hasConsequence && (
        <ConsequenceNote id={consequenceId} irreversible={irreversible}>
          {consequence}
        </ConsequenceNote>
      )}
      {children}
    </Modal>
  );
}
