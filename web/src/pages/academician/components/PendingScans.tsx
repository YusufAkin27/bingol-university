// "Kayıtlı değil" listesi: geçerli kodu okutan ama derse kayıtlı olmayan öğrenciler. Her satırda "Derse ekle ve var say" ve
// "Yok say". API: POST /academician/sessions/{id}/pending/{studentId}/accept | dismiss (kapalı oturumda da çalışır).
import { useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import { acceptPending, dismissPending, type PendingScan } from '../../../api/academician';
import { Badge, Button, Icon, useToast } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { useT } from '../dict';
import { acadError } from '../errors';
import { fmtTime } from '../format';
import styles from '../academician.module.css';

export function PendingScans({
  sessionId,
  items,
  onChanged,
  headingLevel = 3,
}: {
  sessionId: number;
  items: PendingScan[];
  /** Karar verilince (üst bileşen listeyi/sayıları yeniler). */
  onChanged: (kind: 'accept' | 'dismiss', s: PendingScan) => void;
  headingLevel?: 2 | 3;
}) {
  const i18n = useI18n();
  const t = useT();
  const toast = useToast();
  const [busyId, setBusyId] = useState<number | null>(null);
  const H = `h${headingLevel}` as 'h2' | 'h3';

  const decide = useMutation({
    mutationFn: async ({ kind, s }: { kind: 'accept' | 'dismiss'; s: PendingScan }): Promise<void> => {
      if (kind === 'accept') await acceptPending(sessionId, s.studentId);
      else await dismissPending(sessionId, s.studentId);
    },
    onMutate: ({ s }) => setBusyId(s.studentId),
    onSuccess: (_r, { kind, s }) => {
      toast.success(kind === 'accept' ? t('ac.pending.accepted', { name: s.displayName }) : t('ac.pending.dismissed', { name: s.displayName }));
      onChanged(kind, s);
    },
    onError: (e) => toast.error(acadError(i18n, e)),
    onSettled: () => setBusyId(null),
  });

  if (items.length === 0) return null;
  return (
    <section className={styles.pendingBox} aria-labelledby={`pend-h-${sessionId}`}>
      <H id={`pend-h-${sessionId}`} className={styles.subHeading}>
        {t('ac.scans.title')} <Badge tone="warning">{items.length}</Badge>
      </H>
      <p className={styles.muted}>{t('ac.scans.hint')}</p>
      <ul className={styles.rows}>
        {items.map((s) => (
          <li key={s.studentId} className={styles.row}>
            <div className={styles.rowMain}>
              <span className={styles.rowTitle}>{s.displayName}</span>
              <span className={styles.muted}>
                <span className="ltr">{s.studentNo ?? '—'}</span> · {[s.department, s.grade].filter(Boolean).join(' · ') || t('ac.scans.noDept')} · {fmtTime(s.scannedAt)}
              </span>
            </div>
            <div className={styles.rowActions}>
              <Button size="sm" loading={busyId === s.studentId && decide.variables?.kind === 'accept'} disabled={busyId !== null} leftIcon={<Icon name="check" size={16} />} onClick={() => decide.mutate({ kind: 'accept', s })} aria-label={t('ac.scans.acceptAria', { name: s.displayName })}>
                {t('ac.scans.accept')}
              </Button>
              <Button size="sm" variant="secondary" loading={busyId === s.studentId && decide.variables?.kind === 'dismiss'} disabled={busyId !== null} onClick={() => decide.mutate({ kind: 'dismiss', s })} aria-label={t('ac.scans.dismissAria', { name: s.displayName })}>
                {t('ac.scans.dismiss')}
              </Button>
            </div>
          </li>
        ))}
      </ul>
    </section>
  );
}
