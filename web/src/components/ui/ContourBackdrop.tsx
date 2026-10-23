import { useMemo } from 'react';

interface Peak {
  cx: number;
  cy: number;
  rings: number;
  step: number;
  seed: number;
}

const PEAKS: Peak[] = [
  { cx: 560, cy: 250, rings: 15, step: 26, seed: 1.3 },
  { cx: 170, cy: 470, rings: 10, step: 24, seed: 4.1 },
];

function ring(p: Peak, k: number): string {
  const pts: string[] = [];
  const n = 72;
  const r0 = 18 + k * p.step;
  for (let i = 0; i <= n; i++) {
    const a = (i / n) * Math.PI * 2;
    // Yükseklik eğrisi gibi: halkalar dışa doğru giderek dağılır, doğu-batı yönünde uzar
    const wob =
      1 + 0.11 * Math.sin(3 * a + p.seed + k * 0.22) + 0.06 * Math.sin(5 * a - p.seed * 1.7 + k * 0.1);
    const x = p.cx + Math.cos(a) * r0 * wob * 1.35;
    const y = p.cy + Math.sin(a) * r0 * wob * 0.85;
    pts.push(`${i ? 'L' : 'M'}${x.toFixed(1)} ${y.toFixed(1)}`);
  }
  return `${pts.join(' ')}Z`;
}

/** Bingöl dağlarının kabartma (topografik) çizgilerinden esinlenen dekoratif zemin. Rengi `color` belirler. */
export function ContourBackdrop({ className }: { className?: string }) {
  const paths = useMemo(
    () =>
      PEAKS.flatMap((p, pi) =>
        Array.from({ length: p.rings }, (_, k) => ({ key: `${pi}-${k}`, d: ring(p, k), major: k % 4 === 0 })),
      ),
    [],
  );
  return (
    <svg
      className={className}
      viewBox="0 0 800 600"
      preserveAspectRatio="xMidYMid slice"
      aria-hidden="true"
      focusable="false"
      fill="none"
      stroke="currentColor"
    >
      {paths.map((p) => (
        <path key={p.key} d={p.d} strokeWidth={p.major ? 1.6 : 0.9} opacity={p.major ? 0.55 : 0.28} />
      ))}
    </svg>
  );
}
