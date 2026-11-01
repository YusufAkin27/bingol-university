// Ayarlar: "Şu an" şeridi (bakım, duyuru bandı, zorunlu güncelleme, etkinlik onayı) ve kaydedilmemiş değişiklik çubuğu.
import { Button, StatusDot, type StatusTone } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import type { SettingGroup } from './lib';
import styles from './nowstrip.module.css';

interface Chip {
  id: string;
  label: string;
  value: string;
  tone: StatusTone;
  group: SettingGroup;
  anchor: string;
}

/** Sunucudaki (kaydedilmiş) değerlerden tek bakışta durum: ne açık, ne kapalı. */
export function NowStrip({
  server,
  onGo,
}: {
  server: Record<string, string>;
  onGo: (group: SettingGroup) => void;
}) {
  const { t } = useI18n();
  const on = (k: string) => (server[k] ?? '').toLowerCase() === 'true';
  const maint = on('maintenance_mode');
  const banner = (server.banner_text_tr ?? '').trim();
  const minOf = (p: 'android' | 'ios') => (server[`min_version_${p}`] ?? '').trim();
  const latestOf = (p: 'android' | 'ios') => (server[`latest_version_${p}`] ?? '').trim();
  const updateText = (p: 'android' | 'ios') => {
    const min = minOf(p);
    if (min) return t('admin.v2n.set.now.updForce', { v: min });
    return latestOf(p) ? t('admin.v2n.set.now.updSuggest') : t('admin.v2n.set.now.updOff');
  };
  const forced = minOf('android') !== '' || minOf('ios') !== '';
  const chips: Chip[] = [
    {
      id: 'maintenance',
      label: t('admin.v2n.set.now.maintenance'),
      value: maint ? t('admin.v2n.set.on') : t('admin.v2n.set.off'),
      tone: maint ? 'danger' : 'success',
      group: 'maintenance',
      anchor: 'maintenance_mode',
    },
    {
      id: 'banner',
      label: t('admin.v2n.set.now.banner'),
      value: banner ? t('admin.v2n.set.now.bannerOn', { text: banner.length > 40 ? `${banner.slice(0, 40)}…` : banner }) : t('admin.v2n.set.off'),
      tone: banner ? 'info' : 'neutral',
      group: 'banner',
      anchor: 'card-banner-texts',
    },
    {
      id: 'update',
      label: t('admin.v2n.set.now.update'),
      value: `Android: ${updateText('android')} · iOS: ${updateText('ios')}`,
      tone: forced ? 'warning' : 'neutral',
      group: 'stores',
      anchor: 'card-android',
    },
    {
      id: 'events',
      label: t('admin.v2n.set.now.events'),
      value: on('events_require_approval') ? t('admin.v2n.set.on') : t('admin.v2n.set.off'),
      tone: 'neutral',
      group: 'events',
      anchor: 'card-event-approval',
    },
  ];
  return (
    <section className={styles.strip} aria-label={t('admin.v2n.set.now.title')} data-search-anchor="now-strip" data-testid="now-strip">
      <h2 className={styles.title}>{t('admin.v2n.set.now.title')}</h2>
      <ul className={styles.chips}>
        {chips.map((c) => (
          <li key={c.id}>
            <button type="button" className={styles.chip} onClick={() => onGo(c.group)} data-testid={`now-${c.id}`}>
              <span className={styles.chipLabel}>{c.label}</span>
              <StatusDot tone={c.tone} announceTone={false}>
                {c.value}
              </StatusDot>
            </button>
          </li>
        ))}
      </ul>
    </section>
  );
}

/** Kaydedilmemiş değişiklik varken altta yapışan çubuk: sayı + hepsini geri al. */
export function DirtyBar({ count, onRevertAll }: { count: number; onRevertAll: () => void }) {
  const { t } = useI18n();
  if (count === 0) return null;
  return (
    <div className={styles.dirty} role="status" data-testid="dirty-bar">
      <span>{t('admin.v2n.set.dirty', { n: count })}</span>
      <Button size="sm" variant="secondary" onClick={onRevertAll}>
        {t('admin.v2n.set.revertAll')}
      </Button>
    </div>
  );
}
