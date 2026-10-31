import { useId, useState } from 'react';
import type { ReasonTemplate } from '../../../api/types';
import type { I18n } from '../../../i18n/I18nProvider';
import { useI18n } from '../../../i18n/I18nProvider';
import { Textarea } from '../../ui/Fields';
import { DEFAULT_REASON_MIN, REASON_MAX, isReasonValid } from './match';
import styles from './guard.module.css';

/** Hazır sebep seçeneği: tıklanınca `text` alana yazılır. */
export interface ReasonTemplateOption {
  id: string;
  label: string;
  text: string;
}

/**
 * Raporlama modülünün `GET /admin/reports/reason-templates` yanıtını (ReasonTemplate[]) şablon seçeneklerine
 * çevirir; etiket `admin.reports.reasonCode.<KOD>` çevirisinden, metin etkin dilden gelir.
 */
export function reportTemplatesToOptions(
  templates: ReasonTemplate[],
  i18n: Pick<I18n, 'td' | 'lang'>,
): ReasonTemplateOption[] {
  return templates.map((tpl) => ({
    id: tpl.code,
    label: i18n.td(`admin.reports.reasonCode.${tpl.code}`, tpl.code),
    text: tpl.texts?.[i18n.lang] ?? tpl.text,
  }));
}

export interface ReasonFieldProps {
  value: string;
  onChange: (value: string) => void;
  /** En az karakter (boşluk kırpılarak sayılır). Varsayılan 10. */
  minLength?: number;
  /** En çok karakter; 300'den büyük verilse de 300'e kısılır. */
  maxLength?: number;
  label?: string;
  templates?: ReasonTemplateOption[];
  /** Diyalog açılınca odak bu alana gelsin (`data-autofocus`). */
  focusOnMount?: boolean;
  disabled?: boolean;
  required?: boolean;
}

/** Çok satırlı sebep alanı: karakter sayacı, en az uzunluk uyarısı, isteğe bağlı hazır sebep düğmeleri. */
export function ReasonField({
  value,
  onChange,
  minLength = DEFAULT_REASON_MIN,
  maxLength = REASON_MAX,
  label,
  templates,
  focusOnMount,
  disabled,
  required = true,
}: ReasonFieldProps) {
  const { t } = useI18n();
  const uid = useId();
  const [touched, setTouched] = useState(false);
  const max = Math.min(maxLength, REASON_MAX);
  const valid = isReasonValid(value, minLength);
  const showError = touched && !valid;
  const inputId = `${uid}-input`;
  const hintId = `${uid}-hint`;
  const counterId = `${uid}-count`;
  const errId = `${uid}-err`;
  return (
    <div className={styles.field}>
      <label htmlFor={inputId} className={styles.label}>
        {label ?? t('admin.guard.reason.label')}
        {required && (
          <span className={styles.req} aria-hidden="true">
            {' '}
            *
          </span>
        )}
      </label>
      {templates && templates.length > 0 && (
        <div role="group" aria-label={t('admin.guard.reason.templates')} className={styles.chips}>
          {templates.map((tpl) => (
            <button
              key={tpl.id}
              type="button"
              className={styles.chip}
              disabled={disabled}
              title={tpl.text}
              onClick={() => {
                onChange(tpl.text.slice(0, max));
                setTouched(true);
              }}
            >
              {tpl.label}
            </button>
          ))}
        </div>
      )}
      <Textarea
        id={inputId}
        rows={3}
        value={value}
        maxLength={max}
        disabled={disabled}
        required={required}
        data-autofocus={focusOnMount ? true : undefined}
        aria-invalid={showError ? true : undefined}
        aria-describedby={[hintId, counterId, showError ? errId : null].filter(Boolean).join(' ')}
        // Sunucu, sebep başlığında satır sonu/sekme gibi kontrol karakterini 400 REASON_INVALID sayar: yazarken boşluğa çevrilir.
        onChange={(e) => onChange(e.target.value.replace(/[\r\n\t]+/g, ' '))}
        onBlur={() => setTouched(true)}
      />
      <div className={styles.reasonMeta}>
        <p id={hintId} className={styles.hint}>
          {t('admin.guard.reason.hint', { min: minLength })}
        </p>
        <p id={counterId} className={styles.counter}>
          {t('admin.guard.reason.counter', { count: value.length, max })}
        </p>
      </div>
      {showError && (
        <p id={errId} className={styles.mismatch} role="alert">
          {t('admin.guard.reason.tooShort', { min: minLength })}
        </p>
      )}
    </div>
  );
}
