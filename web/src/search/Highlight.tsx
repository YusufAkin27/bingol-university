import { useMemo } from 'react';
import { highlight } from './engine';
import styles from './search.module.css';

/** Metindeki sorguyla eşleşen kısımları <mark> ile vurgular (renk + kalınlık; yalnız renge güvenmez). */
export function Highlight({ text, query }: { text: string; query: string }) {
  const segs = useMemo(() => highlight(text, query), [text, query]);
  return (
    <>
      {segs.map((s, i) =>
        s.hit ? (
          <mark key={i} className={styles.mark}>
            {s.text}
          </mark>
        ) : (
          <span key={i}>{s.text}</span>
        ),
      )}
    </>
  );
}
