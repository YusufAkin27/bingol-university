// Haber yönetimi: tür dağılımı (haber / duyuru / etkinlik) için saf yardımcılar.
export type DistTone = 'info' | 'warning' | 'success' | 'neutral';

export interface DistPart {
  key: string;
  label: string;
  value: number;
  tone: DistTone;
}

/** Bilinen türler sabit sırada ve sabit renkte; bilinmeyen bir tür gelirse sona nötr olarak eklenir. */
const KNOWN: { key: string; tone: DistTone }[] = [
  { key: 'HABER', tone: 'info' },
  { key: 'DUYURU', tone: 'warning' },
  { key: 'ETKINLIK', tone: 'success' },
];

export function newsDistribution(byType: Record<string, number>, labelOf: (key: string) => string): DistPart[] {
  const known = KNOWN.map((k) => ({ key: k.key, label: labelOf(k.key), value: Math.max(0, byType[k.key] ?? 0), tone: k.tone }));
  const extra = Object.keys(byType)
    .filter((k) => !KNOWN.some((x) => x.key === k))
    .sort()
    .map((k) => ({ key: k, label: labelOf(k), value: Math.max(0, byType[k]), tone: 'neutral' as const }));
  return [...known, ...extra].filter((p) => p.value > 0);
}

/** "Haber 120, Duyuru 340" biçiminde kısa döküm (büyükten küçüğe). */
export function distributionText(parts: DistPart[], fmt: (n: number) => string): string {
  return [...parts]
    .sort((a, b) => b.value - a.value)
    .map((p) => `${p.label} ${fmt(p.value)}`)
    .join(', ');
}
