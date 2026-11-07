import { useGt } from './dict';
import styles from './yaptirim.module.css';

export interface ShortcutItem {
  keys: string;
  label: string;
}

/** Klavye kısayolu ipucu çubuğu (dokunmatik cihazda gizlenir). Tuşlar <kbd> ile yazılır. */
export function ShortcutBar({ items, anchor }: { items: ShortcutItem[]; anchor?: string }) {
  const gt = useGt();
  return (
    <p className={styles.keys} aria-label={gt('admin.mod1.keys.title')} data-search-anchor={anchor}>
      <span className={styles.keysTitle}>{gt('admin.mod1.keys.title')}</span>
      {items.map((it) => (
        <span key={it.keys} className={styles.keyItem}>
          <kbd className={styles.kbd}>{it.keys}</kbd>
          <span>{it.label}</span>
        </span>
      ))}
    </p>
  );
}
