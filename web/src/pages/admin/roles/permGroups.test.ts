import { describe, expect, it } from 'vitest';
import type { AdminProfile, MatrixEntry } from '../../../api/rbac';
import { buildGroupRows, groupOf, levelOf, narrowestProfile, profileCoverage } from './permGroups';

const P: AdminProfile[] = ['FULL', 'MODERATOR', 'VIEWER'];
const entries: MatrixEntry[] = [
  { permission: 'users.read', profiles: ['FULL', 'MODERATOR', 'VIEWER'] },
  { permission: 'users.role', profiles: ['FULL'] },
  { permission: 'users.pii', profiles: ['FULL', 'MODERATOR'] },
  { permission: 'chat.read', profiles: ['FULL', 'MODERATOR'] },
  { permission: 'data.retention.purge', profiles: ['FULL'] },
];

describe('izin grupları', () => {
  it('izni ilk parçasına göre alana koyar', () => {
    expect(groupOf('users.pii')).toBe('users');
    expect(groupOf('data.retention.purge')).toBe('data');
    expect(groupOf('admin.full')).toBe('admin');
  });

  it('kademe: hiç, az, yarı, çok, tamamı', () => {
    expect(levelOf(0, 4)).toBe(0);
    expect(levelOf(1, 4)).toBe(1);
    expect(levelOf(2, 4)).toBe(2);
    expect(levelOf(3, 4)).toBe(3);
    expect(levelOf(1, 3)).toBe(1);
    expect(levelOf(2, 3)).toBe(2);
    expect(levelOf(4, 4)).toBe(4);
    expect(levelOf(0, 0)).toBe(0);
  });

  it('ısı haritası satırları: profil başına verilen/toplam ve eksik izinler', () => {
    const rows = buildGroupRows(entries, P);
    expect(rows.map((r) => r.group)).toEqual(['users', 'chat', 'data']);
    const users = rows[0];
    expect(users.total).toBe(3);
    const mod = users.cells.find((c) => c.profile === 'MODERATOR')!;
    expect(mod.granted).toBe(2);
    expect(mod.missing).toEqual(['users.role']);
    expect(mod.level).toBe(2); // 2/3: "yarı" kademesi
    const viewer = users.cells.find((c) => c.profile === 'VIEWER')!;
    expect(viewer.granted).toBe(1);
    expect(viewer.level).toBe(1);
    expect(rows[2].cells.find((c) => c.profile === 'VIEWER')!.level).toBe(0);
    expect(users.cells.find((c) => c.profile === 'FULL')!.level).toBe(4);
  });

  it('profil kapsamı ve en dar profil (FULL hariç)', () => {
    const cov = profileCoverage(entries, P);
    expect(cov.find((c) => c.profile === 'FULL')!.percent).toBe(100);
    expect(cov.find((c) => c.profile === 'MODERATOR')!.granted).toBe(3);
    const narrow = narrowestProfile(cov)!;
    expect(narrow.profile).toBe('VIEWER');
    expect(narrow.granted).toBe(1);
    expect(narrow.percent).toBe(20);
    expect(narrowestProfile([])).toBeNull();
  });
});
