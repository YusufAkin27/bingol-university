import { lazy, Suspense } from 'react';

const Modal = lazy(() => import('./CookiePrefsModal').then((m) => ({ default: m.CookiePrefsModal })));

/** Tercih penceresi yalnız açılınca indirilir (ana pakete girmez). */
export function CookiePrefs({ open, onClose }: { open: boolean; onClose: () => void }) {
  if (!open) return null;
  return (
    <Suspense fallback={null}>
      <Modal open onClose={onClose} />
    </Suspense>
  );
}
