// Başvuru/profil formu: unvan, ad, soyad, birim. Kayıt (3. adım), beklemede (yeniden başvuru) ve profil sayfası kullanır.
import { useState, type FormEvent } from 'react';
import type { ApplyBody } from '../../../api/academician';
import { Button, FormField, Icon, Input } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { useT } from '../dict';
import { acadError } from '../errors';
import styles from '../academician.module.css';

export const TITLE_SUGGESTIONS = ['Prof. Dr.', 'Doç. Dr.', 'Dr. Öğr. Üyesi', 'Öğr. Gör. Dr.', 'Öğr. Gör.', 'Arş. Gör. Dr.', 'Arş. Gör.', 'Okutman', 'Uzman'];

interface Props {
  initial?: Partial<ApplyBody>;
  submitLabel: string;
  busyLabel: string;
  /** Hata fırlatırsa form girdiyi KORUR ve hatayı gösterir. */
  onSubmit: (b: ApplyBody) => Promise<void>;
  /** Form üstündeki ek düğme (örn. "Vazgeç"). */
  extra?: React.ReactNode;
}

export function ApplyForm({ initial, submitLabel, busyLabel, onSubmit, extra }: Props) {
  const i18n = useI18n();
  const t = useT();
  const [title, setTitle] = useState(initial?.title ?? '');
  const [first, setFirst] = useState(initial?.firstName ?? '');
  const [last, setLast] = useState(initial?.lastName ?? '');
  const [unit, setUnit] = useState(initial?.unit ?? '');
  const [touched, setTouched] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const req = t('ac.field.required');
  const errTitle = touched && !title.trim() ? req : null;
  const errFirst = touched && !first.trim() ? req : null;
  const errLast = touched && !last.trim() ? req : null;

  async function submit(e: FormEvent) {
    e.preventDefault();
    setTouched(true);
    setError(null);
    if (!title.trim() || !first.trim() || !last.trim()) return;
    setBusy(true);
    try {
      await onSubmit({ title: title.trim(), firstName: first.trim(), lastName: last.trim(), unit: unit.trim() || undefined });
    } catch (err) {
      setError(acadError(i18n, err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <form className={styles.formStack} onSubmit={submit} noValidate aria-busy={busy || undefined}>
      {error && (
        <div className={styles.alertBox} role="alert">
          <Icon name="alert" size={18} />
          <span>{error}</span>
        </div>
      )}
      <FormField label={t('ac.apply.title')} error={errTitle} hint={t('ac.apply.titleHint')} required>
        <Input name="title" list="acad-title-list" autoComplete="honorific-prefix" maxLength={40} value={title} onChange={(e) => setTitle(e.target.value)} />
      </FormField>
      <datalist id="acad-title-list">
        {TITLE_SUGGESTIONS.map((s) => (
          <option key={s} value={s} />
        ))}
      </datalist>
      <div className={styles.twoCol}>
        <FormField label={t('ac.apply.firstName')} error={errFirst} required>
          <Input name="firstName" autoComplete="given-name" maxLength={60} value={first} onChange={(e) => setFirst(e.target.value)} />
        </FormField>
        <FormField label={t('ac.apply.lastName')} error={errLast} required>
          <Input name="lastName" autoComplete="family-name" maxLength={60} value={last} onChange={(e) => setLast(e.target.value)} />
        </FormField>
      </div>
      <FormField label={t('ac.apply.unit')} hint={t('ac.apply.unitHint')}>
        <Input name="unit" maxLength={160} value={unit} onChange={(e) => setUnit(e.target.value)} />
      </FormField>
      <div className={styles.actionsRow}>
        <Button type="submit" loading={busy}>
          {busy ? busyLabel : submitLabel}
        </Button>
        {extra}
      </div>
    </form>
  );
}
