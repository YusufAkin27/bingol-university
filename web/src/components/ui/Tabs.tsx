import { useId, useRef, type KeyboardEvent, type ReactNode } from 'react';
import { useI18n } from '../../i18n/I18nProvider';
import styles from './Tabs.module.css';

export interface TabItem {
  id: string;
  label: ReactNode;
  disabled?: boolean;
}

interface TabsProps {
  tabs: TabItem[];
  value: string;
  onChange: (id: string) => void;
  label: string;
  /** Panel içeriği; verilmezse yalnızca sekme çubuğu çizilir (içerik dışarıda, örn. router ile). */
  children?: ReactNode;
}

/** ARIA sekmeleri: ok tuşları (RTL'e duyarlı), Home/End, odaklanınca değil Enter/Space ile değil — ok ile anında seçilir. */
export function Tabs({ tabs, value, onChange, label, children }: TabsProps) {
  const { dir } = useI18n();
  const uid = useId();
  const listRef = useRef<HTMLDivElement>(null);

  function onKeyDown(e: KeyboardEvent<HTMLDivElement>) {
    const enabled = tabs.filter((t) => !t.disabled);
    const idx = enabled.findIndex((t) => t.id === value);
    if (idx < 0) return;
    const forward = dir === 'rtl' ? 'ArrowLeft' : 'ArrowRight';
    const backward = dir === 'rtl' ? 'ArrowRight' : 'ArrowLeft';
    let next = -1;
    if (e.key === forward) next = (idx + 1) % enabled.length;
    else if (e.key === backward) next = (idx - 1 + enabled.length) % enabled.length;
    else if (e.key === 'Home') next = 0;
    else if (e.key === 'End') next = enabled.length - 1;
    if (next >= 0) {
      e.preventDefault();
      onChange(enabled[next].id);
      requestAnimationFrame(() =>
        listRef.current?.querySelector<HTMLElement>(`[data-tab="${enabled[next].id}"]`)?.focus(),
      );
    }
  }

  return (
    <div>
      <div ref={listRef} role="tablist" aria-label={label} className={styles.list} onKeyDown={onKeyDown}>
        {tabs.map((t) => {
          const selected = t.id === value;
          return (
            <button
              key={t.id}
              type="button"
              role="tab"
              id={`${uid}-tab-${t.id}`}
              data-tab={t.id}
              aria-selected={selected}
              aria-controls={`${uid}-panel`}
              tabIndex={selected ? 0 : -1}
              disabled={t.disabled}
              className={`${styles.tab} ${selected ? styles.active : ''}`}
              onClick={() => onChange(t.id)}
            >
              {t.label}
            </button>
          );
        })}
      </div>
      {children !== undefined && (
        <div
          role="tabpanel"
          id={`${uid}-panel`}
          aria-labelledby={`${uid}-tab-${value}`}
          tabIndex={0}
          className={styles.panel}
        >
          {children}
        </div>
      )}
    </div>
  );
}
