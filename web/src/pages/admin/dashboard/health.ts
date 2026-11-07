// Genel bakış: "şu an her şey yolunda mı?" kararı (saf işlev; test: transform.test.ts).
import { levelOf, type SystemOverview } from '../../../api/system';

export type HealthTone = 'good' | 'warn' | 'bad';

export interface HealthIssue {
  /** Sistem göstergesi anahtarı ("db", "mail.dead") ya da "source:NEWS". */
  id: string;
  kind: 'system' | 'source';
  level: 'WARN' | 'CRIT';
}

export interface HealthSummary {
  tone: HealthTone;
  issues: HealthIssue[];
  /** Sistem göstergeleri okunabildi mi (yetki yok ya da hata: bilinmiyor). */
  systemKnown: boolean;
}

/**
 * Sistem göstergeleri (varsa) ve kaynak bakım durumundan en kötü seviyeyi çıkarır. Önce kritik, sonra uyarı sıralanır.
 * UNKNOWN göstergeler sorun sayılmaz (ölçülemeyen şey için alarm vermeyiz); bilinmeyen genel durum "okunamadı" olarak ayrıca belirtilir.
 */
export function summarizeHealth(
  system: SystemOverview | undefined,
  sources: Record<string, { maintenance: boolean }> | undefined,
): HealthSummary {
  const issues: HealthIssue[] = [];
  if (system) {
    for (const [id, ind] of Object.entries(system.indicators ?? {})) {
      const level = levelOf(ind?.status);
      if (level === 'CRIT' || level === 'WARN') issues.push({ id, kind: 'system', level });
    }
  }
  if (sources) {
    for (const [name, s] of Object.entries(sources)) {
      if (s?.maintenance) issues.push({ id: `source:${name}`, kind: 'source', level: 'WARN' });
    }
  }
  issues.sort((a, b) => (a.level === b.level ? 0 : a.level === 'CRIT' ? -1 : 1));
  const tone: HealthTone = issues.some((i) => i.level === 'CRIT') ? 'bad' : issues.length > 0 ? 'warn' : 'good';
  return { tone, issues, systemKnown: !!system };
}
