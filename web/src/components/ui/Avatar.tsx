import { useState } from 'react';
import styles from './Avatar.module.css';

interface Props {
  name: string;
  src?: string | null;
  size?: number;
}

/** Fotoğraf yoksa ya da yüklenemezse adın baş harfleri (ad rengi sabit, ad'dan türetilir). */
export function Avatar({ name, src, size = 36 }: Props) {
  const [failed, setFailed] = useState(false);
  const initials = name
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map((p) => p.charAt(0))
    .join('')
    .toLocaleUpperCase();
  let h = 0;
  for (const ch of name) h = (h * 31 + ch.charCodeAt(0)) % 360;
  const showImg = !!src && !failed;
  return (
    <span
      className={styles.avatar}
      style={{
        width: size,
        height: size,
        fontSize: size * 0.4,
        background: showImg ? undefined : `hsl(${h} 38% 32%)`,
      }}
      role="img"
      aria-label={name}
    >
      {showImg ? <img src={src!} alt="" onError={() => setFailed(true)} /> : initials || '?'}
    </span>
  );
}
