// Toplu mesaj gizleme (P08): seçim durumu + BulkBar. Yalnız görünür (hiç gizlenmemiş/silinmemiş) mesaj seçilebilir;
// en çok 200 mesaj. Onay: GuardedAction (sebep zorunlu + etki şeridi; 50'den fazlasında sayıyı yazdırır).
// Sunucu kısmi başarı döner (mesaj başına hata kodu): özet toast olarak gösterilir.
import { useCallback, useEffect, useState } from 'react';
import { adminChatApi } from '../../../api';
import type { AdminChatMessage } from '../../../api/types';
import { BulkBar, GuardedAction, useToast } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminError } from '../../../lib/errors';
import { BULK_HIDE_MAX, isBulkSelectable, pruneSelection, summarizeBulk, toggleSelection } from './chatAction';

export interface MessageSelection {
  selected: ReadonlySet<number>;
  clear: () => void;
  /** ChatBubble `select` prop'u: seçilebilir değilse null. */
  bubbleSelect: (m: AdminChatMessage) => { checked: boolean; onChange: (checked: boolean) => void; label: string } | null;
}

export function useMessageSelection(messages: readonly AdminChatMessage[], scope: unknown): MessageSelection {
  const { t } = useI18n();
  const [selected, setSelected] = useState<ReadonlySet<number>>(new Set());
  // Kapsam (sohbet/süzgeç) değişince ya da mesaj durumu değişince eskiyen seçim düşer.
  useEffect(() => {
    setSelected(new Set());
  }, [scope]);
  useEffect(() => {
    setSelected((cur) => {
      const next = pruneSelection(cur, messages);
      return next.size === cur.size ? cur : next;
    });
  }, [messages]);
  const clear = useCallback(() => setSelected(new Set()), []);
  const bubbleSelect = useCallback(
    (m: AdminChatMessage) =>
      isBulkSelectable(m)
        ? {
            checked: selected.has(m.id),
            onChange: (on: boolean) => setSelected((cur) => toggleSelection(cur, m.id, on)),
            label: t('admin.p08.select', { id: m.id }),
          }
        : null,
    [selected, t],
  );
  return { selected, clear, bubbleSelect };
}

export function MessageBulkBar({ selection }: { selection: MessageSelection }) {
  const i18n = useI18n();
  const { t } = i18n;
  const toast = useToast();
  const { selected, clear } = selection;
  return (
    <BulkBar count={selected.size} onClear={clear}>
      <GuardedAction
        size="sm"
        variant="secondary"
        title={t('admin.p08.bulk.title')}
        message={t('admin.p08.bulk.message')}
        consequence={t('admin.p08.bulk.consequence')}
        irreversible={false}
        requireReason
        impact={{ count: selected.size, noun: t('admin.p08.bulk.noun') }}
        successMessage={false}
        errorMessage={(e) => adminError(i18n, e)}
        invalidateKeys={[['adminChat']]}
        onSuccess={clear}
        disabled={selected.size > BULK_HIDE_MAX}
        onConfirm={async ({ reason, idempotencyKey }) => {
          const r = await adminChatApi.bulkHideMessages([...selected], reason, idempotencyKey);
          const s = summarizeBulk(r.items);
          if (s.failed === 0) {
            toast.success(t('admin.p08.bulk.done', { n: s.ok }));
          } else {
            toast.error(t('admin.p08.bulk.partial', { ok: s.ok, failed: s.failed, codes: s.codes.join(', ') || '?' }));
          }
          return r;
        }}
      >
        {t('admin.p08.bulk.btn')}
      </GuardedAction>
    </BulkBar>
  );
}
