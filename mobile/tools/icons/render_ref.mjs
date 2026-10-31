// resvg ile SVG -> PNG (dogrulama referansi). Kullanim: node render_ref.mjs jobs.json
// jobs.json: [{ "svg": "<svg ...>", "size": 96, "out": "yol.png" }, ...]
import { Resvg } from '@resvg/resvg-js';
import { readFileSync, writeFileSync } from 'node:fs';

const jobs = JSON.parse(readFileSync(process.argv[2], 'utf8'));
for (const j of jobs) {
  const r = new Resvg(j.svg, { fitTo: { mode: 'width', value: j.size }, background: '#ffffff' });
  writeFileSync(j.out, r.render().asPng());
}
console.log('rendered', jobs.length);
