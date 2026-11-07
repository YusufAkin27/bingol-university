import type { ReactNode } from 'react';
import { Link } from '../../../components/LocalizedLink';
import { Icon } from '../../../components/ui';
import styles from './InlineLinks.module.css';

export interface InlineLinkItem {
  /** Mantıksal site yolu (`paths.site.*`, `#kanca` olabilir); dil öneki Link ekler. */
  to: string;
  /** Açıklayıcı bağlantı metni (hedefi anlatır; "tıklayın" gibi ifadeler kullanılmaz). */
  label: string;
}

interface Props {
  /** Bölümün erişilebilir adı. */
  label: string;
  /** İsteğe bağlı görünür başlık. */
  title?: string;
  /** Bağlantılardan önce gelen kısa metin. */
  children?: ReactNode;
  links: InlineLinkItem[];
}

/** Sayfa sonlarında düzeni bozmayan, metin içi bağlantı / çağrı satırı (iç bağlantı ağı için). */
export function InlineLinks({ label, title, children, links }: Props) {
  return (
    <section className={styles.section} aria-label={label}>
      <div className="container">
        <div className={styles.box}>
          {title && <h2 className={styles.title}>{title}</h2>}
          {children && <p className={styles.text}>{children}</p>}
          <ul className={styles.list}>
            {links.map((l) => (
              <li key={l.to}>
                <Link to={l.to} className={styles.link}>
                  {l.label}
                  <Icon name="chevronRight" size={16} className={styles.arrow} />
                </Link>
              </li>
            ))}
          </ul>
        </div>
      </div>
    </section>
  );
}
