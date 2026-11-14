// Bir öğrencinin bir oturumdaki durumunu değiştiren TEK denetim: "Var" / "İzinli" / "Yok" (üç seçenekli grup). Oturum ayrıntısı,
// canlı ekran araması ve listeler aynısını kullanır. "Kayıtlı değildi" hücreleri düzenlenemez (denetim çizilmez).
import type { Mark } from '../../../api/academician';
import { useT } from '../dict';
import styles from '../academician.module.css';

export type Choice = 'PRESENT' | 'EXCUSED' | 'ABSENT';

export const choiceOf = (m: Mark | undefined): Choice | null =>
  m === 'PRESENT_QR' || m === 'PRESENT_MANUAL' ? 'PRESENT' : m === 'EXCUSED' ? 'EXCUSED' : m === 'NOT_ENROLLED_YET' ? null : 'ABSENT';

export function StateControl({
  name,
  mark,
  onChoose,
  busy,
}: {
  name: string;
  mark: Mark | undefined;
  /** Seçilen yeni durum (mevcut durumun yeniden seçilmesi çağrılmaz). */
  onChoose: (c: Choice) => void;
  busy?: boolean;
}) {
  const t = useT();
  const cur = choiceOf(mark);
  if (cur === null) return <span className={styles.muted}>{t('ac.mark.NOT_ENROLLED_YET')}</span>;
  const options: Choice[] = ['PRESENT', 'EXCUSED', 'ABSENT'];
  return (
    <div className={styles.segmented} role="group" aria-label={t('ac.state.groupAria', { name })} data-busy={busy || undefined}>
      {options.map((c) => (
        <button
          key={c}
          type="button"
          className={styles.segment}
          aria-pressed={cur === c}
          aria-label={t(`ac.state.${c}.aria`, { name })}
          disabled={busy}
          onClick={() => cur !== c && onChoose(c)}
        >
          {t(`ac.state.${c}`)}
        </button>
      ))}
    </div>
  );
}
