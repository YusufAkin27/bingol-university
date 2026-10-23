import type { ReactNode } from 'react';
import type { AppInfo } from '../../../api/types';
import { Icon, type IconName } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import type { TranslationKey } from '../../../i18n';
import styles from './ContactList.module.css';

interface Item {
  id: string;
  icon: IconName;
  label: TranslationKey;
  value: ReactNode;
}

/** `GET /api/app/info` alanlarından yalnızca dolu olanları listeler; hiçbiri yoksa boş döner. */
export function contactItems(info: AppInfo | undefined): Item[] {
  if (!info) return [];
  const items: Item[] = [];
  const mail = (a: string) => (
    <a href={`mailto:${a}`} className="ltr">
      {a}
    </a>
  );
  if (info.contactEmail)
    items.push({ id: 'contact', icon: 'mail', label: 'site.contact.general', value: mail(info.contactEmail) });
  if (info.supportEmail && info.supportEmail !== info.contactEmail)
    items.push({ id: 'support', icon: 'lifebuoy', label: 'site.contact.support', value: mail(info.supportEmail) });
  if (info.phone)
    items.push({
      id: 'phone',
      icon: 'phone',
      label: 'site.contact.phone',
      value: (
        <a href={`tel:${info.phone.replace(/\s+/g, '')}`} className="ltr">
          {info.phone}
        </a>
      ),
    });
  if (info.address) items.push({ id: 'address', icon: 'pin', label: 'site.contact.address', value: info.address });
  if (info.website)
    items.push({
      id: 'website',
      icon: 'globe',
      label: 'site.contact.website',
      value: (
        <a href={info.website} target="_blank" rel="noopener noreferrer" className="ltr">
          {info.website.replace(/^https?:\/\//, '')}
        </a>
      ),
    });
  const social = [
    ['Instagram', info.social.instagram],
    ['X / Twitter', info.social.twitter],
    ['YouTube', info.social.youtube],
  ].filter((s): s is [string, string] => !!s[1]);
  if (social.length)
    items.push({
      id: 'social',
      icon: 'external',
      label: 'site.contact.social',
      value: (
        <span className={styles.social}>
          {social.map(([name, url]) => (
            <a key={name} href={url} target="_blank" rel="noopener noreferrer">
              {name}
            </a>
          ))}
        </span>
      ),
    });
  return items;
}

export function ContactList({ info }: { info: AppInfo | undefined }) {
  const { t } = useI18n();
  const items = contactItems(info);
  if (!items.length) return null;
  return (
    <dl className={styles.list}>
      {items.map((it) => (
        <div key={it.id} className={styles.item}>
          <span className={styles.ico}>
            <Icon name={it.icon} size={20} />
          </span>
          <dt>{t(it.label)}</dt>
          <dd>{it.value}</dd>
        </div>
      ))}
    </dl>
  );
}
