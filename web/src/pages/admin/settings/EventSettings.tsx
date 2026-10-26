// Ayarlar > Etkinlikler grubu. API: GET/PUT /api/admin/settings/{key} (SettingsPage bağlamı üzerinden).
// Anahtarlar: events_require_approval (true|false), event_max_open_per_user, event_daily_create_limit (0 = sınırsız).
import { Badge, Button, Card, Switch } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { Callout } from '../campaigns/shared';
import { isDirty, SettingRow, useSettings, valueOf } from './SettingRow';
import styles from './settings.module.css';

function ApprovalSwitch() {
  const { t } = useI18n();
  const c = useSettings();
  const k = 'events_require_approval';
  const on = valueOf(c, k) === 'true';
  const dirty = isDirty(c, k);
  return (
    <div className={`${styles.row} ${dirty ? styles.rowDirty : ''}`} data-key={k}>
      {dirty && (
        <span className={styles.unsaved}>
          <Badge tone="warning">{t('admin.settings.unsaved')}</Badge>
        </span>
      )}
      <Switch
        checked={on}
        onChange={(v) => c.setEdit(k, v ? 'true' : 'false')}
        label={t(on ? 'admin.settings.events.approvalOn' : 'admin.settings.events.approvalOff')}
      />
      <p className={styles.hintLine}>{t('admin.settings.events.approvalHint')}</p>
      {c.errors[k] && (
        <p className={styles.errText} role="alert">
          {c.errors[k]}
        </p>
      )}
      <div className={styles.rowActions}>
        <Button
          size="sm"
          disabled={!dirty}
          loading={c.savingKey === k}
          onClick={() => c.save(k)}
          data-testid={`save-${k}`}
        >
          {t('admin.settings.saveField')}
        </Button>
        {dirty && (
          <Button size="sm" variant="ghost" onClick={() => c.revert(k)}>
            {t('admin.settings.revert')}
          </Button>
        )}
      </div>
    </div>
  );
}

export function EventSettings() {
  const { t } = useI18n();
  return (
    <>
      <Callout tone="info">{t('admin.settings.events.explain')}</Callout>
      <Card title={t('admin.settings.events.approvalTitle')}>
        <ApprovalSwitch />
      </Card>
      <Card title={t('admin.settings.events.limitsTitle')}>
        <div className={styles.grid}>
          <SettingRow
            k="event_max_open_per_user"
            label={t('admin.settings.key.event_max_open_per_user')}
            hint={t('admin.settings.events.zeroUnlimited')}
            ltr
            placeholder="5"
          />
          <SettingRow
            k="event_daily_create_limit"
            label={t('admin.settings.key.event_daily_create_limit')}
            hint={t('admin.settings.events.zeroUnlimited')}
            ltr
            placeholder="5"
          />
        </div>
      </Card>
    </>
  );
}
