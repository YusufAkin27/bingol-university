// Yanıt kutusunun ek yükleme durumu: seçilen dosyaları ön kontrolden geçirir, ilerlemeyle yükler, kaldırmayı/yeniden denemeyi yönetir.
import { useCallback, useEffect, useRef, useState } from 'react';
import type { UploadOptions } from '../../../api/client';
import type { AttachmentView } from '../../../api/types';
import { screenFiles, type AttachmentProblem, type UploadItem } from './attachmentLogic';

export interface UploadDeps {
  upload: (file: File, o: UploadOptions) => Promise<AttachmentView>;
  /** Sunucu/ağ hatasını kullanıcı metnine çevirir. */
  errorText: (e: unknown) => string;
  /** Ön kontrol reddini kullanıcı metnine çevirir. */
  problemText: (file: File, problem: AttachmentProblem) => string;
}

export function useAttachmentUploads(deps: UploadDeps) {
  const [items, setItems] = useState<UploadItem[]>([]);
  const [problems, setProblems] = useState<string[]>([]);
  const itemsRef = useRef<UploadItem[]>([]);
  itemsRef.current = items;
  const aborts = useRef(new Map<string, AbortController>());
  const seq = useRef(0);
  const depsRef = useRef(deps);
  depsRef.current = deps;

  useEffect(() => {
    const map = aborts.current;
    return () => {
      map.forEach((c) => c.abort());
      map.clear();
    };
  }, []);

  const patch = useCallback((key: string, p: Partial<UploadItem>) => {
    setItems((cur) => cur.map((i) => (i.key === key ? { ...i, ...p } : i)));
  }, []);

  const start = useCallback(
    (key: string, file: File) => {
      const ctl = new AbortController();
      aborts.current.set(key, ctl);
      patch(key, { status: 'uploading', progress: 0, error: undefined });
      depsRef.current
        .upload(file, { signal: ctl.signal, onProgress: (f) => patch(key, { progress: f }) })
        .then((attachment) => patch(key, { status: 'done', progress: 1, attachment }))
        .catch((e: unknown) => {
          if (e instanceof DOMException && e.name === 'AbortError') return;
          patch(key, { status: 'error', error: depsRef.current.errorText(e) });
        })
        .finally(() => aborts.current.delete(key));
    },
    [patch],
  );

  const add = useCallback(
    (files: File[]) => {
      const { accepted, rejected } = screenFiles(
        files,
        itemsRef.current.map((i) => i.kind),
      );
      setProblems(rejected.map((r) => depsRef.current.problemText(r.file, r.problem)));
      if (accepted.length === 0) return;
      const fresh: UploadItem[] = accepted.map((c) => ({
        key: `u${(seq.current += 1)}`,
        file: c.file,
        kind: c.kind,
        status: 'uploading',
        progress: 0,
      }));
      itemsRef.current = [...itemsRef.current, ...fresh];
      setItems(itemsRef.current);
      fresh.forEach((f) => start(f.key, f.file));
    },
    [start],
  );

  const remove = useCallback((key: string) => {
    aborts.current.get(key)?.abort();
    aborts.current.delete(key);
    setItems((cur) => cur.filter((i) => i.key !== key));
    setProblems([]);
  }, []);

  const retry = useCallback(
    (key: string) => {
      const it = itemsRef.current.find((i) => i.key === key);
      if (it) start(key, it.file);
    },
    [start],
  );

  /** Gönderim sonrası: yüklenenler yanıta bağlandı, listeyi boşalt. */
  const reset = useCallback(() => {
    aborts.current.forEach((c) => c.abort());
    aborts.current.clear();
    itemsRef.current = [];
    setItems([]);
    setProblems([]);
  }, []);

  return { items, problems, setProblems, add, remove, retry, reset };
}
