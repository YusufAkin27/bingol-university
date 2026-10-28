import { useId } from 'react';
import { useI18n } from '../../../i18n/I18nProvider';
import { Input } from '../../ui/Fields';
import { matchesTarget } from './match';
import styles from './guard.module.css';

const PLACEHOLDER = '\u0001'; // hedef metnin yerini tutar; cümleyi <code> etrafında bölmek için

export interface TypeToConfirmProps {
  /** Yazılması istenen metin: hedefin adı/e-postası ya da "SİL" gibi bir sözcük. */
  target: string;
  value: string;
  /** Her tuşta çağrılır; ikinci bağımsız değişken eşleşme durumudur. */
  onChange: (value: string, matches: boolean) => void;
  label?: string;
  /** Diyalog açılınca odak bu alana gelsin (`data-autofocus`). */
  focusOnMount?: boolean;
  disabled?: boolean;
  /** Eşleşme dışında Enter ile onay istenirse (alan geçerliyken). */
  onEnter?: () => void;
}

/**
 * Hedef metni yazdıran onay alanı. Yapıştırma serbesttir; karşılaştırma Türkçe İ/ı duyarlı, büyük/küçük
 * harf ve baş/son boşluktan bağımsızdır (bkz. match.ts).
 */
export function TypeToConfirm({ target, value, onChange, label, focusOnMount, disabled, onEnter }: TypeToConfirmProps) {
  const { t } = useI18n();
  const uid = useId();
  const inputId = `${uid}-input`;
  const promptId = `${uid}-prompt`;
  const statusId = `${uid}-status`;
  const ok = matchesTarget(value, target);
  const [before = '', after = ''] = t('admin.guard.typeToConfirm.prompt', { target: PLACEHOLDER }).split(PLACEHOLDER);
  const touched = value.trim().length > 0;
  return (
    <div className={styles.field}>
      <label htmlFor={inputId} className={styles.label}>
        {label ?? t('admin.guard.typeToConfirm.label')}
      </label>
      <p id={promptId} className={styles.prompt}>
        {before}
        <code className={styles.target}>{target}</code>
        {after}
      </p>
      <Input
        id={inputId}
        value={value}
        autoComplete="off"
        autoCapitalize="off"
        spellCheck={false}
        disabled={disabled}
        data-autofocus={focusOnMount ? true : undefined}
        aria-describedby={`${promptId} ${statusId}`}
        aria-invalid={touched && !ok ? true : undefined}
        onChange={(e) => onChange(e.target.value, matchesTarget(e.target.value, target))}
        onKeyDown={(e) => {
          if (e.key === 'Enter' && ok && onEnter) {
            e.preventDefault();
            onEnter();
          }
        }}
      />
      <p id={statusId} className={ok ? styles.ok : styles.mismatch} aria-live="polite">
        {touched ? (ok ? t('admin.guard.typeToConfirm.match') : t('admin.guard.typeToConfirm.mismatch')) : ''}
      </p>
    </div>
  );
}
