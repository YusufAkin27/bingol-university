import { cloneElement, useId, useState, type ReactElement } from 'react';
import styles from './Tooltip.module.css';

interface Props {
  text: string;
  children: ReactElement;
}

/** Hover/odakla görünen ipucu; ESC ile kapanır. Tek bir odaklanabilir çocuk bekler. */
export function Tooltip({ text, children }: Props) {
  const id = useId();
  const [open, setOpen] = useState(false);
  const child = cloneElement(children as ReactElement<Record<string, unknown>>, { 'aria-describedby': id });
  return (
    <span
      className={styles.wrap}
      onMouseEnter={() => setOpen(true)}
      onMouseLeave={() => setOpen(false)}
      onFocus={() => setOpen(true)}
      onBlur={() => setOpen(false)}
      onKeyDown={(e) => e.key === 'Escape' && setOpen(false)}
    >
      {child}
      <span id={id} role="tooltip" className={`${styles.tip} ${open ? styles.open : ''}`}>
        {text}
      </span>
    </span>
  );
}
