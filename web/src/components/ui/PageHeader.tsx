import type { ReactNode } from 'react';
import { Link } from '../LocalizedLink';
import styles from './PageHeader.module.css';

export interface Crumb {
  label: string;
  to?: string;
}

interface Props {
  title: ReactNode;
  description?: ReactNode;
  actions?: ReactNode;
  breadcrumbs?: Crumb[];
}

export function PageHeader({ title, description, actions, breadcrumbs }: Props) {
  return (
    <header className={styles.header}>
      <div className={styles.text}>
        {breadcrumbs && breadcrumbs.length > 0 && (
          <nav aria-label="breadcrumb" className={styles.crumbs}>
            <ol>
              {breadcrumbs.map((c, i) => (
                <li key={i} aria-current={i === breadcrumbs.length - 1 ? 'page' : undefined}>
                  {c.to ? <Link to={c.to}>{c.label}</Link> : c.label}
                </li>
              ))}
            </ol>
          </nav>
        )}
        <h1 className={styles.title}>{title}</h1>
        {description && <p className={styles.desc}>{description}</p>}
      </div>
      {actions && <div className={styles.actions}>{actions}</div>}
    </header>
  );
}
