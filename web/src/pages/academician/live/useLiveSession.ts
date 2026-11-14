// Canlı oturum yoklaması: GET /academician/sessions/{id}/live her 2,5 sn (kapalıyken 5 sn). Sekme gizliyken yoklama DURUR; görünür
// olunca ya da ağ geri gelince (online) eski istek iptal edilip HEMEN yeniden başlar; bileşen kalkınca durur.
// Dayanıklılık: her yoklamanın 5 sn zaman aşımı vardır (takılan istek yeni turu engellemez); eski/geç gelen yanıt (sıra numarası)
// yeni yanıtın üstüne yazılmaz; hata olunca üstel geri çekilme (429'da Retry-After); kalıcı hata `error` ile gösterilir.
// Her yanıtta: kod penceresi + sunucu saat farkı + sayaçlar + yoklama satırları (sunucu oturumun TÜM satırlarını verir; kimliğe göre
// birleştirilir, `revoked` korunur) + "kayıtlı değil" listesi. Yeni gelenler (ilk yüklemeden sonra) `onArrival` ile bildirilir.
import { useCallback, useEffect, useRef, useState } from 'react';
import { getLive, type AttendanceRecord, type LiveCode, type LiveView, type PendingScan } from '../../../api/academician';
import { isApiError } from '../../../api/client';
import { POLL_CLOSED_MS, POLL_OPEN_MS, clockOffset, mergeCodes } from './liveCode';

/** Tek yoklamanın en uzun süresi. */
export const POLL_TIMEOUT_MS = 5_000;
const BACKOFF_MAX_MS = 15_000;

export interface LiveState {
  status: 'OPEN' | 'CLOSED' | null;
  codes: LiveCode[];
  /** sunucu saati − yerel saat (ms) */
  offsetMs: number;
  /** son başarılı yanıtın yerel zamanı (ms); hiç yoksa null */
  lastFreshAt: number | null;
  presentCount: number;
  enrolledCount: number;
  records: AttendanceRecord[];
  pending: PendingScan[];
  /** Son yoklama hatası (başarılı yanıtla temizlenir). Zaman aşımı `TimeoutError` adlı Error'dır. */
  error: unknown;
  /** Art arda başarısız yoklama sayısı. */
  failures: number;
  /** 404: oturum yok ya da başkasının. */
  notFound: boolean;
  /** Oturum bu ekran açıkken OPEN iken CLOSED oldu (kapanışı bu sayfa yapmadıysa "başka yoklama/süre doldu" denir). */
  closedWhileWatching: boolean;
}

const INITIAL: LiveState = {
  status: null,
  codes: [],
  offsetMs: 0,
  lastFreshAt: null,
  presentCount: 0,
  enrolledCount: 0,
  records: [],
  pending: [],
  error: null,
  failures: 0,
  notFound: false,
  closedWhileWatching: false,
};

/** Bir hata sonrası bekleme süresi (ms). */
export function backoffMs(failures: number, e: unknown): number {
  if (isApiError(e) && e.status === 429) return Math.max(POLL_OPEN_MS, (e.retryAfter ?? 5) * 1000);
  return Math.min(BACKOFF_MAX_MS, POLL_OPEN_MS * 2 ** Math.max(0, failures - 1));
}

