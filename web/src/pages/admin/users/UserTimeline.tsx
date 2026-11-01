// Kullanıcı ayrıntısı: zaman çizelgesi. Ayrıntı yanıtındaki tarihli kayıtlardan derlenir (ek istek yok); en yeni üstte, ilk 8 olay görünür.
import { useMemo, useState } from 'react';
import type { AdminUserDetail } from '../../../api/types';
import { Button, Card, Icon, type IconName } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { buildTimeline, type TimelineKind } from './insanData';
import { it } from './insan';
import styles from './insan.module.css';

const ICON: Record<TimelineKind, IconName> = {
  joined: 'plus',
  consent: 'check',
  twoFactor: 'shield',
  device: 'smartphone',
  community: 'community',
  ticket: 'lifebuoy',
  feedback: 'message',
  reportAgainst: 'flag',
  reportFiled: 'flag',
  lastSeen: 'clock',
  deleted: 'x',
};
const VISIBLE = 8;

export function UserTimeline({ user }: { user: AdminUserDetail }) {
  const i18n = useI18n();
  const t = it(i18n);
  const { td, formatDateTime, formatNumber } = i18n;
  const [all, setAll] = useState(false);
  const events = useMemo(
    () => buildTimeline(user, (type) => td(`admin.users.consentType.${type}`, type)),
    [user, td],
  );
  const shown = all ? events : events.slice(0, VISIBLE);
  const label = (kind: TimelineKind, p: Record<string, string>) => {
    if (kind === 'device') return t('admin.insan.tl.device', { platform: td(`admin.users.platform.${p.platform.toUpperCase()}`, p.platform) });
    if (kind === 'reportAgainst' || kind === 'reportFiled')
      return t(`admin.insan.tl.${kind}`, { status: t(`admin.insan.tl.status.${p.status}`) });
    return t(`admin.insan.tl.${kind}`, p);
  };
  return (
    <Card title={t('admin.insan.tl.title')} data-search-anchor="ud-timeline">
      <div className={styles.cardBody}>
        <p className={styles.note}>{t('admin.insan.tl.hint')}</p>
        {events.length === 0 ? (
          <p className={styles.note}>{t('admin.insan.tl.empty')}</p>
        ) : (
          <ol className={styles.timeline} aria-label={t('admin.insan.tl.list')}>
            {shown.map((e) => (
              <li key={e.id} className={styles.tlItem}>
                <span className={styles.tlDot} data-tone={e.tone}>
                  <Icon name={ICON[e.kind]} size={16} aria-hidden="true" />
                </span>
                <span className={styles.tlBody}>
                  <span className={styles.tlTitle} dir="auto">
                    {label(e.kind, e.params)}
                  </span>
                  <time className={styles.tlWhen} dateTime={e.at}>
                    {formatDateTime(e.at)}
                  </time>
                </span>
              </li>
            ))}
          </ol>
        )}
        {events.length > VISIBLE && (
          <Button variant="ghost" size="sm" aria-expanded={all} onClick={() => setAll((v) => !v)}>
            {all ? t('admin.insan.tl.less') : t('admin.insan.tl.more', { n: formatNumber(events.length) })}
          </Button>
        )}
      </div>
    </Card>
  );
}
