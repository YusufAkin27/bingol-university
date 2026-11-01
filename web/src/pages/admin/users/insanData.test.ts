import { describe, expect, it } from 'vitest';
import type { AdminUserDetail, BreakdownResponse } from '../../../api/types';
import {
  attentionItems,
  buildTimeline,
  compareTrend,
  computeRisk,
  facultyRows,
  statusSlices,
  weekOverWeek,
  weeklyEnablements,
} from './insanData';

const NOW = new Date('2026-11-01T12:00:00').getTime();
const DAY = 86_400_000;
const ago = (d: number) => new Date(NOW - d * DAY).toISOString();

const detail = (over: Partial<AdminUserDetail> = {}): AdminUserDetail =>
  ({
    id: 3,
    email: 'a@bingol.edu.tr',
    displayName: 'Ayşe',
    faculty: null,
    department: null,
    classYear: null,
    language: 'tr',
    role: 'USER',
    status: 'ACTIVE',
    emailVerified: true,
    createdAt: ago(40),
    lastSeenAt: ago(1),
    avatarUrl: null,
    bio: null,
    suspendedReason: null,
    deletedAt: null,
    deviceCount: 0,
    platforms: [],
    counts: { feedback: 0, tickets: 0, reportsAgainst: 0, reportsFiled: 0, conversations: 0, communities: 0, eventsCreated: 0, bookmarks: 0 },
    consents: [],
    recentActivity: [],
    ...over,
  }) as AdminUserDetail;

describe('compareTrend / weekOverWeek', () => {
  it('önceki 0 ise uydurma yüzde yok', () => {
    expect(compareTrend(5, 0)).toMatchObject({ dir: 'fromZero', pct: null });
    expect(compareTrend(0, 0).dir).toBe('none');
  });
  it('yüzde ve yön', () => {
    expect(compareTrend(120, 100)).toMatchObject({ dir: 'up', pct: 20 });
    expect(compareTrend(80, 100)).toMatchObject({ dir: 'down', pct: 20 });
    expect(compareTrend(7, 7).dir).toBe('same');
  });
  it('14 günden kısa seri karşılaştırılmaz; son 7 gün öncekiyle kıyaslanır', () => {
    expect(weekOverWeek([1, 2, 3])).toBeNull();
    const series = [...Array(7).fill(1), ...Array(7).fill(2)];
    expect(weekOverWeek(series)).toMatchObject({ now: 14, prev: 7, dir: 'up', pct: 100 });
  });
});

describe('kırılım dönüşümleri', () => {
  const b = (items: BreakdownResponse['items']): BreakdownResponse => ({ dimension: 'status', total: 0, items });
  it('durum: sıra sabit, sıfırlar ve bilinmeyenler atılır', () => {
    const r = statusSlices(b([{ key: 'DELETED', label: '', count: 3, percent: 0 }, { key: 'ACTIVE', label: '', count: 10, percent: 0 }, { key: 'X', label: '', count: 9, percent: 0 }]));
    expect(r.map((s) => s.key)).toEqual(['ACTIVE', 'DELETED']);
    expect(statusSlices(undefined)).toEqual([]);
  });
  it('fakülte: boş/unknown ayrı sayılır, büyükten küçüğe', () => {
    const r = facultyRows(b([{ key: 'a', label: 'A', count: 1, percent: 0 }, { key: 'unknown', label: '', count: 7, percent: 0 }, { key: 'b', label: 'B', count: 4, percent: 0 }]));
    expect(r.rows.map((x) => x.label)).toEqual(['B', 'A']);
    expect(r.unset).toBe(7);
  });
});

describe('attentionItems', () => {
  it('sıfır/bilinmeyen gösterilmez; önem sırası askı, korumasız yönetici, doğrulamayan', () => {
    expect(attentionItems({ suspended: 0, unverified: undefined, adminsNo2fa: undefined })).toEqual([]);
    expect(attentionItems({ suspended: 2, unverified: 9, adminsNo2fa: 1 }).map((a) => a.kind)).toEqual(['suspended', 'adminNo2fa', 'unverified']);
  });
});

