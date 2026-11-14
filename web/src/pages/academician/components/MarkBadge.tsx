import type { Mark } from '../../../api/academician';
import { Badge, Icon, type IconName, type Tone } from '../../../components/ui';
import { useT } from '../dict';

const MARKS: Record<Mark, { icon: IconName; tone: Tone; key: string }> = {
  PRESENT_QR: { icon: 'check', tone: 'success', key: 'ac.mark.PRESENT_QR' },
  PRESENT_MANUAL: { icon: 'pencil', tone: 'success', key: 'ac.mark.PRESENT_MANUAL' },
  EXCUSED: { icon: 'clipboard', tone: 'info', key: 'ac.mark.EXCUSED' },
  REVOKED: { icon: 'ban', tone: 'warning', key: 'ac.mark.REVOKED' },
  ABSENT: { icon: 'x', tone: 'neutral', key: 'ac.mark.ABSENT' },
  NOT_ENROLLED_YET: { icon: 'lock', tone: 'neutral', key: 'ac.mark.NOT_ENROLLED_YET' },
};

/** Yoklama durumu: renge ek olarak simge + metin taşır (renk tek başına anlam taşımaz). `provisional`: açık oturum, "yok" henüz kesin değil. */
export function MarkBadge({ mark, provisional }: { mark: Mark; provisional?: boolean }) {
  const t = useT();
  const m = MARKS[mark];
  const label = provisional && mark === 'ABSENT' ? t('ac.mark.PROVISIONAL') : t(m.key);
  return (
    <Badge tone={m.tone}>
      <Icon name={m.icon} size={14} aria-hidden="true" /> {label}
    </Badge>
  );
}

export const isPresent = (m: Mark | undefined): boolean => m === 'PRESENT_QR' || m === 'PRESENT_MANUAL';

export const MARK_ORDER: Mark[] = ['PRESENT_QR', 'PRESENT_MANUAL', 'EXCUSED', 'REVOKED', 'ABSENT', 'NOT_ENROLLED_YET'];

/** Matris açıklaması: altı durumun simgesi + adı (renkten bağımsız). */
export function MarkLegend() {
  const t = useT();
  return (
    <ul aria-label={t('ac.legend.aria')} style={{ listStyle: 'none', display: 'flex', flexWrap: 'wrap', gap: 'var(--space-2)', margin: 0, padding: 0 }}>
      {MARK_ORDER.map((m) => (
        <li key={m}>
          <MarkBadge mark={m} />
        </li>
      ))}
    </ul>
  );
}
