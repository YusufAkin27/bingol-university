// Öğrenci durumunu değiştirme eylemleri (Var / İzinli / Yok): doğru isteği seçer, "var"ı kaldırmak için onay ister. Oturum ayrıntısı ve
// canlı ekran aynı kancayı kullanır. İstekler: PUT .../records/{id} (var), PUT ... {excused:true} (izinli), DELETE (yok).
import { useState, type ReactNode } from 'react';
import { useMutation } from '@tanstack/react-query';
import { markExcused, markPresent, removeRecord, type Mark } from '../../../api/academician';
import { ConfirmDialog, useToast } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { useT } from '../dict';
import { acadError } from '../errors';
import { isPresent } from './MarkBadge';
import type { Choice } from './StateControl';

interface Target {
  studentId: number;
  name: string;
}

export function useMarkActions(sessionId: number, onChanged: () => void): { choose: (s: Target, current: Mark | undefined, c: Choice) => void; busyId: number | null; dialog: ReactNode } {
  const i18n = useI18n();
  const t = useT();
  const toast = useToast();
  const [confirm, setConfirm] = useState<Target | null>(null);

  const run = useMutation({
    mutationFn: async ({ s, c }: { s: Target; c: Choice; current: Mark | undefined }): Promise<void> => {
      if (c === 'PRESENT') await markPresent(sessionId, s.studentId);
      else if (c === 'EXCUSED') await markExcused(sessionId, s.studentId);
      else await removeRecord(sessionId, s.studentId);
    },
    onSuccess: (_r, { s, c, current }) => {
      toast.success(
        c === 'PRESENT'
          ? current === 'REVOKED'
            ? t('ac.detail.restored', { name: s.name })
            : t('ac.detail.marked', { name: s.name })
          : c === 'EXCUSED'
            ? t('ac.detail.excusedDone', { name: s.name })
            : t('ac.detail.removed', { name: s.name }),
      );
      setConfirm(null);
      onChanged();
    },
    onError: (e) => {
      toast.error(acadError(i18n, e));
      setConfirm(null);
    },
  });

  const choose = (s: Target, current: Mark | undefined, c: Choice) => {
    if (c === 'ABSENT' && isPresent(current)) setConfirm(s); // geçerli "var" kaydını kaldırmak onay ister
    else run.mutate({ s, c, current });
  };

  const dialog = (
    <ConfirmDialog
      open={!!confirm}
      onClose={() => setConfirm(null)}
      onConfirm={() => confirm && run.mutate({ s: confirm, c: 'ABSENT', current: 'PRESENT_QR' })}
      loading={run.isPending}
      danger
      role="alertdialog"
      title={t('ac.detail.removeTitle', { name: confirm?.name ?? '' })}
      message={t('ac.detail.removeText')}
      consequence={t('ac.detail.removeConsequence')}
      confirmLabel={t('ac.detail.remove')}
      initialFocus="cancel"
    />
  );
  return { choose, busyId: run.isPending ? (run.variables?.s.studentId ?? null) : null, dialog };
}
