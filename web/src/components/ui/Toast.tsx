import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from 'react';
import { createPortal } from 'react-dom';
import { useI18n } from '../../i18n/I18nProvider';
import { Icon } from './Icon';
import styles from './Toast.module.css';

export type ToastTone = 'success' | 'error' | 'info';
interface ToastItem {
  id: number;
  tone: ToastTone;
  message: string;
}

interface ToastApi {
  show: (message: string, tone?: ToastTone) => void;
  success: (message: string) => void;
  error: (message: string) => void;
  info: (message: string) => void;
}

const Ctx = createContext<ToastApi | null>(null);
const MAX = 4;

/** Bildirim kuyruğu: en çok 4 görünür, 5 sn sonra kapanır (hata 8 sn), `aria-live` ile okunur. */
export function ToastProvider({ children }: { children: ReactNode }) {
  const [items, setItems] = useState<ToastItem[]>([]);
  const seq = useRef(0);
  const { t } = useI18n();

  const dismiss = useCallback((id: number) => setItems((l) => l.filter((x) => x.id !== id)), []);
  const show = useCallback((message: string, tone: ToastTone = 'info') => {
    const id = ++seq.current;
    setItems((l) => [...l, { id, tone, message }].slice(-MAX));
  }, []);

  const api = useMemo<ToastApi>(
    () => ({
      show,
      success: (m) => show(m, 'success'),
      error: (m) => show(m, 'error'),
      info: (m) => show(m, 'info'),
    }),
    [show],
  );

  return (
    <Ctx.Provider value={api}>
      {children}
      {createPortal(
        <div className={styles.region} role="region" aria-label="Notifications">
          <div aria-live="polite" aria-atomic="false" className={styles.stack}>
            {items.map((it) => (
              <ToastView key={it.id} item={it} onDismiss={dismiss} dismissLabel={t('common.toast.dismiss')} />
            ))}
          </div>
        </div>,
        document.body,
      )}
    </Ctx.Provider>
  );
}

function ToastView({
  item,
  onDismiss,
  dismissLabel,
}: {
  item: ToastItem;
  onDismiss: (id: number) => void;
  dismissLabel: string;
}) {
  useEffect(() => {
    const timer = setTimeout(() => onDismiss(item.id), item.tone === 'error' ? 8000 : 5000);
    return () => clearTimeout(timer);
  }, [item, onDismiss]);
  return (
    <div className={`${styles.toast} ${styles[item.tone]}`} role={item.tone === 'error' ? 'alert' : 'status'}>
      <Icon name={item.tone === 'success' ? 'check' : item.tone === 'error' ? 'alert' : 'info'} size={18} />
      <span className={styles.msg}>{item.message}</span>
      <button
        type="button"
        className={styles.close}
        aria-label={dismissLabel}
        onClick={() => onDismiss(item.id)}
      >
        <Icon name="x" size={16} />
      </button>
    </div>
  );
}

export function useToast(): ToastApi {
  const v = useContext(Ctx);
  if (!v) throw new Error('useToast yalnızca <ToastProvider> içinde kullanılabilir');
  return v;
}
