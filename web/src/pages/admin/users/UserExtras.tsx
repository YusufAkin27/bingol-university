// Kullanıcı ayrıntısının ek bölümleri: hesap bilgisi, bildirim tercihleri, topluluk/etkinlik, destek, geri bildirim,
// raporlar ve cihaz kayıtları. API: GET /api/admin/users/{id} → extras. Mesaj İÇERİĞİ gösterilmez (yalnızca sayı).
import type { ReactNode } from 'react';
import { Link } from 'react-router-dom';
import type { AdminUserDetail } from '../../../api/types';
import { Badge, Card } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { paths } from '../../../paths';
import styles from './users.module.css';

function Row({ left, right }: { left: ReactNode; right?: ReactNode }) {
  return (
    <li>
      <span>{left}</span>
      {right !== undefined && <span className={`${styles.muted} ${styles.nowrap}`}>{right}</span>}
    </li>
  );
}

export function UserExtras({ u }: { u: AdminUserDetail }) {
  const { t, td, formatDate, formatDateTime, formatNumber } = useI18n();
  const x = u.extras;
  if (!x) return null;
  const empty = <p className={styles.hint}>{t('admin.users.x.empty')}</p>;
  const yesNo = (v: boolean) => (v ? t('admin.users.x.on') : t('admin.users.x.off'));

  const prefs: [string, boolean][] = [
    ['news', x.notificationPrefs.news],
    ['announcements', x.notificationPrefs.announcements],
    ['events', x.notificationPrefs.events],
    ['messages', x.notificationPrefs.messages],
    ['communities', x.notificationPrefs.communities],
  ];

  return (
    <>
      <Card title={t('admin.users.x.account')}>
        <dl className={styles.facts}>
          <div>
            <dt>{t('admin.users.x.userId')}</dt>
            <dd>#{u.id}</dd>
          </div>
          <div>
            <dt>{t('admin.users.x.emailVisible')}</dt>
            <dd>{x.showEmail ? t('admin.users.x.yes') : t('admin.users.x.no')}</dd>
          </div>
          <div>
            <dt>{t('admin.users.x.notifTotal')}</dt>
            <dd>{formatNumber(x.notificationsTotal)}</dd>
          </div>
          <div>
            <dt>{t('admin.users.x.notifUnread')}</dt>
            <dd>{formatNumber(x.notificationsUnread)}</dd>
          </div>
          <div>
            <dt>{t('admin.users.x.messagesSent')}</dt>
            <dd>{formatNumber(x.messagesSent)}</dd>
          </div>
          <div>
            <dt>{t('admin.users.x.blocking')}</dt>
            <dd>{formatNumber(x.blocking)}</dd>
          </div>
          <div>
            <dt>{t('admin.users.x.blockedBy')}</dt>
            <dd>{formatNumber(x.blockedBy)}</dd>
          </div>
        </dl>
        <p className={styles.hint}>{t('admin.users.x.privacyNote')}</p>
        <p className={styles.hint}>
          <Link to={paths.admin.crypto}>{t('admin.users.x.decryptLink')}</Link>
        </p>
      </Card>

      <Card title={t('admin.users.x.prefs')}>
        <div className={styles.badges}>
          {prefs.map(([k, on]) => (
            <Badge key={k} tone={on ? 'success' : 'neutral'}>
              {td(`admin.users.x.pref.${k}`)}: {yesNo(on)}
            </Badge>
          ))}
        </div>
      </Card>

      <Card title={t('admin.users.x.communities')}>
        {x.communities.length === 0 ? (
          empty
        ) : (
          <ul className={styles.list}>
            {x.communities.map((c) => (
              <Row
                key={c.id}
                left={
                  <>
                    {c.name} <Badge tone="info">{c.role}</Badge> <Badge tone="neutral">{c.status}</Badge>
                  </>
                }
                right={c.joinedAt ? formatDate(c.joinedAt) : undefined}
              />
            ))}
          </ul>
        )}
      </Card>

      <Card title={t('admin.users.x.eventsCreated')}>
        {x.eventsCreated.length === 0 ? (
          empty
        ) : (
          <ul className={styles.list}>
            {x.eventsCreated.map((e) => (
              <Row
                key={e.id}
                left={
                  <>
                    {e.title} <Badge tone="neutral">{e.status}</Badge>
                  </>
                }
                right={formatDateTime(e.startsAt)}
              />
            ))}
          </ul>
        )}
      </Card>

      <Card title={t('admin.users.x.eventsAttending')}>
        {x.eventsAttending.length === 0 ? (
          empty
        ) : (
          <ul className={styles.list}>
            {x.eventsAttending.map((e) => (
              <Row
                key={e.id}
                left={
                  <>
                    {e.title} {e.rsvp && <Badge tone="info">{e.rsvp}</Badge>}
                  </>
                }
                right={formatDateTime(e.startsAt)}
              />
            ))}
          </ul>
        )}
      </Card>

      <Card title={t('admin.users.x.feedback')}>
        {x.feedback.length === 0 ? (
          empty
        ) : (
          <ul className={styles.list}>
            {x.feedback.map((f) => (
              <Row
                key={f.id}
                left={
                  <>
                    {f.subject} <Badge tone="info">{f.category}</Badge> <Badge tone="neutral">{f.status}</Badge>
                  </>
                }
                right={formatDate(f.createdAt)}
              />
            ))}
          </ul>
        )}
      </Card>

      <Card title={t('admin.users.x.tickets')}>
        {x.tickets.length === 0 ? (
          empty
        ) : (
          <ul className={styles.list}>
            {x.tickets.map((tk) => (
              <Row
                key={tk.id}
                left={
                  <>
                    {tk.subject} <Badge tone="info">{tk.category}</Badge> <Badge tone="neutral">{tk.status}</Badge>
                  </>
                }
                right={formatDate(tk.createdAt)}
              />
            ))}
          </ul>
        )}
      </Card>

      <Card title={t('admin.users.x.reportsAgainst')}>
        {x.reportsAgainst.length === 0 ? (
          empty
        ) : (
          <ul className={styles.list}>
            {x.reportsAgainst.map((r) => (
              <Row
                key={r.id}
                left={
                  <>
                    #{r.id} <Badge tone="warning">{r.reason}</Badge> <Badge tone="neutral">{r.status}</Badge>
                  </>
                }
                right={formatDate(r.createdAt)}
              />
            ))}
          </ul>
        )}
      </Card>

      <Card title={t('admin.users.x.reportsFiled')}>
        {x.reportsFiled.length === 0 ? (
          empty
        ) : (
          <ul className={styles.list}>
            {x.reportsFiled.map((r) => (
              <Row
                key={r.id}
                left={
                  <>
                    #{r.id} {r.targetType} #{r.targetId} <Badge tone="warning">{r.reason}</Badge>{' '}
                    <Badge tone="neutral">{r.status}</Badge>
                  </>
                }
                right={formatDate(r.createdAt)}
              />
            ))}
          </ul>
        )}
      </Card>

      <Card title={t('admin.users.x.deviceLog')}>
        {x.devices.length === 0 ? (
          empty
        ) : (
          <ul className={styles.list}>
            {x.devices.map((d, i) => (
              <Row key={i} left={<Badge tone="info">{d.platform}</Badge>} right={formatDateTime(d.registeredAt)} />
            ))}
          </ul>
        )}
      </Card>
    </>
  );
}
