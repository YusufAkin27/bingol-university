// Kullanıcı ayrıntısının ek bölümleri: hesap bilgisi, bildirim tercihleri, topluluk/etkinlik, destek, geri bildirim,
// raporlar ve cihaz kayıtları. API: GET /api/admin/users/{id} → extras. Mesaj İÇERİĞİ gösterilmez (yalnızca sayı).
// PEOPLE: sayfa sekmelere bölündüğü için `sections` ile yalnız istenen bölümler çizilir; ham enum değerleri
// (ADMIN, GOING, BUG, android...) Türkçe karşılıklarıyla yazılır, sözlükte yoksa ham değer görünür.
import type { ReactNode } from 'react';
import { Link } from 'react-router-dom';
import type { AdminUserDetail } from '../../../api/types';
import { Badge, Card } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { paths } from '../../../paths';
import styles from './users.module.css';

export type ExtrasSection = 'account' | 'prefs' | 'community' | 'support' | 'devicelog';
const ALL: ExtrasSection[] = ['account', 'prefs', 'community', 'support', 'devicelog'];

function Row({ left, right }: { left: ReactNode; right?: ReactNode }) {
  return (
    <li>
      <span>{left}</span>
      {right !== undefined && <span className={`${styles.muted} ${styles.nowrap}`}>{right}</span>}
    </li>
  );
}

