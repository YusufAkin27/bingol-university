import {
  cloneElement,
  forwardRef,
  isValidElement,
  useId,
  useState,
  type InputHTMLAttributes,
  type ReactElement,
  type ReactNode,
  type SelectHTMLAttributes,
  type TextareaHTMLAttributes,
} from 'react';
import { Icon } from './Icon';
import styles from './Fields.module.css';

interface FormFieldProps {
  label: ReactNode;
  /** Tek bir form denetimi (Input, Select, Textarea...). id ve aria özellikleri otomatik enjekte edilir. */
  children: ReactElement;
  error?: string | null;
  hint?: ReactNode;
  required?: boolean;
  className?: string;
}

export function FormField({ label, children, error, hint, required, className }: FormFieldProps) {
  const uid = useId();
  const id = (isValidElement(children) && (children.props as { id?: string }).id) || `f-${uid}`;
  const hintId = `${id}-hint`;
  const errId = `${id}-err`;
  const describedBy = [hint ? hintId : null, error ? errId : null].filter(Boolean).join(' ') || undefined;
  return (
    <div className={`${styles.field} ${className ?? ''}`}>
      <label htmlFor={id} className={styles.label}>
        {label}
        {required && (
          <span className={styles.req} aria-hidden="true">
            {' '}
            *
          </span>
        )}
      </label>
      {cloneElement(children as ReactElement<Record<string, unknown>>, {
        id,
        'aria-invalid': error ? true : undefined,
        'aria-describedby': describedBy,
        required: required || undefined,
      })}
      {hint && (
        <p id={hintId} className={styles.hint}>
          {hint}
        </p>
      )}
      {error && (
        <p id={errId} className={styles.error} role="alert">
          {error}
        </p>
      )}
    </div>
  );
}

export const Input = forwardRef<HTMLInputElement, InputHTMLAttributes<HTMLInputElement>>(function Input(
  { className, ...rest },
  ref,
) {
  return <input ref={ref} className={`${styles.control} ${className ?? ''}`} {...rest} />;
});

interface PasswordInputProps extends Omit<InputHTMLAttributes<HTMLInputElement>, 'type'> {
  showLabel: string;
  hideLabel: string;
}

/** Göster/gizle düğmeli şifre alanı; FormField içinde doğrudan kullanılabilir (id/aria iç alana iletilir). */
export const PasswordInput = forwardRef<HTMLInputElement, PasswordInputProps>(function PasswordInput(
  { showLabel, hideLabel, className, ...rest },
  ref,
) {
  const [show, setShow] = useState(false);
  return (
    <div className={styles.pw}>
      <input
        ref={ref}
        type={show ? 'text' : 'password'}
        className={`${styles.control} ${className ?? ''}`}
        {...rest}
      />
      <button
        type="button"
        className={styles.pwBtn}
        aria-label={show ? hideLabel : showLabel}
        aria-pressed={show}
        onClick={() => setShow((v) => !v)}
      >
        <Icon name={show ? 'eyeOff' : 'eye'} size={18} />
      </button>
    </div>
  );
});

export const Textarea = forwardRef<HTMLTextAreaElement, TextareaHTMLAttributes<HTMLTextAreaElement>>(
  function Textarea({ className, rows = 4, ...rest }, ref) {
    return (
      <textarea
        ref={ref}
        rows={rows}
        className={`${styles.control} ${styles.textarea} ${className ?? ''}`}
        {...rest}
      />
    );
  },
);

export const Select = forwardRef<HTMLSelectElement, SelectHTMLAttributes<HTMLSelectElement>>(function Select(
  { className, children, ...rest },
  ref,
) {
  return (
    <select ref={ref} className={`${styles.control} ${styles.select} ${className ?? ''}`} {...rest}>
      {children}
    </select>
  );
});

interface CheckboxProps extends Omit<InputHTMLAttributes<HTMLInputElement>, 'type'> {
  label: ReactNode;
}

export const Checkbox = forwardRef<HTMLInputElement, CheckboxProps>(function Checkbox(
  { label, className, ...rest },
  ref,
) {
  return (
    <label className={`${styles.check} ${className ?? ''}`}>
      <input ref={ref} type="checkbox" className={styles.checkInput} {...rest} />
      <span>{label}</span>
    </label>
  );
});

interface SwitchProps {
  checked: boolean;
  onChange: (checked: boolean) => void;
  label: ReactNode;
  disabled?: boolean;
  id?: string;
}

/** Açık/kapalı anahtarı (role="switch"). Boşluk ve Enter ile çalışır. */
export function Switch({ checked, onChange, label, disabled, id }: SwitchProps) {
  const uid = useId();
  const labelId = `sw-${uid}`;
  return (
    <div className={styles.switchRow}>
      <button
        type="button"
        id={id}
        role="switch"
        aria-checked={checked}
        aria-labelledby={labelId}
        disabled={disabled}
        className={`${styles.switch} ${checked ? styles.on : ''}`}
        onClick={() => onChange(!checked)}
      >
        <span className={styles.thumb} />
      </button>
      <span id={labelId} className={styles.switchLabel}>
        {label}
      </span>
    </div>
  );
}
