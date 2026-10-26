import { Link } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import { paths } from '../paths';
import styles from './Breadcrumbs.module.css';

export interface Crumb {
  label: string;
  /** Verilmezse geçerli sayfadır (bağlantısız, aria-current). */
  to?: string;
}

/** Ekmek kırıntısı: "Ana sayfa" otomatik başa eklenir. Ayırıcı CSS ile (mantıksal, RTL'de döner). */
export function Breadcrumbs({ items }: { items: Crumb[] }) {
  const { t } = useI18n();
  const all: Crumb[] = [{ label: t('pg.crumb.home'), to: paths.site.home }, ...items];
  return (
    <nav aria-label={t('pg.crumbs')} className={styles.nav}>
      <ol className={styles.list}>
        {all.map((c, i) => (
          <li key={`${c.label}-${i}`} className={styles.item}>
            {c.to ? <Link to={c.to}>{c.label}</Link> : <span aria-current="page">{c.label}</span>}
          </li>
        ))}
      </ol>
    </nav>
  );
}