export function UserExtras({ u, sections = ALL }: { u: AdminUserDetail; sections?: ExtrasSection[] }) {
  const { t, td, formatDate, formatDateTime, formatNumber } = useI18n();
  const x = u.extras;
  if (!x) return null;
  const show = (s: ExtrasSection) => sections.includes(s);
  const empty = <p className={styles.hint}>{t('admin.users.x.empty')}</p>;
  const yesNo = (v: boolean) => (v ? t('admin.users.x.on') : t('admin.users.x.off'));
  const en = (group: string, value: string | null | undefined) =>
    value ? td(`admin.v2p.enum.${group}.${value}`, value) : '';

  const prefs: [string, boolean][] = [
    ['news', x.notificationPrefs.news],
    ['announcements', x.notificationPrefs.announcements],
    ['events', x.notificationPrefs.events],
    ['messages', x.notificationPrefs.messages],
    ['communities', x.notificationPrefs.communities],
  ];

  return (
    <>
      {show('account') && (
        <Card title={t('admin.users.x.account')} data-search-anchor="ud-account">
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
          <p className={styles.hint}>
            <Link to={paths.admin.userMessages(u.id)} data-search-anchor="ud-messages-link">
              {t('admin.users.x.decryptLink')}
            </Link>
          </p>
        </Card>
      )}

      {show('prefs') && (
        <Card title={t('admin.users.x.prefs')} data-search-anchor="ud-prefs">
          <div className={styles.badges}>
            {prefs.map(([k, on]) => (
              <Badge key={k} tone={on ? 'success' : 'neutral'}>
                {td(`admin.users.x.pref.${k}`)}: {yesNo(on)}
              </Badge>
            ))}
          </div>
        </Card>
      )}

      {show('community') && (
        <>
          <Card title={t('admin.users.x.communities')} data-search-anchor="ud-communities">
            {x.communities.length === 0 ? (
              empty
            ) : (
              <ul className={styles.list}>
                {x.communities.map((c) => (
                  <Row
                    key={c.id}
                    left={
                      <>
                        {c.name} <Badge tone="info">{en('communityRole', c.role)}</Badge>{' '}
                        <Badge tone="neutral">{en('memberStatus', c.status)}</Badge>
                      </>
                    }
                    right={c.joinedAt ? formatDate(c.joinedAt) : undefined}
                  />
                ))}
              </ul>
            )}
          </Card>

          <Card title={t('admin.users.x.eventsCreated')} data-search-anchor="ud-events-created">
            {x.eventsCreated.length === 0 ? (
              empty
            ) : (
              <ul className={styles.list}>
                {x.eventsCreated.map((e) => (
                  <Row
                    key={e.id}
                    left={
                      <>
                        {e.title} <Badge tone="neutral">{en('eventStatus', e.status)}</Badge>
                      </>
                    }
                    right={formatDateTime(e.startsAt)}
                  />
                ))}
              </ul>
            )}
          </Card>

          <Card title={t('admin.users.x.eventsAttending')} data-search-anchor="ud-events-attending">
            {x.eventsAttending.length === 0 ? (
              empty
            ) : (
              <ul className={styles.list}>
                {x.eventsAttending.map((e) => (
                  <Row
                    key={e.id}
                    left={
                      <>
                        {e.title} {e.rsvp && <Badge tone="info">{en('rsvp', e.rsvp)}</Badge>}
                      </>
                    }
                    right={formatDateTime(e.startsAt)}
                  />
                ))}
              </ul>
            )}
          </Card>
        </>
      )}

      {show('support') && (
        <>
          <Card title={t('admin.users.x.reportsAgainst')} data-search-anchor="ud-reports-against">
            {x.reportsAgainst.length === 0 ? (
              empty
            ) : (
              <ul className={styles.list}>
                {x.reportsAgainst.map((r) => (
                  <Row
                    key={r.id}
                    left={
                      <>
                        #{r.id} <Badge tone="warning">{td(`admin.reports.reason.${r.reason}`, r.reason)}</Badge>{' '}
                        <Badge tone="neutral">{en('reportStatus', r.status)}</Badge>
                      </>
                    }
                    right={formatDate(r.createdAt)}
                  />
                ))}
              </ul>
            )}
          </Card>

          <Card title={t('admin.users.x.reportsFiled')} data-search-anchor="ud-reports-filed">
            {x.reportsFiled.length === 0 ? (
              empty
            ) : (
              <ul className={styles.list}>
                {x.reportsFiled.map((r) => (
                  <Row
                    key={r.id}
                    left={
                      <>
                        #{r.id} {en('targetType', r.targetType)} #{r.targetId}{' '}
                        <Badge tone="warning">{td(`admin.reports.reason.${r.reason}`, r.reason)}</Badge>{' '}
                        <Badge tone="neutral">{en('reportStatus', r.status)}</Badge>
                      </>
                    }
                    right={formatDate(r.createdAt)}
                  />
                ))}
              </ul>
            )}
          </Card>

          <Card title={t('admin.users.x.tickets')} data-search-anchor="ud-tickets">
            {x.tickets.length === 0 ? (
              empty
            ) : (
              <ul className={styles.list}>
                {x.tickets.map((tk) => (
                  <Row
                    key={tk.id}
                    left={
                      <>
                        {tk.subject}{' '}
                        <Badge tone="info">{td(`admin.tickets.category.${tk.category}`, tk.category)}</Badge>{' '}
                        <Badge tone="neutral">{td(`admin.tickets.status.${tk.status}`, tk.status)}</Badge>
                      </>
                    }
                    right={formatDate(tk.createdAt)}
                  />
                ))}
              </ul>
            )}
          </Card>

          <Card title={t('admin.users.x.feedback')} data-search-anchor="ud-feedback">
            {x.feedback.length === 0 ? (
              empty
            ) : (
              <ul className={styles.list}>
                {x.feedback.map((f) => (
                  <Row
                    key={f.id}
                    left={
                      <>
                        {f.subject}{' '}
                        <Badge tone="info">{td(`admin.feedback.category.${f.category}`, f.category)}</Badge>{' '}
                        <Badge tone="neutral">{td(`admin.feedback.status.${f.status}`, f.status)}</Badge>
                      </>
                    }
                    right={formatDate(f.createdAt)}
                  />
                ))}
              </ul>
            )}
          </Card>
        </>
      )}

      {show('devicelog') && (
        <Card title={t('admin.users.x.deviceLog')} data-search-anchor="ud-device-log">
          {x.devices.length === 0 ? (
            empty
          ) : (
            <ul className={styles.list}>
              {x.devices.map((d, i) => (
                <Row
                  key={i}
                  left={<Badge tone="info">{td(`admin.v2p.enum.platform.${d.platform.toLowerCase()}`, d.platform)}</Badge>}
                  right={formatDateTime(d.registeredAt)}
                />
              ))}
            </ul>
          )}
        </Card>
      )}
    </>
  );
}
