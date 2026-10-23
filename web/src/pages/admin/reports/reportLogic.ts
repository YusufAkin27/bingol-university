import type { ReportResolution, ReportView, ResolveReportRequest } from '../../../api/types';

export const RESOLUTIONS: ReportResolution[] = ['DISMISS', 'HIDE', 'WARN', 'SUSPEND_USER'];
export const MAX_MESSAGE = 300;

export type DecisionError = 'reasonRequired' | 'tooLong';

/** Karar formu doğrulaması: askıya almada neden zorunlu; mesaj en çok 300 karakter. */
export function validateDecision(action: ReportResolution, message: string): DecisionError | null {
  const m = message.trim();
  if (action === 'SUSPEND_USER' && m === '') return 'reasonRequired';
  if (m.length > MAX_MESSAGE) return 'tooLong';
  return null;
}

/** Yalnızca mesajı kullanan kararlarda (WARN, SUSPEND_USER) mesaj gönderilir. */
export function buildResolveRequest(action: ReportResolution, message: string): ResolveReportRequest {
  const m = message.trim();
  return action === 'WARN' || action === 'SUSPEND_USER'
    ? { action, ...(m ? { message: m } : {}) }
    : { action };
}

/** Aynı hedefe yüklü listede kaç rapor var. */
export function countByTarget(items: ReportView[]): Map<string, number> {
  const map = new Map<string, number>();
  for (const r of items) {
    const k = `${r.targetType}:${r.targetId}`;
    map.set(k, (map.get(k) ?? 0) + 1);
  }
  return map;
}

export const targetKey = (r: Pick<ReportView, 'targetType' | 'targetId'>) => `${r.targetType}:${r.targetId}`;

/** j/k gezinme: sınırda durur; liste boşsa -1. */
export function moveSelection(index: number, delta: 1 | -1, length: number): number {
  if (length === 0) return -1;
  if (index < 0) return delta === 1 ? 0 : length - 1;
  return Math.min(length - 1, Math.max(0, index + delta));
}
