// Node only; FFmpeg supplies the open-source x264 encoder and SSIM measurement.
// node scripts/benchmark-media.mjs <ffmpeg executable> <output folder> [source.mp4]
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const [ffmpeg, output, suppliedSource] = process.argv.slice(2);
if (!ffmpeg || !output) throw new Error('Usage: node scripts/benchmark-media.mjs <ffmpeg> <output folder> [source.mp4]');
const out = path.resolve(output);
fs.mkdirSync(out, { recursive: true });
function run(args) {
  const r = spawnSync(ffmpeg, ['-hide_banner', '-nostdin', ...args], { encoding: 'utf8', timeout: 300000, maxBuffer: 8 * 1024 * 1024 });
  if (r.error || r.status !== 0) throw r.error ?? new Error(r.stderr);
  return r.stderr;
}
const input = suppliedSource ? path.resolve(suppliedSource) : path.join(out, 'synthetic-camera.mp4');
if (!suppliedSource) {
  run(['-y', '-f', 'lavfi', '-i', 'testsrc2=size=1920x1080:rate=30', '-f', 'lavfi', '-i', 'sine=frequency=440:sample_rate=48000',
    '-t', '5', '-c:v', 'libx264', '-preset', 'ultrafast', '-crf', '12', '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-b:a', '192k', input]);
}
const probe = run(['-i', input, '-t', '0', '-f', 'null', '-']);
const dimensions = probe.match(/Video:[^\r\n]*?\b(\d{2,5})x(\d{2,5})\b/);
if (!dimensions) throw new Error('Cannot read source dimensions');
const width = Number(dimensions[1]), height = Number(dimensions[2]);
const sourceBytes = fs.statSync(input).size;
const filter = "scale=w='if(gte(iw,ih),min(1920,iw),min(1080,iw))':h='if(gte(iw,ih),min(1080,ih),min(1920,ih))':force_original_aspect_ratio=decrease:force_divisible_by=2";
const results = [];
for (const crf of [18, 22, 26]) {
  const file = path.join(out, `video-crf${crf}.mp4`);
  const start = performance.now();
  run(['-y', '-i', input, '-map', '0:v:0', '-map', '0:a:0?', '-sn', '-dn', '-map_metadata', '-1', '-vf', filter,
    '-c:v', 'libx264', '-profile:v', 'main', '-pix_fmt', 'yuv420p', '-preset', 'medium', '-crf', String(crf),
    '-maxrate', '5400k', '-bufsize', '9000k', '-threads', '1', '-c:a', 'aac', '-b:a', '128k', '-ac', '2', '-movflags', '+faststart', file]);
  const elapsedMs = Math.round(performance.now() - start);
  const metric = run(['-i', input, '-i', file, '-filter_complex',
    `[0:v]setpts=PTS-STARTPTS,format=yuv420p[ref];[1:v]setpts=PTS-STARTPTS,scale=${width}:${height}:flags=lanczos,format=yuv420p[dist];[ref][dist]ssim=shortest=1`,
    '-an', '-f', 'null', '-']);
  const ssim = metric.match(/All:([0-9.]+)/);
  const bytes = fs.statSync(file).size;
  results.push({ source: suppliedSource ? path.basename(input) : 'synthetic testsrc2 (not real camera footage)', crf,
    sourceBytes, outputBytes: bytes, ratio: sourceBytes / bytes, savedPercent: 100 * (1 - bytes / sourceBytes),
    ssim: ssim ? Number(ssim[1]) : null, elapsedMs, selectedByDefault: crf === 22,
    qualityNote: 'SSIM is a similarity index, not a percentage of perceived visual loss.' });
}
fs.writeFileSync(path.join(out, 'video-results.json'), JSON.stringify(results, null, 2));
console.log(JSON.stringify(results, null, 2));
