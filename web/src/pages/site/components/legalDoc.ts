export interface LegalSection {
  id: string | null;
  level: 2 | 3;
  title: string | null;
  body: string;
}

export interface PreparedLegal {
  /** İçerikte "TASLAK" geçiyor mu. */
  draft: boolean;
  sections: LegalSection[];
  toc: { id: string; title: string }[];
}

function slug(s: string): string {
  return (
    s
      .toLocaleLowerCase('tr')
      .replace(/ı/g, 'i')
      .normalize('NFD')
      .replace(/[̀-ͯ]/g, '')
      .replace(/[^\p{L}\p{N}]+/gu, '-')
      .replace(/^-+|-+$/g, '') || 'bolum'
  );
}

/**
 * Yasal metni bölümlere ayırır. Başlıklar `#`/`##`/`###` satırlarıdır; ayrıca tek satırlık, noktalama ile
 * bitmeyen "1. Başlık" satırları (boşlukla ayrılmış, ardından numaralı olmayan metin gelen) başlık sayılır.
 * Baştaki "TASLAK ..." uyarı paragrafı metinden çıkarılır (yerine yerelleştirilmiş uyarı gösterilir).
 */
export function prepareLegal(content: string): PreparedLegal {
  const lines = content.replace(/\r\n?/g, '\n').split('\n');
  const draft = /TASLAK/i.test(content);

  // Baştaki TASLAK paragrafını ayıkla
  let start = 0;
  while (start < lines.length && !lines[start].trim()) start++;
  if (/^\s*TASLAK/i.test(lines[start] ?? '')) {
    while (start < lines.length && lines[start].trim()) start++;
  }
  const rest = lines.slice(start);

  const sections: LegalSection[] = [];
  const used = new Set<string>();
  let cur: LegalSection = { id: null, level: 2, title: null, body: '' };
  const push = () => {
    if (cur.title || cur.body.trim()) sections.push({ ...cur, body: cur.body.trim() });
  };
  const open = (title: string, level: 2 | 3) => {
    push();
    let id = slug(title);
    let n = 2;
    while (used.has(id)) id = `${slug(title)}-${n++}`;
    used.add(id);
    cur = { id, level, title, body: '' };
  };

  for (let i = 0; i < rest.length; i++) {
    const line = rest[i];
    const h = /^(#{1,3})\s+(.*\S)\s*$/.exec(line);
    if (h) {
      open(h[2].replace(/\*\*/g, ''), h[1].length >= 3 ? 3 : 2);
      continue;
    }
    const num = /^(\d+)\.\s+(.{2,70})$/.exec(line.trim());
    const prevBlank = i === 0 || !rest[i - 1].trim();
    const next = rest[i + 1];
    if (
      num &&
      prevBlank &&
      next !== undefined &&
      next.trim() &&
      !/^\s*\d+[.)]\s/.test(next) &&
      !/[.:;,!?)]$/.test(line.trim())
    ) {
      open(`${num[1]}. ${num[2]}`, 2);
      continue;
    }
    cur.body += `${line}\n`;
  }
  push();

  const toc = sections.filter((s) => s.id && s.level === 2).map((s) => ({ id: s.id!, title: s.title! }));
  return { draft, sections, toc };
}
