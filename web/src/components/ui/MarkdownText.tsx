import { Fragment, type ReactNode } from 'react';
import styles from './MarkdownText.module.css';

/**
 * Güvenli, küçük Markdown alt kümesi: başlık (#..###), madde/numaralı liste, **kalın**, *italik*, [metin](bağlantı).
 * HTML asla enjekte edilmez (her şey React düğümü olarak üretilir); yalnızca http(s), mailto, "/" ve "#" bağlantıları
 * izin alır, diğerleri düz metin kalır.
 */
const SAFE_URL = /^(https?:\/\/|mailto:|\/(?!\/)|#)/i;
const INLINE = /\*\*([^*]+)\*\*|\[([^\]]+)\]\(([^)\s]+)\)|\*([^*\s][^*]*)\*/g;

function inline(text: string): ReactNode[] {
  const out: ReactNode[] = [];
  let last = 0;
  let i = 0;
  for (const m of text.matchAll(INLINE)) {
    const idx = m.index ?? 0;
    if (idx > last) out.push(text.slice(last, idx));
    if (m[1] !== undefined) out.push(<strong key={i++}>{m[1]}</strong>);
    else if (m[2] !== undefined) {
      const url = m[3];
      if (SAFE_URL.test(url)) {
        const external = /^https?:/i.test(url);
        out.push(
          <a key={i++} href={url} {...(external ? { target: '_blank', rel: 'noopener noreferrer' } : {})}>
            {m[2]}
          </a>,
        );
      } else out.push(m[0]);
    } else if (m[4] !== undefined) out.push(<em key={i++}>{m[4]}</em>);
    last = idx + m[0].length;
  }
  if (last < text.length) out.push(text.slice(last));
  return out;
}

type Block =
  | { kind: 'h'; level: 3 | 4 | 5; text: string }
  | { kind: 'ul' | 'ol'; items: string[] }
  | { kind: 'p'; lines: string[] }
  | { kind: 'quote'; lines: string[] }
  | { kind: 'table'; head: string[]; rows: string[][] };

/** "| a | b |" satırını hücrelere böler (baştaki/sondaki boru atılır). */
function cells(line: string): string[] {
  return line
    .trim()
    .replace(/^\|/, '')
    .replace(/\|$/, '')
    .split('|')
    .map((c) => c.trim());
}
const TABLE_SEP = /^\s*\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)*\|?\s*$/;

export function parseBlocks(src: string): Block[] {
  const blocks: Block[] = [];
  let cur: Block | null = null;
  const flush = () => {
    if (cur) blocks.push(cur);
    cur = null;
  };
  for (const raw of src.replace(/\r\n?/g, '\n').split('\n')) {
    const line = raw.trimEnd();
    if (!line.trim()) {
      flush();
      continue;
    }
    const h = /^(#{1,3})\s+(.*)$/.exec(line);
    if (h) {
      flush();
      // Sayfa başlığı zaten h1/h2: içerik başlıkları h3'ten başlar
      blocks.push({ kind: 'h', level: (h[1].length + 2) as 3 | 4 | 5, text: h[2] });
      continue;
    }
    const q = /^>\s?(.*)$/.exec(line);
    if (q) {
      if (cur && (cur as Block).kind === 'quote') (cur as { lines: string[] }).lines.push(q[1]);
      else {
        flush();
        cur = { kind: 'quote', lines: [q[1]] };
      }
      continue;
    }
    if (line.trimStart().startsWith('|')) {
      if (cur && (cur as Block).kind === 'table') {
        // Ayırıcı satır (---) atlanır; kalanlar gövde satırı
        if (!TABLE_SEP.test(line)) (cur as { rows: string[][] }).rows.push(cells(line));
      } else {
        flush();
        cur = { kind: 'table', head: cells(line), rows: [] };
      }
      continue;
    }
    const ul = /^\s*[-*]\s+(.*)$/.exec(line);
    const ol = /^\s*\d+[.)]\s+(.*)$/.exec(line);
    if (ul || ol) {
      const kind = ul ? 'ul' : 'ol';
      const text = (ul ?? ol)![1];
      if (cur && (cur as Block).kind === kind) (cur as { items: string[] }).items.push(text);
      else {
        flush();
        cur = { kind, items: [text] };
      }
      continue;
    }
    if (cur && (cur as Block).kind === 'p') (cur as { lines: string[] }).lines.push(line.trim());
    else {
      flush();
      cur = { kind: 'p', lines: [line.trim()] };
    }
  }
  flush();
  return blocks;
}

export function MarkdownText({ text, className }: { text: string; className?: string }) {
  const blocks = parseBlocks(text);
  return (
    <div className={`${styles.md} ${className ?? ''}`}>
      {blocks.map((b, i) => {
        switch (b.kind) {
          case 'h': {
            const H = `h${b.level}` as 'h3' | 'h4' | 'h5';
            return <H key={i}>{inline(b.text)}</H>;
          }
          case 'ul':
            return (
              <ul key={i}>
                {b.items.map((it, j) => (
                  <li key={j}>{inline(it)}</li>
                ))}
              </ul>
            );
          case 'ol':
            return (
              <ol key={i}>
                {b.items.map((it, j) => (
                  <li key={j}>{inline(it)}</li>
                ))}
              </ol>
            );
          case 'quote':
            return (
              <blockquote key={i}>
                {b.lines.map((l, j) => (
                  <p key={j}>{inline(l)}</p>
                ))}
              </blockquote>
            );
          case 'table':
            return (
              <div key={i} className={styles.tableWrap}>
                <table>
                  <thead>
                    <tr>
                      {b.head.map((h, j) => (
                        <th key={j}>{inline(h)}</th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {b.rows.map((r, j) => (
                      <tr key={j}>
                        {r.map((c, k) => (
                          <td key={k}>{inline(c)}</td>
                        ))}
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            );
          default:
            return (
              <p key={i}>
                {b.lines.map((l, j) => (
                  <Fragment key={j}>
                    {j > 0 && <br />}
                    {inline(l)}
                  </Fragment>
                ))}
              </p>
            );
        }
      })}
    </div>
  );
}
