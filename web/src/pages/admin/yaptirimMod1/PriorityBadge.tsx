import { useGt } from './dict';
import type { Urgency } from './queueLogic';
import styles from './yaptirim.module.css';

const CLS: Record<Urgency, string> = {
  urgent: styles.prioUrgent,
  attention: styles.prioAttention,
  normal: styles.prioNormal,
};

/** Öncelik rozeti: nokta + metin (acil, dikkat, yeni); renk tek başına anlam taşımaz. */
export function PriorityBadge({ urgency }: { urgency: Urgency }) {
  const gt = useGt();
  return <span className={`${styles.prio} ${CLS[urgency]}`}>{gt(`admin.mod1.prio.${urgency}`)}</span>;
}
