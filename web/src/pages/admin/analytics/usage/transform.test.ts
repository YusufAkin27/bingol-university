import { describe, expect, it } from 'vitest';
import type { UsageHourly } from '../../../../api/usage';
import {
  csvCell,
  flowRows,
  formatSeconds,
  heatGrid,
  isEmptyUsage,
  orderSegments,
  toCsv,
  usageCsvRows,
} from './transform';

describe('formatSeconds', () => {
  it('saniye, dakika ve saat biçimleri', () => {
    expect(formatSeconds(8)).toBe('8 sn');
    expect(formatSeconds(75)).toBe('1 dk 15 sn');
    expect(formatSeconds(120)).toBe('2 dk');
    expect(formatSeconds(3660)).toBe('1 sa 1 dk');
  });
  it('veri yoksa null', () => {
    expect(formatSeconds(null)).toBeNull();
    expect(formatSeconds(undefined)).toBeNull();
    expect(formatSeconds(-3)).toBeNull();
    expect(formatSeconds(Number.NaN)).toBeNull();
  });
});

describe('heatGrid', () => {
  const hourly: UsageHourly = {
    from: '2026-10-01',
    to: '2026-10-31',
    totalSessions: 130,
    totalViews: 400,
    peak: { dow: 5, hour: 13, sessions: 100 },
    cells: [
      { dow: 5, hour: 13, sessions: 100, views: 300 },
      { dow: 1, hour: 9, sessions: 30, views: 100 },
      { dow: 2, hour: 2, sessions: 1, views: 1 },
    ],
  };
  it('7x24 ızgara kurar, eksik hücre 0 olur', () => {
    const g = heatGrid(hourly);
    expect(g).toHaveLength(7);
    expect(g.every((row) => row.length === 24)).toBe(true);
    expect(g[0][0].sessions).toBe(0);
    expect(g[0][0].level).toBe(0);
  });
  it('basamaklar en yoğun hücreye oranlanır', () => {
    const g = heatGrid(hourly);
    expect(g[4][13].level).toBe(4); // pazartesi=0 → cuma=4
    expect(g[0][9].level).toBe(2); // 30/100 = 0.30
    expect(g[1][2].level).toBe(1); // 0.01
  });
  it('veri yoksa hepsi 0 ve çökmez', () => {
    const g = heatGrid(undefined);
    expect(g.flat().every((c) => c.level === 0)).toBe(true);
  });
});

describe('flowRows', () => {
  it('genişlik ve pay hesaplar', () => {
    const rows = flowRows({
      from: 'a',
      to: 'b',
      totalTransitions: 200,
      edges: [
        { from: 'home', to: 'news_list', count: 100 },
        { from: 'news_list', to: 'news_detail', count: 50 },
      ],
    });
    expect(rows[0].widthPercent).toBe(100);
    expect(rows[1].widthPercent).toBe(50);
    expect(rows[0].sharePercent).toBe(50);
  });
  it('boş akış boş liste', () => {
    expect(flowRows(undefined)).toEqual([]);
  });
});

describe('orderSegments', () => {
  it('other ve unknown sona gider, unknown other öncesi', () => {
    const out = orderSegments([
      { key: 'other', userDays: 500 },
      { key: 'a', userDays: 10 },
      { key: 'unknown', userDays: 400 },
      { key: 'b', userDays: 20 },
    ]);
    expect(out.map((i) => i.key)).toEqual(['b', 'a', 'unknown', 'other']);
  });
});

describe('CSV', () => {
  it('formül enjeksiyonu önlenir (=, +, -, @, sekme)', () => {
    expect(csvCell('=HYPERLINK("http://x")')).toBe('"\'=HYPERLINK(""http://x"")"');
    expect(csvCell('+1')).toBe("'+1");
    expect(csvCell('-2')).toBe("'-2");
    expect(csvCell('@SUM(A1)')).toBe("'@SUM(A1)");
    expect(csvCell('\tcmd')).toBe("'\tcmd");
  });
  it('virgül, tırnak ve satır sonu çift tırnağa alınır; sayı ve boş değerler dokunulmaz', () => {
    expect(csvCell('a,b')).toBe('"a,b"');
    expect(csvCell('a "b"')).toBe('"a ""b"""');
    expect(csvCell('x\ny')).toBe('"x\ny"');
    expect(csvCell(-5)).toBe('-5');
    expect(csvCell(null)).toBe('');
    expect(csvCell(Number.NaN)).toBe('');
  });
  it('toCsv satırları CRLF ile birleştirir', () => {
    expect(toCsv([['a', 1], ['b', null]])).toBe('a,1\r\nb,');
  });
  it('usageCsvRows başlık satırı ile başlar, kullanıcı kimliği sütunu yoktur', () => {
    const rows = usageCsvRows({
      screens: {
        from: 'a',
        to: 'b',
        dates: [],
        totalViews: 5,
        items: [{ screen: '=evil', views: 5, userDays: 2, avgDailyUsers: 1, avgSeconds: 10, medianSeconds: null, exitPercent: 20, trend: [] }],
      },
      screenLabel: (k) => k,
      actionLabel: (k) => k,
      featureLabel: (k) => k,
    });
    expect(rows[0]).toEqual(['bolum', 'oge', 'olcu', 'deger']);
    expect(rows[1]).toEqual(['ekran', '=evil', 'goruntuleme', 5]);
    expect(toCsv(rows)).toContain("'=evil");
    expect(toCsv(rows)).not.toMatch(/user_?id|e-?posta/i);
  });
});

describe('isEmptyUsage', () => {
  it('hiç ekran, eylem, akış ve oturum yoksa boştur', () => {
    expect(isEmptyUsage({})).toBe(true);
    expect(
      isEmptyUsage({
        screens: { from: 'a', to: 'b', dates: [], totalViews: 0, items: [] },
        hourly: { from: 'a', to: 'b', totalSessions: 0, totalViews: 0, peak: null, cells: [] },
      }),
    ).toBe(true);
  });
  it('tek oturum bile varsa dolu', () => {
    expect(
      isEmptyUsage({ hourly: { from: 'a', to: 'b', totalSessions: 1, totalViews: 0, peak: null, cells: [] } }),
    ).toBe(false);
  });
});