export function useLiveSession(sessionId: number, onArrival?: (r: AttendanceRecord) => void) {
  const [state, setState] = useState<LiveState>(INITIAL);
  const refreshRef = useRef<() => void>(() => undefined);
  const arrival = useRef(onArrival);
  arrival.current = onArrival;

  useEffect(() => {
    if (!Number.isFinite(sessionId)) return;
    let stopped = false;
    let timer: ReturnType<typeof setTimeout> | undefined;
    let interval = POLL_OPEN_MS;
    let failures = 0;
    let seq = 0; // başlatılan yoklama sayısı
    let applied = 0; // en son uygulanan yoklamanın sırası (geç/eski yanıt bunun altındaysa atılır)
    let current: { ac: AbortController; superseded: boolean } | null = null;
    const known = new Map<number, AttendanceRecord>(); // studentId -> kayıt
    let first = true;
    let lastStatus: 'OPEN' | 'CLOSED' | null = null;

    const schedule = (ms: number) => {
      clearTimeout(timer);
      if (!stopped && !document.hidden) timer = setTimeout(() => void tick(), ms);
    };

    const apply = (v: LiveView, receivedLocal: number) => {
      interval = v.status === 'OPEN' ? POLL_OPEN_MS : POLL_CLOSED_MS;
      failures = 0;
      const offsetMs = clockOffset(v.serverNowMs, receivedLocal);
      for (const r of v.newRecords) {
        const prev = known.get(r.studentId);
        // ilk yüklemeden sonra yoklamaya GİREN (yeni ya da geri yüklenen) öğrenci: duyuru için bildirilir
        if (!first && !r.revoked && (!prev || prev.revoked)) arrival.current?.(r);
        known.set(r.studentId, r);
      }
      first = false;
      const closedNow = lastStatus === 'OPEN' && v.status === 'CLOSED';
      lastStatus = v.status;
      setState((s) => ({
        status: v.status,
        codes: v.status === 'OPEN' ? mergeCodes(s.codes, v.codes, v.serverNowMs) : [],
        offsetMs,
        lastFreshAt: receivedLocal,
        presentCount: v.presentCount,
        enrolledCount: v.enrolledCount,
        records: [...known.values()],
        pending: v.pendingScans ?? [],
        error: null,
        failures: 0,
        notFound: false,
        closedWhileWatching: v.status === 'CLOSED' ? s.closedWhileWatching || closedNow : false,
      }));
    };

    async function tick() {
      if (stopped || document.hidden) return;
      // takılı eski istek varsa iptal et (yenisi onun yerini alır)
      if (current) {
        current.superseded = true;
        current.ac.abort();
      }
      const mine = { ac: new AbortController(), superseded: false };
      current = mine;
      const my = ++seq;
      let timedOut = false;
      const to = setTimeout(() => {
        timedOut = true;
        mine.ac.abort();
      }, POLL_TIMEOUT_MS);
      const t0 = Date.now();
      try {
        const v = await getLive(sessionId, mine.ac.signal);
        if (stopped || mine.superseded || my < applied) return; // eski/geç yanıt
        applied = my;
        apply(v, (t0 + Date.now()) / 2);
        schedule(interval);
      } catch (e) {
        if (stopped || mine.superseded) return;
        const err: unknown = timedOut ? Object.assign(new Error('poll timeout'), { name: 'TimeoutError' }) : e;
        if (!timedOut && e instanceof DOMException && e.name === 'AbortError') return;
        failures += 1;
        const notFound = isApiError(err) && err.status === 404;
        setState((s) => ({ ...s, error: err, failures, notFound }));
        if (notFound) {
          stopped = true;
          return;
        }
        schedule(backoffMs(failures, err));
      } finally {
        clearTimeout(to);
        if (current === mine) current = null;
      }
    }

    /** Görünür olma / ağ geri geldi: eski isteği iptal et, hemen yoklama. */
    const wake = () => {
      if (document.hidden || stopped) return;
      clearTimeout(timer);
      void tick();
    };
    const onVisibility = () => {
      if (document.hidden) {
        clearTimeout(timer); // gizliyken yeni yoklama yok
        if (current) {
          current.superseded = true;
          current.ac.abort();
          current = null;
        }
      } else wake();
    };
    refreshRef.current = wake;
    document.addEventListener('visibilitychange', onVisibility);
    window.addEventListener('online', wake);
    void tick();
    return () => {
      stopped = true; // süren istek iptal EDİLMEZ (sonucu yok sayılır; en çok 5 sn zaman aşımı): sayfa değişiminde ağ hatası gürültüsü olmasın
      clearTimeout(timer);
      document.removeEventListener('visibilitychange', onVisibility);
      window.removeEventListener('online', wake);
    };
  }, [sessionId]);

  /** Eylemden (kapat, var say, kabul...) sonra bir sonraki yoklamayı beklemeden hemen çek. */
  const refresh = useCallback(() => refreshRef.current(), []);
  return { ...state, refresh };
}
