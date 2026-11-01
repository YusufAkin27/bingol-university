import { Modal } from '../components/ui';
import { usePermissions } from '../auth/permissions';
import { useI18n } from '../i18n/I18nProvider';
import { allAdminNavItems } from './adminNav';
import { GENERAL_SHORTCUTS, GO_SHORTCUTS } from './shortcuts';
import styles from './ShellExtras.module.css';

/** "?" ile açılan yardım penceresi: klavye kısayolları (g + harf dahil) ve arama ipuçları. */
export function ShortcutsHelp({ open, onClose }: { open: boolean; onClose: () => void }) {
  const { t } = useI18n();
  const perms = usePermissions();
  const go = GO_SHORTCUTS.map((s) => ({ key: s.key, item: allAdminNavItems.find((i) => i.id === s.page) })).filter(
    (s) => s.item && perms.can(s.item.perm),
  );
  return (
    <Modal open={open} onClose={onClose} title={t('admin.kbd.title')} size="md">
      <div className={styles.help} data-testid="shortcuts-help">
        <section aria-labelledby="kbd-general">
          <h3 id="kbd-general" className={styles.helpH}>
            {t('admin.kbd.general')}
          </h3>
          <dl className={styles.kbdList}>
            {GENERAL_SHORTCUTS.map((s) => (
              <div key={s.labelKey} className={styles.kbdRow}>
                <dt>
                  {s.keys.map((k, i) => (
                    <span key={k}>
                      {i > 0 && ' + '}
                      <kbd className="ltr">{k}</kbd>
                    </span>
                  ))}
                </dt>
                <dd>{t(s.labelKey)}</dd>
              </div>
            ))}
          </dl>
        </section>

        <section aria-labelledby="kbd-go">
          <h3 id="kbd-go" className={styles.helpH}>
            {t('admin.kbd.go')}
          </h3>
          <p className={styles.helpNote}>{t('admin.kbd.goHint')}</p>
          <dl className={`${styles.kbdList} ${styles.kbdGrid}`}>
            {go.map((s) => (
              <div key={s.key} className={styles.kbdRow}>
                <dt>
                  <kbd className="ltr">g</kbd> <kbd className="ltr">{s.key}</kbd>
                </dt>
                <dd>{s.item ? t(s.item.labelKey) : ''}</dd>
              </div>
            ))}
          </dl>
        </section>

        <section aria-labelledby="kbd-tips">
          <h3 id="kbd-tips" className={styles.helpH}>
            {t('admin.kbd.tips')}
          </h3>
          <ul className={styles.tips}>
            <li>{t('admin.kbd.tip1')}</li>
            <li>{t('admin.kbd.tip2')}</li>
            <li>{t('admin.kbd.tip3')}</li>
            <li>{t('admin.kbd.tip4')}</li>
          </ul>
        </section>
      </div>
    </Modal>
  );
}

export default ShortcutsHelp;
