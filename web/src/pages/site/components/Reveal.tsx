import { useEffect, useRef, useState, type CSSProperties, type ElementType, type ReactNode } from 'react';
import styles from './Reveal.module.css';

interface Props {
  children: ReactNode;
  /** Eleman türü (varsayılan div). */
  as?: ElementType;
  /** Gecikme (ms): aynı bölümdeki kardeşler için 60-120 ms basamak verin. */
  delay?: number;
  className?: string;
  style?: CSSProperties;
}

/**
 * Kaydırınca hafifçe beliren (opacity + transform) sarmalayıcı; JS animasyon kitaplığı yok, yalnız IntersectionObserver.
 * - Ekranın ilk görünümündeki (LCP) öğeleri SARMAYIN.
 * - `prefers-reduced-motion` açıksa ve IntersectionObserver yoksa (test, eski tarayıcı) içerik doğrudan görünür.
 * - Yerleşimi etkilemez (transform), CLS üretmez.
 */
export function Reveal({ children, as, delay = 0, className, style }: Props) {
  const Tag = (as ?? 'div') as ElementType;
  const ref = useRef<HTMLElement>(null);
  const [shown, setShown] = useState(() => typeof IntersectionObserver === 'undefined');
  useEffect(() => {
    const el = ref.current;
    if (shown || !el) return undefined;
    const io = new IntersectionObserver(
      (entries) => {
        if (entries.some((e) => e.isIntersecting)) {
          setShown(true);
          io.disconnect();
        }
      },
      { rootMargin: '0px 0px -8% 0px', threshold: 0.05 },
    );
    io.observe(el);
    return () => io.disconnect();
  }, [shown]);
  return (
    <Tag
      ref={ref}
      className={`${styles.reveal} ${shown ? styles.shown : ''} ${className ?? ''}`}
      style={delay ? { ...style, transitionDelay: `${delay}ms` } : style}
    >
      {children}
    </Tag>
  );
}
