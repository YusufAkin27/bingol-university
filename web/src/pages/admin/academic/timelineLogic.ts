// Akademik takvim çizelgesi (Gantt benzeri) için saf mantık: pencere, çubuk yerleşimi, satır paketleme, yaklaşanlar.
// Tarihler "YYYY-MM-DD" anahtarlarıyla ve UTC gün numarasıyla işlenir; saat dilimi kayması olmaz (sunucu +03:00 verir,
// tarih kısmı zaten yerel gündür). Bitiş günü DAHİLDİR (tüm gün olayı "T23:59" ile biter).
import type { AcademicEvent, CalendarKind } from '../../../api/academic';

const DAY = 86_400_000;

/** "YYYY-MM-DD" (ya da ISO başı) -> UTC gün numarası; geçersizse NaN. */
export function dayNum(key: string): number {
  const y = Number(key.slice(0, 4));
  const m = Number(key.slice(5, 7));
  const d = Number(key.slice(8, 10));
  if (!Number.isFinite(y) || !Number.isFinite(m) || !Number.isFinite(d) || m < 1 || m > 12) return NaN;
  return Date.UTC(y, m - 1, d) / DAY;
}

const pad = (n: number) => String(n).padStart(2, '0');
export function keyOfDay(num: number): string {
  const d = new Date(num * DAY);
  return `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())}`;
}

export interface TimelineMonth {
  year: number;
  month0: number;
  /** Penceredeki gün sayısı ( ızgara sütun ağırlığı ). */
  days: number;
}

export interface TimelineWindow {
  startNum: number;
  /** Penceredeki toplam gün. */
  totalDays: number;
  months: TimelineMonth[];
  startKey: string;
  endKey: string;
}

/** `span` ay genişliğinde pencere; verilen ayın 1'inden başlar. */
export function timelineWindow(year: number, month0: number, span = 6): TimelineWindow {
  const months: TimelineMonth[] = [];
  let total = 0;
  for (let i = 0; i < span; i++) {
    const d = new Date(Date.UTC(year, month0 + i, 1));
    const days = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + 1, 0)).getUTCDate();
    months.push({ year: d.getUTCFullYear(), month0: d.getUTCMonth(), days });
    total += days;
  }
  const startNum = Date.UTC(year, month0, 1) / DAY;
  return { startNum, totalDays: total, months, startKey: keyOfDay(startNum), endKey: keyOfDay(startNum + total - 1) };
}

/** Pencereyi `delta` ay kaydırır (başlangıç ayı döner). */
export function shiftWindowStart(year: number, month0: number, delta: number): { year: number; month0: number } {
  const d = new Date(Date.UTC(year, month0 + delta, 1));
  return { year: d.getUTCFullYear(), month0: d.getUTCMonth() };
}

/** Olayın ilk ve son günü (son gün dahil); bitiş yok ya da başlangıçtan önceyse tek gün. */
export function eventSpan(ev: Pick<AcademicEvent, 'startsAt' | 'endsAt'>): { start: number; end: number } | null {
  const start = dayNum(ev.startsAt);
  if (Number.isNaN(start)) return null;
  const end = ev.endsAt ? dayNum(ev.endsAt) : start;
  return { start, end: Number.isNaN(end) || end < start ? start : end };
}

export interface PlacedEvent {
  ev: AcademicEvent;
  /** Pencereye kırpılmış çubuğun başlangıcı ve genişliği (yüzde). */
  leftPct: number;
  widthPct: number;
  /** Olay pencereden önce başlıyor / sonra bitiyor. */
  clippedStart: boolean;
  clippedEnd: boolean;
  startNum: number;
  endNum: number;
}

/** Olayı pencereye yerleştirir; pencereyle hiç kesişmiyorsa null. En az 1 günlük genişlik verilir. */
export function placeEvent(ev: AcademicEvent, win: TimelineWindow): PlacedEvent | null {
  const span = eventSpan(ev);
  if (!span) return null;
  const winEnd = win.startNum + win.totalDays - 1;
  if (span.end < win.startNum || span.start > winEnd) return null;
  const from = Math.max(span.start, win.startNum);
  const to = Math.min(span.end, winEnd);
  return {
    ev,
    leftPct: ((from - win.startNum) / win.totalDays) * 100,
    widthPct: ((to - from + 1) / win.totalDays) * 100,
    clippedStart: span.start < win.startNum,
    clippedEnd: span.end > winEnd,
    startNum: span.start,
    endNum: span.end,
  };
}

/** Yazı için ayrılan en az genişlik (yüzde): dar çubuğun başlığı sığsın diye paketlemede bu kadar yer tutulur. */
export const MIN_LABEL_PCT = 22;

