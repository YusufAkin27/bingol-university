import { useMutation, useQueryClient, type QueryKey } from '@tanstack/react-query';
import { useCallback, useRef } from 'react';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminError } from '../../../lib/errors';
import { useToast } from '../../ui/Toast';

/** `Idempotency-Key` başlığı için yeni anahtar (tarayıcıda crypto.randomUUID; yoksa rastgele yedek). */
export function newIdempotencyKey(): string {
  const c = (globalThis as { crypto?: Crypto }).crypto;
  if (c && typeof c.randomUUID === 'function') return c.randomUUID();
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (ch) => {
    const r = Math.floor(Math.random() * 16);
    return (ch === 'x' ? r : (r & 0x3) | 0x8).toString(16);
  });
}

/** `api.post(path, body, idempotencyHeaders(key))` biçiminde kullanılır. */
export function idempotencyHeaders(key: string): { headers: Record<string, string> } {
  return { headers: { 'Idempotency-Key': key } };
}

export interface GuardedContext {
  /** Bu onay diyaloğuna ait anahtar: aynı diyalogda yeniden denemede AYNI kalır, başarıdan sonra yenilenir. */
  idempotencyKey: string;
}

export type GuardedResult<TData> =
  | { ok: true; data: TData }
  | { ok: false; error?: unknown; /** true: önceki çağrı sürerken yok sayıldı. */ skipped?: boolean };

export interface UseGuardedMutationOptions<TData, TVars> {
  mutationFn: (vars: TVars, ctx: GuardedContext) => Promise<TData>;
  /** Başarı bildirimi; `false` sessiz. Varsayılan "İşlem tamamlandı." */
  successMessage?: string | false | ((data: TData, vars: TVars) => string);
  /** Hata bildirimi metni; varsayılan `adminError` (admin.err.* → common.error.*). */
  errorMessage?: (error: unknown) => string;
  /** Başarıdan sonra geçersiz kılınacak react-query anahtarları. */
  invalidateKeys?: QueryKey[];
  onSuccess?: (data: TData, vars: TVars) => void;
  onError?: (error: unknown, vars: TVars) => void;
}

/**
 * react-query `useMutation` sarmalayıcısı. Ayrıcalıklar:
 *  - İş sürerken ikinci `run` çağrısı YOK SAYILIR (senkron ref kilidi: çift tıklama, Enter + tıklama, çift tetikleme).
 *  - Onay diyaloğu başına bir `Idempotency-Key` (renewKey ile yenilenir, başarıdan sonra otomatik yenilenir).
 *  - Başarı/hata için tek tip toast; hata metni birleşik `adminError` ile üretilir.
 * `run` asla fırlatmaz; sonucu `GuardedResult` olarak döner.
 */
export function useGuardedMutation<TData, TVars = void>(opts: UseGuardedMutationOptions<TData, TVars>) {
  const { t, td } = useI18n();
  const toast = useToast();
  const qc = useQueryClient();
  const inFlight = useRef(false);
  const keyRef = useRef<string | null>(null);
  const optsRef = useRef(opts);
  optsRef.current = opts;

  const getKey = useCallback(() => (keyRef.current ??= newIdempotencyKey()), []);
  const renewKey = useCallback(() => {
    keyRef.current = newIdempotencyKey();
    return keyRef.current;
  }, []);

  const mutation = useMutation<TData, unknown, TVars>({
    mutationFn: (vars) => optsRef.current.mutationFn(vars, { idempotencyKey: getKey() }),
  });

  const { mutateAsync } = mutation;
  const run = useCallback(
    async (vars: TVars): Promise<GuardedResult<TData>> => {
      if (inFlight.current) return { ok: false, skipped: true };
      inFlight.current = true;
      const o = optsRef.current;
      try {
        const data = await mutateAsync(vars);
        renewKey();
        if (o.invalidateKeys) {
          await Promise.all(o.invalidateKeys.map((k) => qc.invalidateQueries({ queryKey: k })));
        }
        const sm = o.successMessage;
        if (sm !== false) {
          toast.success(typeof sm === 'function' ? sm(data, vars) : (sm ?? t('admin.guard.action.success')));
        }
        o.onSuccess?.(data, vars);
        return { ok: true, data };
      } catch (error) {
        toast.error(o.errorMessage ? o.errorMessage(error) : adminError({ t, td }, error));
        o.onError?.(error, vars);
        return { ok: false, error };
      } finally {
        inFlight.current = false;
      }
    },
    [mutateAsync, qc, toast, renewKey, t, td],
  );

  return {
    run,
    isPending: mutation.isPending,
    error: mutation.error,
    reset: mutation.reset,
    /** Geçerli diyalog anahtarı (okuma). */
    getIdempotencyKey: getKey,
    /** Yeni onay diyaloğu açılırken çağırın. */
    renewKey,
  };
}
