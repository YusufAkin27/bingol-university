import { useCallback, useEffect, useRef, useState, type ReactElement } from 'react';
import { useI18n } from '../../../i18n/I18nProvider';
import { ConfirmDialog } from '../../ui/Overlay';

export interface UnsavedGuard {
  /** Sayfanın JSX'ine yerleştirin; kaydedilmemiş değişiklik uyarı diyaloğunu çizer. */
  dialog: ReactElement;
  /** Programatik çıkışlar (navigate, "Kapat" düğmesi) için: temizse hemen, kirliyse onayla çalıştırır. */
  confirmLeave: (action: () => void) => void;
}

/**
 * Kaydedilmemiş değişiklik koruması. `dirty` iken:
 *  - sekme kapatma/yenileme için tarayıcının `beforeunload` uyarısı,
 *  - uygulama içi bağlantı (`<a href>`, `<Link>`) tıklamaları yakalanıp onay diyaloğu gösterilir
 *    (onaylanırsa tıklama yeniden gönderilir; böylece router/basename davranışı bozulmaz).
 * Not: uygulama `BrowserRouter` kullandığı için react-router `useBlocker` (veri yönlendirici ister)
 * kullanılamaz; tarayıcı geri/ileri düğmesi `beforeunload` kapsamı dışındadır, programatik çıkışlar
 * için `confirmLeave` kullanın.
 */
export function useUnsavedGuard(dirty: boolean): UnsavedGuard {
  const { t } = useI18n();
  const [pending, setPending] = useState<(() => void) | null>(null);
  const bypass = useRef(false);

  useEffect(() => {
    if (!dirty) return;
    const onBeforeUnload = (e: BeforeUnloadEvent) => {
      e.preventDefault();
      e.returnValue = ''; // eski tarayıcılar için
    };
    const onClick = (e: MouseEvent) => {
      if (bypass.current || e.defaultPrevented || e.button !== 0) return;
      if (e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
      const anchor = (e.target as Element | null)?.closest?.('a[href]') as HTMLAnchorElement | null;
      if (!anchor) return;
      if (anchor.target && anchor.target !== '_self') return;
      if (anchor.hasAttribute('download')) return;
      let url: URL;
      try {
        url = new URL(anchor.href, window.location.href);
      } catch {
        return;
      }
      if (url.origin !== window.location.origin) return;
      if (url.pathname === window.location.pathname && url.search === window.location.search) return; // yalnız #hash
      e.preventDefault();
      e.stopPropagation();
      setPending(() => () => {
        bypass.current = true;
        try {
          anchor.click();
        } finally {
          bypass.current = false;
        }
      });
    };
    window.addEventListener('beforeunload', onBeforeUnload);
    document.addEventListener('click', onClick, true);
    return () => {
      window.removeEventListener('beforeunload', onBeforeUnload);
      document.removeEventListener('click', onClick, true);
    };
  }, [dirty]);

  const confirmLeave = useCallback(
    (action: () => void) => {
      if (dirty) setPending(() => action);
      else action();
    },
    [dirty],
  );

  const dialog = (
    <ConfirmDialog
      open={pending !== null}
      onClose={() => setPending(null)}
      onConfirm={() => {
        const go = pending;
        setPending(null);
        go?.();
      }}
      title={t('admin.guard.unsaved.title')}
      message={t('admin.guard.unsaved.message')}
      confirmLabel={t('admin.guard.unsaved.leave')}
      cancelLabel={t('admin.guard.unsaved.stay')}
      danger
      role="alertdialog"
      initialFocus="cancel"
    />
  );
  return { dialog, confirmLeave };
}
