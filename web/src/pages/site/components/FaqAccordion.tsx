import { useId, useRef, useState, type KeyboardEvent } from 'react';
import type { FaqEntry } from '../../../api/types';
import { Icon, MarkdownText } from '../../../components/ui';
import styles from './FaqAccordion.module.css';

/**
 * Erişilebilir akordeon: düğme başlıklar (aria-expanded/aria-controls), Enter/Boşluk ile aç-kapa,
 * Yukarı/Aşağı/Home/End ile başlıklar arasında gezinme.
 */
export function FaqAccordion({ items }: { items: FaqEntry[] }) {
  const base = useId();
  const [open, setOpen] = useState<Set<number>>(new Set());
  const heads = useRef<(HTMLButtonElement | null)[]>([]);

  const toggle = (id: number) =>
    setOpen((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });

  const onKey = (e: KeyboardEvent, i: number) => {
    const last = items.length - 1;
    let to = -1;
    if (e.key === 'ArrowDown') to = i === last ? 0 : i + 1;
    else if (e.key === 'ArrowUp') to = i === 0 ? last : i - 1;
    else if (e.key === 'Home') to = 0;
    else if (e.key === 'End') to = last;
    if (to >= 0) {
      e.preventDefault();
      heads.current[to]?.focus();
    }
  };

  return (
    <div className={styles.acc}>
      {items.map((it, i) => {
        const isOpen = open.has(it.id);
        const hid = `${base}-h-${it.id}`;
        const pid = `${base}-p-${it.id}`;
        return (
          <div key={it.id} className={`${styles.item} ${isOpen ? styles.open : ''}`}>
            <h3 className={styles.h}>
              <button
                ref={(el) => {
                  heads.current[i] = el;
                }}
                type="button"
                id={hid}
                className={styles.btn}
                aria-expanded={isOpen}
                aria-controls={pid}
                onClick={() => toggle(it.id)}
                onKeyDown={(e) => onKey(e, i)}
              >
                <span>{it.question}</span>
                <Icon name="chevronDown" size={20} className={styles.chev} />
              </button>
            </h3>
            <div id={pid} role="region" aria-labelledby={hid} hidden={!isOpen} className={styles.panel}>
              <MarkdownText text={it.answer} />
            </div>
          </div>
        );
      })}
    </div>
  );
}
