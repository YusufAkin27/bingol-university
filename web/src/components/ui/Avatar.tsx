import { useState } from 'react';
import styles from './Avatar.module.css';

interface Props {
  name: string;
  src?: string | null;
  size?: number;
}

/** Fotoğraf yoksa ya da yüklenemezse adın baş harfleri (monochrome: nötr zemin, renk türetilmez; fotoğraf doğal renkte kalır). */
export function Avatar({ name, src, size = 36 }: Props) {
  const [failed, setFailed] = useState(false);
  const initials = name
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map((p) => p.charAt(0))
    .join('')
    .toLocaleUpperCase();
  const showImg = !!src && !failed;
  return (
    <span
      className={styles.avatar}
      style={{
        width: size,
        height: size,
        fontSize: size * 0.4,
      }}
      role="img"
      aria-label={name}
    >
      {showImg ? <img src={src!} alt="" onError={() => setFailed(true)} /> : initials || '?'}
    </span>
  );
}