describe('computeRisk', () => {
  it('temiz hesap', () => {
    expect(computeRisk(detail(), NOW)).toEqual({ level: 'clean', factors: [] });
  });
  it('askıdaki hesap yüksek risk', () => {
    expect(computeRisk(detail({ status: 'SUSPENDED' }), NOW).level).toBe('high');
  });
  it('doğrulanmamış e-posta orta; yönetici + 2FA kapalı orta ve güvenlik sekmesine yönlendirir', () => {
    expect(computeRisk(detail({ emailVerified: false }), NOW).level).toBe('medium');
    const r = computeRisk(detail({ role: 'ADMIN', twoFactorEnabled: false }), NOW);
    expect(r.factors[0]).toMatchObject({ id: 'adminNo2fa', goto: 'security' });
  });
  it('3 ve üstü açık şikâyet yüksek; yalnız açık olanlar sayılır', () => {
    const rep = (id: number, status: string) => ({ id, targetType: 'USER', targetId: 3, reason: 'X', status, createdAt: ago(1) });
    const x = {
      reportsAgainst: [rep(1, 'OPEN'), rep(2, 'OPEN'), rep(3, 'OPEN'), rep(4, 'RESOLVED')],
    } as unknown as AdminUserDetail['extras'];
    const r = computeRisk(detail({ extras: x }), NOW);
    expect(r.level).toBe('high');
    expect(r.factors[0]).toMatchObject({ id: 'reportsMany', n: 3 });
  });
  it('hiç girmeyen ve uzun süre girmeyen düşük risk; silinmiş hesap değerlendirilmez', () => {
    expect(computeRisk(detail({ lastSeenAt: null }), NOW).level).toBe('low');
    expect(computeRisk(detail({ lastSeenAt: ago(90) }), NOW).factors[0]).toMatchObject({ id: 'dormant', n: 90 });
    expect(computeRisk(detail({ status: 'DELETED', emailVerified: false }), NOW).level).toBe('deleted');
  });
});

describe('buildTimeline', () => {
  it('en yeni üstte; tarihsiz ve geçersiz kayıtlar atılır', () => {
    const u = detail({
      createdAt: ago(40),
      lastSeenAt: ago(1),
      twoFactorEnabledAt: ago(10),
      consents: [{ type: 'TERMS', version: 2, acceptedAt: ago(39) }],
      extras: {
        devices: [{ platform: 'android', registeredAt: ago(20) }, { platform: 'ios', registeredAt: 'bozuk' }],
        communities: [{ id: 1, name: 'Robotik', role: 'MEMBER', status: 'ACTIVE', joinedAt: null }],
        tickets: [{ id: 5, category: 'X', subject: 'Şifre', status: 'OPEN', createdAt: ago(5) }],
        feedback: [],
        reportsAgainst: [],
        reportsFiled: [],
        eventsCreated: [],
        eventsAttending: [],
      } as unknown as AdminUserDetail['extras'],
    });
    const ev = buildTimeline(u, (t) => t);
    expect(ev.map((e) => e.kind)).toEqual(['lastSeen', 'ticket', 'twoFactor', 'device', 'consent', 'joined']);
    expect(ev[1].params.subject).toBe('Şifre');
  });
  it('silinme tarihi eklenir', () => {
    expect(buildTimeline(detail({ deletedAt: ago(0.5) }), (t) => t)[0].kind).toBe('deleted');
  });
});

describe('weeklyEnablements', () => {
  it('8 haftalık dilim, en yeni sağda; pencere dışı ve gelecekteki kayıtlar sayılmaz', () => {
    const rows = [
      { enabledAt: ago(0.1) },
      { enabledAt: ago(3) },
      { enabledAt: ago(8) },
      { enabledAt: ago(40) },
      { enabledAt: ago(200) },
      { enabledAt: null },
      { enabledAt: new Date(NOW + 3 * DAY).toISOString() },
    ];
    const b = weeklyEnablements(rows, 8, NOW);
    expect(b).toHaveLength(8);
    expect(b[7].count).toBe(2); // son 7 gün
    expect(b[6].count).toBe(1); // önceki hafta
    expect(b.reduce((s, x) => s + x.count, 0)).toBe(4); // 40 gün önce de pencerede (56 gün)
  });
});
