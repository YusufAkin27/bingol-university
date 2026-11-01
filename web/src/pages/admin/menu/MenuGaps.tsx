// Menü eksikleri uyarısı: gösterilen aydaki fotoğrafsız günler ve kalorisi girilmemiş yemekler.
// Kalori yemek adına, fotoğraf menü içeriğine bağlı kaydedilir; yeni bir yemek/menü gelince burada görünür.
import { useI18n } from '../../../i18n/I18nProvider';
import type { AdminMenuDay } from '../../../api/adminMenu';
import { menuGaps } from './menuLogic';
import styles from './menu.module.css';

export function MenuGaps({ days }: { days: AdminMenuDay[] }) {
  const { t, formatDate } = useI18n();
  const gaps = menuGaps(days);
  if (gaps.noImage.length === 0 && gaps.noKcal.length === 0) return null;
  return (
    <div className={styles.gaps} role="status" data-testid="menu-gaps">
      <strong>{t('admin.menu.gaps.title')}</strong>
      {gaps.noKcal.length > 0 && (
        <details>
          <summary>{t('admin.menu.gaps.kcal', { count: String(gaps.noKcal.length) })}</summary>
          <ul className={styles.items}>
            {gaps.noKcal.map((g) => (
              <li key={g.name}>{g.name}</li>
            ))}
          </ul>
        </details>
      )}
      {gaps.noImage.length > 0 && (
        <details>
          <summary>{t('admin.menu.gaps.image', { count: String(gaps.noImage.length) })}</summary>
          <ul className={styles.items}>
            {gaps.noImage.map((d) => (
              <li key={d}>{formatDate(d, { dateStyle: 'full' })}</li>
            ))}
          </ul>
        </details>
      )}
    </div>
  );
}
