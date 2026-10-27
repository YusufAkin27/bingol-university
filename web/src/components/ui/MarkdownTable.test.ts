import { describe, expect, it } from 'vitest';
import { parseBlocks } from './MarkdownText';

describe('MarkdownText tablo ve alıntı', () => {
  it('tabloyu başlık ve satırlara ayırır, ayırıcıyı atar', () => {
    const b = parseBlocks('| A | B |\n|---|---|\n| 1 | 2 |\n| 3 | 4 |');
    expect(b).toEqual([{ kind: 'table', head: ['A', 'B'], rows: [['1', '2'], ['3', '4']] }]);
  });

  it('"> Özetle" satırını alıntı bloğu yapar', () => {
    const b = parseBlocks('metin\n\n> **Özetle:** kısa\n\nson');
    expect(b.map((x) => x.kind)).toEqual(['p', 'quote', 'p']);
  });
});
