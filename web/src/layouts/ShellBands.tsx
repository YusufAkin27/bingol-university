// Kabuk bantları (bakım modu + depolama uyarısı): telefonda ekranın ~%22'sini kaplıyordu. Burada tek satırlık kompakt hâle
// gelir; bakım iletisi dokununca açılır, depolama UYARISI (WARN) oturum boyunca gizlenebilir (KRİTİK her zaman görünür).
import { useRef, useState, type ReactNode } from 'react';
import { Icon } from '../components/ui';
import { useI18n } from '../i18n/I18nProvider';
import { readStorage, writeStorage } from '../lib/storage';
import styles from './AdminLayout.module.css';

const DISMISS_KEY = 'bu.admin.storageband';

/** Bakım modu bandı: başlık her zaman görünür; ileti dar ekranda tek satıra kısalır, dokununca tamamı açılır. */
export function MaintenanceBand({ message }: { message?: string | null }) {
  const { t } = useI18n();
  const [open, setOpen] = useState(false);
  return (
    <div className={styles.maintenance} role="status">
      <Icon name="alert" size={18} />
      <strong>{t('admin.layout.maintenance')}</strong>
      {message && (
        <button
          type="button"
          className={styles.maintenanceMsg}
          aria-expanded={open}
          data-open={open}
          title={open ? t('admin.layout.bandLess') : t('admin.layout.bandMore')}
          onClick={() => setOpen((o) => !o)}
        >
          <span className={styles.maintenanceText}>{message}</span>
        </button>
      )}
    </div>
  );
}

/**
 * Depolama bandı (StorageBanner) sarmalayıcısı: yalnız UYARI düzeyi kapatılabilir; durum KRİTİK'e çıkarsa yeniden görünür.
 * Bant kendi içinde karar verir (izin, eşik); sarmalayıcı yalnız çizilmişse düğmeyi gösterir (CSS :has + data-status).
 */
export function DismissibleBand({ children }: { children: ReactNode }) {
  const { t } = useI18n();
  const ref = useRef<HTMLDivElement>(null);
  const [dismissed, setDismissed] = useState<string | null>(() => readStorage('session', DISMISS_KEY));

  function dismiss() {
    const status =
      ref.current?.querySelector<HTMLElement>('[data-testid="storage-banner"]')?.getAttribute('data-status') ?? 'WARN';
    if (status !== 'WARN') return; // kritik uyarı kapatılamaz
    writeStorage('session', DISMISS_KEY, status);
    setDismissed(status);
  }

  return (
    <div ref={ref} className={styles.dismissable} data-dismissed={dismissed ?? undefined}>
      {children}
      <button type="button" className={styles.dismissBtn} aria-label={t('admin.layout.bandDismiss')} onClick={dismiss}>
        <Icon name="x" size={18} />
      </button>
    </div>
  );
}
