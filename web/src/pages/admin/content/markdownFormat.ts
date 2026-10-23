/** Markdown araç çubuğu için saf metin dönüşümleri (seçim aralığına göre). */
export type MdFormat = 'heading' | 'bold' | 'italic' | 'list' | 'link';

export interface EditResult {
  value: string;
  selStart: number;
  selEnd: number;
}

const PLACEHOLDER: Record<MdFormat, string> = {
  heading: '',
  bold: 'metin',
  italic: 'metin',
  list: '',
  link: 'bağlantı',
};

function wrap(value: string, start: number, end: number, mark: string, placeholder: string): EditResult {
  const sel = value.slice(start, end);
  // Seçim zaten işaretlerle çevriliyse işareti kaldır
  if (
    start >= mark.length &&
    value.slice(start - mark.length, start) === mark &&
    value.slice(end, end + mark.length) === mark
  ) {
    return {
      value: value.slice(0, start - mark.length) + sel + value.slice(end + mark.length),
      selStart: start - mark.length,
      selEnd: end - mark.length,
    };
  }
  const inner = sel || placeholder;
  const next = value.slice(0, start) + mark + inner + mark + value.slice(end);
  return { value: next, selStart: start + mark.length, selEnd: start + mark.length + inner.length };
}

/** Seçimin kapsadığı satırların [başlangıç, bitiş) aralığı. */
function lineRange(value: string, start: number, end: number): [number, number] {
  const from = start === 0 ? 0 : value.lastIndexOf('\n', start - 1) + 1;
  const nl = value.indexOf('\n', end);
  return [from, nl === -1 ? value.length : nl];
}

function prefixLines(value: string, start: number, end: number, prefix: string): EditResult {
  const [a, b] = lineRange(value, start, end);
  const lines = value.slice(a, b).split('\n');
  const all = lines.every((l) => l.startsWith(prefix));
  const out = lines.map((l) => (all ? l.slice(prefix.length) : l.startsWith(prefix) ? l : prefix + l));
  const block = out.join('\n');
  return { value: value.slice(0, a) + block + value.slice(b), selStart: a, selEnd: a + block.length };
}

export function applyFormat(value: string, start: number, end: number, fmt: MdFormat): EditResult {
  const s = Math.max(0, Math.min(start, value.length));
  const e = Math.max(s, Math.min(end, value.length));
  switch (fmt) {
    case 'bold':
      return wrap(value, s, e, '**', PLACEHOLDER.bold);
    case 'italic':
      return wrap(value, s, e, '*', PLACEHOLDER.italic);
    case 'heading':
      return prefixLines(value, s, e, '## ');
    case 'list':
      return prefixLines(value, s, e, '- ');
    case 'link': {
      const text = value.slice(s, e) || PLACEHOLDER.link;
      const url = 'https://';
      const md = `[${text}](${url})`;
      const urlStart = s + text.length + 3;
      return { value: value.slice(0, s) + md + value.slice(e), selStart: urlStart, selEnd: urlStart + url.length };
    }
  }
}
