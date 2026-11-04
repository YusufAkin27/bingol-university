import {
  useEffect,
  useLayoutEffect,
  useRef,
  useState,
  type CSSProperties,
  type ElementType,
  type ReactNode,
} from 'react';
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

/** Yerleşim boyanmadan önce çalışsın diye tarayıcıda useLayoutEffect (sunucuda uyarı vermemesi için useEffect). */
const useIsoLayoutEffect = typeof window === 'undefined' ? useEffect : useLayoutEffect;

/**
 * Kaydırınca hafifçe beliren (opacity + transform) sarmalayıcı; JS animasyon kitaplığı yok.
 *
 * Güvenli varsayılan: içerik HER ZAMAN görünür başlar (önrender, JS'siz, yazdırma, animasyon hatası). Gizleme yalnız
 * tarayıcıda, öğe ilk ekranın altındaysa ve IntersectionObserver varsa "silahlanır"; öğe görünür alana girince açılır.
 * IntersectionObserver sessiz kalırsa kaydırma/yeniden boyutlandırma dinleyicisi aynı ölçümü elle yapar (yedek yol).
 * - İlk ekrandaki (LCP) öğeler hiç gizlenmez; `prefers-reduced-motion` açıksa hiçbir öğe gizlenmez.
 * - Yerleşimi etkilemez (transform), CLS üretmez.
 */
export function Reveal({ children, as, delay = 0, className, style }: Props) {
  const Tag = (as ?? 'div') as ElementType;
  const ref = useRef<HTMLElement>(null);
  // hidden: yalnız silahlanmış ve henüz görünür alana girmemiş öğe gizlidir
  const [hidden, setHidden] = useState(false);

  useIsoLayoutEffect(() => {
    const el = ref.current;
    if (!el || typeof IntersectionObserver === 'undefined') return undefined;
    if (typeof window.matchMedia === 'function' && window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      return undefined;
    }
    const inView = () => {
      const r = el.getBoundingClientRect();
      return r.top < window.innerHeight * 0.94;
    };
    // ilk ekranda ya da üstünde (sayfa kaydırılmış açıldıysa) olan öğe gizlenmez
    if (inView()) return undefined;
    setHidden(true);
    let done = false;
    const show = () => {
      if (done) return;
      done = true;
      setHidden(false);
      cleanup();
    };
    const io = new IntersectionObserver(
      (entries) => {
        if (entries.some((e) => e.isIntersecting)) show();
      },
      { rootMargin: '0px 0px -6% 0px', threshold: 0.04 },
    );
    io.observe(el);
    const check = () => {
      if (inView()) show();
    };
    window.addEventListener('scroll', check, { passive: true });
    window.addEventListener('resize', check, { passive: true });
    function cleanup() {
      io.disconnect();
      window.removeEventListener('scroll', check);
      window.removeEventListener('resize', check);
    }
    return () => {
      done = true;
      cleanup();
    };
  }, []);

  return (
    <Tag
      ref={ref}
      className={`${styles.reveal} ${hidden ? styles.hidden : ''} ${className ?? ''}`}
      style={delay ? { ...style, transitionDelay: `${delay}ms` } : style}
    >
      {children}
    </Tag>
  );
}
