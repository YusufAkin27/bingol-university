// Yedekleme durumu (GD1): GET /api/admin/system/backup (izin: system.read). Sözleşme (backend ayrı dalda yazılır):
// tarihler ISO UTC, bilinmeyen alan null. Uç henüz yoksa (404/501) sayfa kurulum rehberini yine gösterir.
// Sayfa hiçbir sır toplamaz: yalnız durum okur.
import { api } from './client';

export interface BackupLocal {
  count: number | null;
  bytes: number | null;
  oldestAt: string | null;
}

export interface BackupRemote {
  configured: boolean;
  /** Uzak türü (ör. "drive", "s3"); bilinmiyorsa null. */
  kind: string | null;
  name: string | null;
  lastSuccessAt: string | null;
  lastVerifiedAt: string | null;
  lastError: string | null;
  bytes: number | null;
  count: number | null;
}

export interface BackupRetention {
  localDaily: number | null;
  localWeekly: number | null;
  localMonthly: number | null;
  remoteDaily: number | null;
  remoteWeekly: number | null;
  remoteMonthly: number | null;
}

export interface BackupStatus {
  local: BackupLocal | null;
  remote: BackupRemote | null;
  lastSuccessAt: string | null;
  lastStatus: string | null;
  schedule: { cron: string | null; verifyCron: string | null } | null;
  retention: BackupRetention | null;
}

export const backupKeys = {
  all: ['admin', 'backup'] as const,
  status: ['admin', 'backup', 'status'] as const,
};

export const getBackupStatus = () => api.get<BackupStatus>('/admin/system/backup');
