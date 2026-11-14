import type { Mark } from '../../../api/academician';
import { Badge, Icon, type IconName, type Tone } from '../../../components/ui';
import { useT } from '../dict';

const MARKS: Record<Mark, { icon: IconName; tone: Tone; key: string }> = {
  PRESENT_QR: { icon: 'check', tone: 'success', key: 'ac.mark.PRESENT_QR' },
  PRESENT_MANUAL: { icon: 'pencil', tone: 'success', key: 'ac.mark.PRESENT_MANUAL' },
  REVOKED: { icon: 'ban', tone: 'warning', key: 'ac.mark.REVOKED' },
  ABSENT: { icon: 'x', tone: 'neutral', key: 'ac.mark.ABSENT' },
};

/** Yoklama durumu: renge ek olarak simge + metin taşır (renk tek başına anlam taşımaz). */
export function MarkBadge({ mark }: { mark: Mark }) {
  const t = useT();
  const m = MARKS[mark];
  return (
    <Badge tone={m.tone}>
      <Icon name={m.icon} size={14} aria-hidden="true" /> {t(m.key)}
    </Badge>
  );
}

export const isPresent = (m: Mark | undefined): boolean => m === 'PRESENT_QR' || m === 'PRESENT_MANUAL';
