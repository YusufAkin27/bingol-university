import type { HTMLAttributes, ReactNode } from 'react';
import styles from './Mobile.module.css';

export interface ActionBarProps extends HTMLAttributes<HTMLDivElement> {
  children: ReactNode;
  /** Hizalama: start (varsayılan), end, between. */
  align?: 'start' | 'end' | 'between';
  /** Dar ekranda (<640 px) her düğme satır genişliğini paylaşır ve alt alta/yan yana sarar. */
  stretchOnNarrow?: boolean;
}

/**
 * Eylem çubuğu: düğmeler sığmayınca alt satıra SARAR (taşmaz), dar ekranda dokunma hedefleri en az 44 px olur.
 * Filtre/araç çubuklarında ve sayfa başlığı eylemlerinde kullanın.
 */
export function ActionBar({ children, align = 'start', stretchOnNarrow = true, className, ...rest }: ActionBarProps) {
  return (
    <div
      className={`${styles.actionBar} ${styles[`align${align}`]} ${stretchOnNarrow ? styles.stretch : ''} ${className ?? ''}`}
      {...rest}
    >
      {children}
    </div>
  );
}
