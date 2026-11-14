// Canlı oturum yoklaması: GET /academician/sessions/{id}/live her 2,5 sn (kapalıyken 5 sn). Sekme gizliyken yoklama DURUR, görünür
// olunca HEMEN yeniden başlar; bileşen kalkınca durur (süren istek iptal edilir). Her yanıtta: kod penceresi + sunucu saat farkı +
// sayaçlar + yoklama satırları (sunucu oturumun TÜM satırlarını verir; kimliğe göre birleştirilir, `revoked` bayrağı korunur) +
// "kayıtlı değil" listesi. Yeni gelenler (ilk yüklemeden sonra) `onArrival` ile bildirilir.
import { useCallback, useEffect, useRef, useState } from 'react';
import { getLive, type AttendanceRecord, type LiveCode, type LiveView, type PendingScan } from '../../../api/academician';
import { isApiError } from '../../../api/client';
import { POLL_CLOSED_MS, POLL_OPEN_MS, clockOffset, mergeCodes } from './liveCode';

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
  /** Son yoklama hatası (başarılı yanıtla temizlenir). */
  error: unknown;
  /** 404: oturum yok ya da başkasının. */
  notFound: boolean;
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
  notFound: false,
};

export function useLiveSession(sessionId: number, onArrival?: (r: AttendanceRecord) => void) {
  const [state, setState] = useState<LiveState>(INITIAL);
  const refreshRef = useRef<() => void>(() => undefined);
  const arrival = useRef(onArrival);
  arrival.current = onArrival;

  useEffect(() => {
    if (!Number.isFinite(sessionId)) return;
    let stopped = false;
    let timer: ReturnType<typeof setTimeout> | undefined;
    let inflight = false;
    let interval = POLL_OPEN_MS;
    const ac = new AbortController();
    const known = new Map<number, AttendanceRecord>(); // studentId -> kayıt
    let first = true;

    const schedule = () => {
      clearTimeout(timer);
      if (!stopped && !document.hidden) timer = setTimeout(() => void tick(), interval);
    };

    const apply = (v: LiveView, receivedLocal: number) => {
      interval = v.status === 'OPEN' ? POLL_OPEN_MS : POLL_CLOSED_MS;
      const offsetMs = clockOffset(v.serverNowMs, receivedLocal);
      for (const r of v.newRecords) {
        const prev = known.get(r.studentId);
        // ilk yüklemeden sonra yoklamaya GİREN (yeni ya da geri yüklenen) öğrenci: duyuru için bildirilir
        if (!first && !r.revoked && (!prev || prev.revoked)) arrival.current?.(r);
        known.set(r.studentId, r);
      }
      first = false;
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
        notFound: false,
      }));
    };

    async function tick() {
      if (stopped || inflight || document.hidden) return;
      inflight = true;
      const t0 = Date.now();
      try {
        const v = await getLive(sessionId, ac.signal);
        if (stopped) return;
        // yanıt yerel alınma anı: istek orta noktası (gidiş-dönüş gecikmesinin yarısı hesaba katılır)
        apply(v, (t0 + Date.now()) / 2);
      } catch (e) {
        if (stopped || (e instanceof DOMException && e.name === 'AbortError')) return;
        setState((s) => ({ ...s, error: e, notFound: isApiError(e) && e.status === 404 }));
        if (isApiError(e) && e.status === 404) {
          stopped = true;
          return;
        }
      } finally {
        inflight = false;
        schedule();
      }
    }

    const onVisibility = () => {
      if (document.hidden) {
        clearTimeout(timer); // gizliyken yoklama yok
      } else if (!inflight) {
        clearTimeout(timer);
        void tick(); // görünür olunca hemen
      }
    };
    refreshRef.current = () => {
      if (!inflight && !document.hidden) {
        clearTimeout(timer);
        void tick();
      }
    };
    document.addEventListener('visibilitychange', onVisibility);
    void tick();
    return () => {
      stopped = true;
      ac.abort();
      clearTimeout(timer);
      document.removeEventListener('visibilitychange', onVisibility);
    };
  }, [sessionId]);

  /** Eylemden (kapat, var say, kabul...) sonra bir sonraki yoklamayı beklemeden hemen çek. */
  const refresh = useCallback(() => refreshRef.current(), []);
  return { ...state, refresh };
}
