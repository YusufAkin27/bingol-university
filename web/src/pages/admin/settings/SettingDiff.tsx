import { useI18n } from '../../../i18n/I18nProvider';
import styles from './settings.module.css';

/** Kritik ayar onayında "ne değişecek" önizlemesi: eski değer → yeni değer (boş değer açıkça belirtilir). */
export function SettingDiff({ label, before, after }: { label: string; before: string; after: string }) {
  const { t } = useI18n();
  const isBool = (v: string) => v === 'true' || v === 'false' || v === '';
  const bool = isBool(before) && isBool(after) && (before !== '' || after !== '');
  const human = (v: string) => (v === 'true' ? t('admin.v2n.set.on') : t('admin.v2n.set.off'));
  if (bool) {
    return (
      <div className={styles.diff} role="group" aria-label={t('admin.p05.settings.diffTitle', { name: label })}>
        <p className={styles.diffLabel}>{label}</p>
        <p className={styles.diffValue} data-testid="diff-bool">
          {human(before)} → <strong>{human(after)}</strong>
        </p>
      </div>
    );
  }
  const side = (tag: string, value: string, cls: string, testId: string) => (
    <div className={`${styles.diffSide} ${cls}`} data-testid={testId}>
      <span className={styles.diffTag}>{tag}</span>
      {value.trim() ? (
        <p className={styles.diffValue} dir="auto">
          {value}
        </p>
      ) : (
        <p className={`${styles.diffValue} ${styles.diffEmpty}`}>{t('admin.p05.settings.empty')}</p>
      )}
    </div>
  );
  return (
    <div className={styles.diff} role="group" aria-label={t('admin.p05.settings.diffTitle', { name: label })}>
      <p className={styles.diffLabel}>{label}</p>
      {side(t('admin.p05.settings.old'), before, styles.diffOld, 'diff-old')}
      {side(t('admin.p05.settings.new'), after, styles.diffNew, 'diff-new')}
    </div>
  );
}