export interface BoxLayout {
  /** Tıklanabilir kutunun başlangıcı ve genişliği (yüzde); sağ kenara taşmaz. */
  boxLeft: number;
  occ: number;
  /** Kutunun içindeki renkli şeridin konumu ve genişliği (kutuya göre yüzde). */
  bandOffset: number;
  bandWidth: number;
  /** Kutu sağ kenara yaslandı: yazı da sona hizalanır. */
  alignEnd: boolean;
}

export function layoutBox(leftPct: number, widthPct: number, minOcc = MIN_LABEL_PCT): BoxLayout {
  const occ = Math.min(100, Math.max(widthPct, minOcc));
  const boxLeft = Math.min(leftPct, 100 - occ);
  return {
    boxLeft,
    occ,
    bandOffset: ((leftPct - boxLeft) / occ) * 100,
    bandWidth: (widthPct / occ) * 100,
    alignEnd: boxLeft < leftPct,
  };
}

/** Çakışmayan alt satırlara açgözlü paketleme (başlangıca göre sıralı); satır = aynı çizgide yan yana duran olaylar. */
export function packLanes(items: PlacedEvent[], gapPct = 0.6): PlacedEvent[][] {
  const sorted = [...items].sort((a, b) => a.leftPct - b.leftPct || a.ev.id - b.ev.id);
  const rows: { end: number; items: PlacedEvent[] }[] = [];
  for (const it of sorted) {
    const box = layoutBox(it.leftPct, it.widthPct);
    const row = rows.find((r) => r.end + gapPct <= box.boxLeft);
    if (row) {
      row.items.push(it);
      row.end = box.boxLeft + box.occ;
    } else {
      rows.push({ end: box.boxLeft + box.occ, items: [it] });
    }
  }
  return rows.map((r) => r.items);
}

export interface TimelineLane {
  kind: CalendarKind;
  rows: PlacedEvent[][];
  count: number;
}

/** Pencerede olayı olan türler için şerit üretir; sıra `order` (CALENDAR_KINDS) sırasıdır. */
export function buildLanes(events: AcademicEvent[], win: TimelineWindow, order: readonly CalendarKind[]): TimelineLane[] {
  const byKind = new Map<CalendarKind, PlacedEvent[]>();
  for (const ev of events) {
    const p = placeEvent(ev, win);
    if (!p) continue;
    const arr = byKind.get(ev.kind) ?? [];
    arr.push(p);
    byKind.set(ev.kind, arr);
  }
  return order
    .filter((k) => byKind.has(k))
    .map((kind) => {
      const items = byKind.get(kind)!;
      return { kind, rows: packLanes(items), count: items.length };
    });
}

/** Bugün çizgisinin konumu (bugünün sütununun ortası, yüzde); pencere dışındaysa null. */
export function todayPct(win: TimelineWindow, todayKey: string): number | null {
  const n = dayNum(todayKey);
  if (Number.isNaN(n) || n < win.startNum || n >= win.startNum + win.totalDays) return null;
  return ((n - win.startNum + 0.5) / win.totalDays) * 100;
}

export interface UpcomingItem {
  ev: AcademicEvent;
  /** Başlangıca kalan gün (0 = bugün); sürüyorsa negatif ya da 0 ve `ongoing` true. */
  inDays: number;
  ongoing: boolean;
  /** Sürüyorsa bitişe kalan gün (bugün biterse 0). */
  endsInDays: number;
}

export interface UpcomingSummary {
  ongoing: UpcomingItem[];
  next: UpcomingItem[];
  /** Bugünden itibaren `horizon` gün içinde başlayan ya da süren olay sayısı. */
  withinHorizon: number;
  /** Aynı ufuktaki taslak (mobilde görünmeyen) olay sayısı. */
  draftSoon: number;
  horizon: number;
}

/** Süren ve sıradaki olaylar; geçmiş olaylar yok sayılır. */
export function summarizeUpcoming(
  events: AcademicEvent[],
  todayKey: string,
  limit = 5,
  horizon = 30,
): UpcomingSummary {
  const today = dayNum(todayKey);
  const ongoing: UpcomingItem[] = [];
  const upcoming: UpcomingItem[] = [];
  for (const ev of events) {
    const span = eventSpan(ev);
    if (!span || Number.isNaN(today) || span.end < today) continue;
    if (span.start <= today) ongoing.push({ ev, inDays: 0, ongoing: true, endsInDays: span.end - today });
    else upcoming.push({ ev, inDays: span.start - today, ongoing: false, endsInDays: span.end - today });
  }
  ongoing.sort((a, b) => a.endsInDays - b.endsInDays || a.ev.id - b.ev.id);
  upcoming.sort((a, b) => a.inDays - b.inDays || a.ev.startsAt.localeCompare(b.ev.startsAt) || a.ev.id - b.ev.id);
  const soon = [...ongoing, ...upcoming.filter((u) => u.inDays <= horizon)];
  return {
    ongoing,
    next: upcoming.slice(0, limit),
    withinHorizon: soon.length,
    draftSoon: soon.filter((u) => !u.ev.published).length,
    horizon,
  };
}
