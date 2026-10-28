import { createContext, useContext, type ReactNode } from 'react';
import { Badge, Button, FormField, Input, PermissionButton, Textarea } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { validateSetting } from './lib';
import styles from './settings.module.css';

/** Sayfa düzeyindeki form durumu: yerel düzenlemeler, kaydetme ve geri alma. */
export interface SettingsCtx {
  server: Record<string, string>;
  edits: Record<string, string>;
  setEdit: (key: string, value: string) => void;
  revert: (key: string) => void;
  /** Kaydet: doğrulama sayfa içinde yapılır; onay gerekiyorsa pencere açar. */
  save: (key: string) => void;
  savingKey: string | null;
  /** Son sunucu hatası (yalnızca ilgili anahtar için). */
  errors: Record<string, string>;
}

const Ctx = createContext<SettingsCtx | null>(null);
export const SettingsProvider = Ctx.Provider;
export function useSettings(): SettingsCtx {
  const v = useContext(Ctx);
  if (!v) throw new Error('SettingsProvider yok');
  return v;
}

export function valueOf(c: Pick<SettingsCtx, 'server' | 'edits'>, key: string): string {
  return c.edits[key] ?? c.server[key] ?? '';
}
export function isDirty(c: Pick<SettingsCtx, 'server' | 'edits'>, key: string): boolean {
  return key in c.edits && c.edits[key] !== (c.server[key] ?? '');
}

export type FieldKind = 'text' | 'email' | 'url' | 'tel' | 'textarea';

/** Tek ayar alanı: değişince vurgulanır, "Kaydedilmemiş" rozeti, kendi Kaydet/Geri al düğmeleri. */
export function SettingRow({
  k,
  label,
  hint,
  kind = 'text',
  ltr,
  lang,
  placeholder,
  extra,
}: {
  k: string;
  label: string;
  hint?: ReactNode;
  kind?: FieldKind;
  ltr?: boolean;
  lang?: 'tr' | 'en' | 'ar';
  placeholder?: string;
  extra?: ReactNode;
}) {
  const { t } = useI18n();
  const c = useSettings();
  const value = valueOf(c, k);
  const dirty = isDirty(c, k);
  const clientErr = dirty ? validateSetting(k, value) : null;
  const errText = clientErr ? t(`admin.settings.err.${clientErr}`) : (c.errors[k] ?? null);
  const dir = lang ? (lang === 'ar' ? 'rtl' : 'ltr') : undefined;
  const common = {
    value,
    lang,
    dir: dir as 'rtl' | 'ltr' | undefined,
    placeholder,
    onChange: (e: { target: { value: string } }) => c.setEdit(k, e.target.value),
  };
  return (
    <div className={`${styles.row} ${dirty ? styles.rowDirty : ''}`} data-dirty={dirty || undefined} data-key={k}>
      {dirty && (
        <span className={styles.unsaved}>
          <Badge tone="warning">{t('admin.settings.unsaved')}</Badge>
        </span>
      )}
      <FormField label={label} hint={hint} error={errText}>
        {kind === 'textarea' ? (
          <Textarea rows={2} {...common} />
        ) : (
          <Input
            type={kind === 'text' ? 'text' : kind}
            className={ltr || kind === 'url' || kind === 'email' || kind === 'tel' ? 'ltr' : undefined}
            autoComplete="off"
            {...common}
          />
        )}
      </FormField>
      {extra}
      <div className={styles.rowActions}>
        <PermissionButton
          permission="settings.write"
          size="sm"
          disabled={!dirty || !!clientErr}
          loading={c.savingKey === k}
          onClick={() => c.save(k)}
          data-testid={`save-${k}`}
        >
          {t('admin.settings.saveField')}
        </PermissionButton>
        {dirty && (
          <Button size="sm" variant="ghost" onClick={() => c.revert(k)}>
            {t('admin.settings.revert')}
          </Button>
        )}
      </div>
    </div>
  );
}
