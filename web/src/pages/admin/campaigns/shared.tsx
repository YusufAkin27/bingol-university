/** Kampanya, ayar ve onay sayfalarının ortak küçük bileşenleri: Callout, RadioCards, hata çevirisi. */
import type { ReactNode } from 'react';
import { isApiError } from '../../../api/client';
import type { I18n } from '../../../i18n/I18nProvider';
import { errorMessage } from '../../../lib/errors';
import { Icon } from '../../../components/ui';
import styles from './shared.module.css';

/** Hata kodunu önce bu sayfaların `admin.err.<KOD>` çevirisinden, yoksa genel hata çevirisinden üretir. */
export function adminErrorMessage(i18n: Pick<I18n, 't' | 'td'>, e: unknown): string {
  if (isApiError(e)) {
    const own = i18n.td(`admin.err.${e.code}`, '');
    if (own) return own;
  }
  return errorMessage(i18n, e);
}

export function Callout({
  tone = 'info',
  title,
  children,
  role,
}: {
  tone?: 'info' | 'warning' | 'danger' | 'success';
  title?: ReactNode;
  children?: ReactNode;
  role?: 'alert' | 'status';
}) {
  return (
    <div className={`${styles.callout} ${styles[tone]}`} role={role}>
      <span className={styles.calloutIcon} aria-hidden="true">
        <Icon name={tone === 'info' ? 'info' : tone === 'success' ? 'check' : 'alert'} size={18} />
      </span>
      <div className={styles.calloutText}>
        {title && <p className={styles.calloutTitle}>{title}</p>}
        {children && <div>{children}</div>}
      </div>
    </div>
  );
}

export interface RadioOption<V extends string> {
  value: V;
  label: ReactNode;
  hint?: ReactNode;
  tone?: 'danger';
}

/** Kart görünümlü radyo grubu (yerel radio girdileri: ok tuşları ve klavye hazır). */
export function RadioCards<V extends string>({
  name,
  legend,
  value,
  options,
  onChange,
  columns = 3,
}: {
  name: string;
  legend: string;
  value: V;
  options: RadioOption<V>[];
  onChange: (v: V) => void;
  columns?: 2 | 3;
}) {
  return (
    <fieldset className={styles.radioSet}>
      <legend className="sr-only">{legend}</legend>
      <div className={`${styles.radioGrid} ${columns === 2 ? styles.cols2 : ''}`}>
        {options.map((o) => (
          <label
            key={o.value}
            className={`${styles.radioCard} ${value === o.value ? styles.radioOn : ''} ${
              o.tone === 'danger' ? styles.radioDanger : ''
            }`}
          >
            <input
              type="radio"
              name={name}
              value={o.value}
              checked={value === o.value}
              onChange={() => onChange(o.value)}
              className={styles.radioInput}
            />
            <span className={styles.radioLabel}>{o.label}</span>
            {o.hint && <span className={styles.radioHint}>{o.hint}</span>}
          </label>
        ))}
      </div>
    </fieldset>
  );
}

/** Sayaç: "42 / 100"; sınıra yaklaşınca uyarı, aşınca hata rengi. */
export function CharCounter({ length, max, tone }: { length: number; max: number; tone: 'ok' | 'warn' | 'over' }) {
  return (
    <span className={`${styles.counter} ${styles[`counter-${tone}`]} ltr`} aria-live="polite">
      {length} / {max}
    </span>
  );
}
