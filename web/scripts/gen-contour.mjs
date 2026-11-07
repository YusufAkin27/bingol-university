// ContourBackdrop.tsx'teki algoritmanin ayni ciktisi: tek statik SVG (beyaz cizgiler; opaklik CSS'ten).
import fs from 'node:fs';
const PEAKS = [
  { cx: 560, cy: 250, rings: 15, step: 26, seed: 1.3 },
  { cx: 170, cy: 470, rings: 10, step: 24, seed: 4.1 },
];
const N = 60;
function ring(p, k) {
  const pts = [];
  const r0 = 18 + k * p.step;
  for (let i = 0; i <= N; i++) {
    const a = (i / N) * Math.PI * 2;
    const wob = 1 + 0.11 * Math.sin(3 * a + p.seed + k * 0.22) + 0.06 * Math.sin(5 * a - p.seed * 1.7 + k * 0.1);
    const x = p.cx + Math.cos(a) * r0 * wob * 1.35;
    const y = p.cy + Math.sin(a) * r0 * wob * 0.85;
    pts.push(`${i ? 'L' : 'M'}${+x.toFixed(1)} ${+y.toFixed(1)}`);
  }
  return pts.join('') + 'Z';
}
const major = [];
const minor = [];
PEAKS.forEach((p) => {
  for (let k = 0; k < p.rings; k++) (k % 4 === 0 ? major : minor).push(ring(p, k));
});
const svg =
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 600" preserveAspectRatio="xMidYMid slice" fill="none" stroke="#fff">` +
  `<path d="${minor.join('')}" stroke-width="0.9" opacity="0.28"/>` +
  `<path d="${major.join('')}" stroke-width="1.6" opacity="0.55"/>` +
  `</svg>\n`;
fs.writeFileSync(process.argv[2], svg);
console.log(svg.length);
