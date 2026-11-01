// Kuyruk sağlığı kartı (mail ve push için ortak): bekleyen / gönderilen / başarısız / ölü kayıtlar tek şeritte,
// durum rozeti ve tek cümlelik yorumla. Şerit satırları süzgece bağlanabilir (örn. "Ölü" -> listeyi ölülere daralt).
import type { ReactNode } from 'react';
import {
  StackedShare,
  type ShareSegment,
  type ShareTone,
} from '../../../components/kit/StackedShareIletisim';
import { Insight, StatusPill, useKitFormat } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { useIl } from './il';
import { queueHealth, queueProblems, type Health } from './logic';
import styles from './iletisim.module.css';

export interface QueueHealthProps {
  title: string;
  counts: { pending: number; sending?: number; failed: number; dead: number; skipped?: number };
  /** Durum adları (kuyruğa göre farklı sözlükten gelir). */
  labels: { pending: string; sending?: string; failed: string; dead: string; skipped?: string };
  /** Bekleyen en eski kaydın tarihi (varsa "en eski X önce" cümlesi). */
  oldestAt?: string | null;
  /** Son 24 saatte gönderilen (biliniyorsa). */
  sentLast24h?: number;
  /** Şerit satırına basınca süzgeci uygular (anahtarlar: pending, sending, failed, dead, skipped). */
  onSelect?: (key: string) => void;
  selectedKey?: string | null;
  ariaLabel: string;
  /** Kuyruk bilgi sayfası bağlantısı vb. için ek eylem. */
  actions?: ReactNode;
}

const TONE: Record<Health, 'success' | 'warning' | 'danger'> = {
  good: 'success',
  warn: 'warning',
  bad: 'danger',
};

export function QueueHealth({
  title,
  counts,
  labels,
  oldestAt,
  sentLast24h,
  onSelect,
  selectedKey,
  ariaLabel,
  actions,
}: QueueHealthProps) {
  const { formatNumber } = useI18n();
  const il = useIl();
  const kit = useKitFormat();
  const health = queueHealth(counts);
  const problems = queueProblems(counts);

  const seg = (
    key: string,
    label: string | undefined,
    value: number | undefined,
    tone: ShareTone,
  ): ShareSegment[] => (label === undefined || value === undefined ? [] : [{ key, label, value, tone }]);
  const segments: ShareSegment[] = [
    ...seg('pending', labels.pending, counts.pending, 'info'),
    ...seg('sending', labels.sending, counts.sending, 'primary'),
    ...seg('failed', labels.failed, counts.failed, 'warning'),
    ...seg('dead', labels.dead, counts.dead, 'danger'),
    ...seg('skipped', labels.skipped, counts.skipped, 'neutral'),
  ];

  const parts: (string | { text: string; tone?: 'warn' | 'bad' | 'good' })[] = [];
  if (health === 'bad')
    parts.push({ text: il('admin.il.qh.bad', { n: formatNumber(counts.dead) }), tone: 'bad' });
  else if (health === 'warn')
    parts.push({ text: il('admin.il.qh.warn', { n: formatNumber(counts.failed) }), tone: 'warn' });
  else parts.push({ text: il('admin.il.qh.good'), tone: 'good' });
  if (oldestAt && counts.pending > 0)
    parts.push(' ', il('admin.il.qh.oldest', { when: kit.relative(oldestAt) }));
  if (sentLast24h !== undefined) parts.push(' ', il('admin.il.qh.sent24', { n: formatNumber(sentLast24h) }));

  return (
    <section className={styles.healthBox} aria-label={title}>
      <div className={styles.healthHead}>
        <h2 className={styles.healthTitle}>{title}</h2>
        <div className={styles.healthMeta}>
          <StatusPill tone={TONE[health]}>{il(`admin.il.qh.status.${health}`)}</StatusPill>
          {actions}
        </div>
      </div>
      <Insight tone={health === 'bad' ? 'bad' : health === 'warn' ? 'warn' : 'good'} parts={parts} />
      <StackedShare segments={segments} ariaLabel={ariaLabel} onSelect={onSelect} selectedKey={selectedKey} />
      {problems > 0 && onSelect && <p className={styles.panelNote}>{il('admin.il.qh.hint')}</p>}
    </section>
  );
}
