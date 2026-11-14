// Duyuru dosya alanı: sürükle-bırak + dosya seçici, en çok 5 dosya / dosya başına 20 MB, yerel ön kontrol (uzantı, boyut, sayı),
// dosya başına yükleme ilerlemesi ve hatası. Yükleme eklenir eklenmez başlar (POST /academician/courses/{id}/notice-files,
// çağrı başına tek dosya); dönen kimlikler duyuru oluşturulurken `fileIds` ile bağlanır. Listeden çıkarılan dosya sunucuda da silinir
// (DELETE /academician/notice-files/{id}); bağlanmayan yüklemeleri sunucu 24 saatte temizler.
import { useCallback, useEffect, useRef, useState, type DragEvent } from 'react';
import { deletePendingFile, uploadNoticeFile } from '../../../api/academician';
import { Button, Icon, ProgressBar } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { useT, type T } from '../dict';
import { acadError } from '../errors';
import { fmtSize } from '../format';
import styles from '../academician.module.css';
import { ACCEPT_ATTR, MAX_FILES, MAX_FILE_BYTES, checkFile, type FileCheck } from './noticeRules';

export interface QueuedFile {
  id: string;
  file: File;
  status: 'uploading' | 'done' | 'error';
  /** 0..1 */
  progress: number;
  error?: string;
  serverId?: number;
  /** Yerel ön kontrolden geçemedi (hiç yüklenmedi). */
  rejected?: boolean;
}

let seq = 0;
const FILE_ERR: Record<FileCheck, string> = {
  type: 'ac.files.err.type',
  size: 'ac.files.err.size',
  limit: 'ac.files.err.limit',
  empty: 'ac.files.err.empty',
};

export function fileCheckMessage(t: T, c: FileCheck): string {
  return t(FILE_ERR[c], { max: MAX_FILES, mb: MAX_FILE_BYTES / (1024 * 1024) });
}

export function useNoticeFiles(courseId: number) {
  const i18n = useI18n();
  const t = useT();
  const [files, setFiles] = useState<QueuedFile[]>([]);
  const aborts = useRef(new Map<string, AbortController>());
  const filesRef = useRef(files);
  filesRef.current = files;

  const patch = useCallback((id: string, p: Partial<QueuedFile>) => setFiles((fs) => fs.map((f) => (f.id === id ? { ...f, ...p } : f))), []);

  const start = useCallback(
    (q: QueuedFile) => {
      const ac = new AbortController();
      aborts.current.set(q.id, ac);
      patch(q.id, { status: 'uploading', progress: 0, error: undefined });
      uploadNoticeFile(courseId, q.file, (p) => patch(q.id, { progress: p }), ac.signal)
        .then((r) => patch(q.id, { status: 'done', progress: 1, serverId: r.id }))
        .catch((e: unknown) => {
          if (e instanceof DOMException && e.name === 'AbortError') return;
          patch(q.id, { status: 'error', error: acadError(i18n, e) });
        })
        .finally(() => aborts.current.delete(q.id));
    },
    [courseId, i18n, patch],
  );

  const add = useCallback(
    (list: FileList | File[]) => {
      const incoming = Array.from(list);
      let count = filesRef.current.filter((f) => !f.rejected).length;
      const next: QueuedFile[] = [];
      for (const file of incoming) {
        const bad = checkFile(file, count);
        const q: QueuedFile = { id: `f${++seq}`, file, status: bad ? 'error' : 'uploading', progress: 0, rejected: bad ? true : undefined, error: bad ? fileCheckMessage(t, bad) : undefined };
        if (!bad) count++;
        next.push(q);
      }
      setFiles((fs) => [...fs, ...next]);
      // yükleme state yerleştikten sonra başlar
      queueMicrotask(() => next.filter((q) => !q.rejected).forEach(start));
    },
    [start, t],
  );

  const remove = useCallback((id: string) => {
    const f = filesRef.current.find((x) => x.id === id);
    aborts.current.get(id)?.abort();
    aborts.current.delete(id);
    setFiles((fs) => fs.filter((x) => x.id !== id));
    if (f?.serverId !== undefined) void deletePendingFile(f.serverId).catch(() => undefined);
  }, []);

  const retry = useCallback(
    (id: string) => {
      const f = filesRef.current.find((x) => x.id === id);
      if (f && !f.rejected) start(f);
    },
    [start],
  );

  /** Duyuru oluşturulunca: dosyalar sunucuda duyuruya bağlandı; yerel listeyi sil (sunucuda silme YOK). */
  const clearAttached = useCallback(() => setFiles([]), []);
  /** Duyuru türü dosyaya izin vermiyorsa: bekleyen yüklemeleri sunucudan da sil. */
  const discardAll = useCallback(() => {
    filesRef.current.forEach((f) => {
      aborts.current.get(f.id)?.abort();
      if (f.serverId !== undefined) void deletePendingFile(f.serverId).catch(() => undefined);
    });
    aborts.current.clear();
    setFiles([]);
  }, []);

  // sayfadan ayrılınca süren yüklemeleri durdur
  useEffect(() => {
    const m = aborts.current;
    return () => m.forEach((a) => a.abort());
  }, []);

  const uploading = files.some((f) => f.status === 'uploading');
  const failed = files.some((f) => f.status === 'error');
  const serverIds = files.filter((f) => f.status === 'done' && f.serverId !== undefined).map((f) => f.serverId!);
  return { files, add, remove, retry, clearAttached, discardAll, uploading, failed, serverIds };
}

