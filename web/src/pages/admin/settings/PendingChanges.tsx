// Ayarlar: kaydedilmemiş değişikliklerin "önce → sonra" özeti. Alt çubukta açılır; satıra basınca ilgili alana gidilir.
import { Button } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { valueExcerpt } from './searchLogic';
import { useGt } from '../sys2Dict';
import styles from './nowstrip.module.css';

export interface PendingChange {
  key: string;
  label: string;
  before: string;
  after: string;
}

export function PendingChanges({ changes, onGo }: { changes: PendingChange[]; onGo: (key: string) => void }) {
  const { t } = useI18n();
  const gt = useGt();
  const human = (v: string) => {
    const s = v.trim();
    if (s === 'true') return t('admin.v2n.set.on');
    if (s === 'false') return t('admin.v2n.set.off');
    return valueExcerpt(s, 60) || t('admin.p05.settings.empty');
  };
  return (
    <details className={styles.pending} data-testid="pending-changes">
      <summary>{gt('admin.sys2.settings.pending.summary')}</summary>
      <ul className={styles.pendingList}>
        {changes.map((c) => (
          <li key={c.key} className={styles.pendingItem}>
            <span className={styles.pendingName}>{c.label}</span>
            <span className={styles.pendingDiff}>
              <span className={styles.pendingOld} dir="auto" data-testid={`pending-old-${c.key}`}>
                {human(c.before)}
              </span>
              <span aria-hidden="true"> → </span>
              <span className="sr-only">{gt('admin.sys2.settings.pending.becomes')}</span>
              <strong className={styles.pendingNew} dir="auto" data-testid={`pending-new-${c.key}`}>
                {human(c.after)}
              </strong>
            </span>
            <Button size="sm" variant="ghost" onClick={() => onGo(c.key)}>
              {gt('admin.sys2.settings.pending.go')}
            </Button>
          </li>
        ))}
      </ul>
    </details>
  );
}
