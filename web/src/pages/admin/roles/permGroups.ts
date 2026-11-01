// Roller ve izinler: izin matrisini alanlara (kullanıcılar, moderasyon...) bölen saf mantık; ısı haritası bunu çizer.
import type { AdminProfile, MatrixEntry } from '../../../api/rbac';

/** İzin anahtarından alan: "users.pii" -> "users", "data.retention.purge" -> "data". */
export function groupOf(permission: string): string {
  return permission.split('.')[0] || 'other';
}

export interface GroupCell {
  profile: AdminProfile;
  granted: number;
  total: number;
  /** 0..1 */
  share: number;
  /** Görsel kademe: 0 hiç, 1 az, 2 yarıya yakın, 3 çoğu, 4 tamamı. */
  level: 0 | 1 | 2 | 3 | 4;
  /** Bu profilde OLMAYAN izinler (ipucu ve açıklama için). */
  missing: string[];
}

export interface GroupRow {
  group: string;
  total: number;
  permissions: string[];
  cells: GroupCell[];
}

export function levelOf(granted: number, total: number): GroupCell['level'] {
  if (total === 0 || granted === 0) return 0;
  if (granted >= total) return 4;
  const s = granted / total;
  // üçte bir ve üçte iki sınırları dahil alta düşer (1/3 az, 2/3 yarı)
  if (s > 0.67) return 3;
  if (s > 0.34) return 2;
  return 1;
}

/** Matris girdilerini alana göre gruplar; alan sırası ilk görünüş sırasıdır (backend sırası korunur). */
export function buildGroupRows(entries: readonly MatrixEntry[], profiles: readonly AdminProfile[]): GroupRow[] {
  const order: string[] = [];
  const by = new Map<string, MatrixEntry[]>();
  for (const e of entries) {
    const g = groupOf(e.permission);
    if (!by.has(g)) {
      by.set(g, []);
      order.push(g);
    }
    by.get(g)!.push(e);
  }
  return order.map((group) => {
    const list = by.get(group)!;
    return {
      group,
      total: list.length,
      permissions: list.map((e) => e.permission),
      cells: profiles.map((profile) => {
        const have = list.filter((e) => e.profiles.includes(profile));
        return {
          profile,
          granted: have.length,
          total: list.length,
          share: list.length ? have.length / list.length : 0,
          level: levelOf(have.length, list.length),
          missing: list.filter((e) => !e.profiles.includes(profile)).map((e) => e.permission),
        };
      }),
    };
  });
}

export interface ProfileCoverage {
  profile: AdminProfile;
  granted: number;
  total: number;
  percent: number;
}

/** Profil başına toplam izin kapsamı (alt satır ve özet cümlesi için). */
export function profileCoverage(entries: readonly MatrixEntry[], profiles: readonly AdminProfile[]): ProfileCoverage[] {
  const total = entries.length;
  return profiles.map((profile) => {
    const granted = entries.filter((e) => e.profiles.includes(profile)).length;
    return { profile, granted, total, percent: total ? Math.round((granted / total) * 100) : 0 };
  });
}

/** En dar profil (FULL hariç, en az izinli); eşitlikte listedeki sonraki. */
export function narrowestProfile(cov: readonly ProfileCoverage[]): ProfileCoverage | null {
  const rest = cov.filter((c) => c.profile !== 'FULL');
  if (rest.length === 0) return null;
  return rest.reduce((m, c) => (c.granted <= m.granted ? c : m));
}