export function NoticeFilesField({ state, disabled }: { state: ReturnType<typeof useNoticeFiles>; disabled?: boolean }) {
  const t = useT();
  const input = useRef<HTMLInputElement>(null);
  const [over, setOver] = useState(false);
  const { files, add, remove, retry } = state;

  function onDrop(e: DragEvent) {
    e.preventDefault();
    setOver(false);
    if (disabled) return;
    if (e.dataTransfer.files.length) add(e.dataTransfer.files);
  }

  return (
    <div className={styles.filesField}>
      <span className={styles.fieldLabel} id="notice-files-label">
        {t('ac.files.label')}
      </span>
      <div
        className={styles.dropzone}
        data-over={over || undefined}
        role="group"
        aria-labelledby="notice-files-label"
        onDragOver={(e) => {
          e.preventDefault();
          if (!disabled) setOver(true);
        }}
        onDragLeave={() => setOver(false)}
        onDrop={onDrop}
      >
        <Icon name="file" size={22} aria-hidden="true" />
        <p>{t('ac.files.drop')}</p>
        <Button type="button" variant="secondary" size="sm" disabled={disabled || files.filter((f) => !f.rejected).length >= MAX_FILES} onClick={() => input.current?.click()}>
          {t('ac.files.pick')}
        </Button>
        <input
          ref={input}
          type="file"
          multiple
          hidden
          accept={ACCEPT_ATTR}
          aria-label={t('ac.files.pick')}
          onChange={(e) => {
            if (e.target.files?.length) add(e.target.files);
            e.target.value = '';
          }}
        />
        <p className={styles.muted}>{t('ac.files.rules', { max: MAX_FILES, mb: MAX_FILE_BYTES / (1024 * 1024) })}</p>
      </div>
      {files.length > 0 && (
        <ul className={styles.fileList} aria-label={t('ac.files.listAria')}>
          {files.map((f) => (
            <li key={f.id} className={styles.fileItem} data-state={f.status}>
              <div className={styles.fileMain}>
                <span className={styles.rowTitle}>{f.file.name}</span>
                <span className={styles.muted}>{fmtSize(f.file.size)}</span>
                {f.status === 'uploading' && <ProgressBar value={Math.round(f.progress * 100)} label={t('ac.files.uploading', { name: f.file.name })} tone="neutral" showLabel />}
                {f.status === 'done' && (
                  <span className={styles.okText}>
                    <Icon name="check" size={14} aria-hidden="true" /> {t('ac.files.uploaded')}
                  </span>
                )}
                {f.status === 'error' && (
                  <span className={styles.errText} role="alert">
                    <Icon name="alert" size={14} aria-hidden="true" /> {f.error}
                  </span>
                )}
              </div>
              <div className={styles.rowActions}>
                {f.status === 'error' && !f.rejected && (
                  <Button type="button" size="sm" variant="secondary" onClick={() => retry(f.id)}>
                    {t('ac.retry')}
                  </Button>
                )}
                <Button type="button" size="sm" variant="ghost" onClick={() => remove(f.id)} aria-label={t('ac.files.removeAria', { name: f.file.name })}>
                  <Icon name="x" size={16} />
                </Button>
              </div>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
