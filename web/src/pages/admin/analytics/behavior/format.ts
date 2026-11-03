// Davranış analizi yardımcıları: süre/oran biçimleyiciler, rota adı -> okunur Türkçe etiket, tarih aralığı kuralları.
// Panel yalnız Türkçedir; biçim sabit `tr-TR`dir. Hepsi saf işlevdir (birim testli).
import { istanbulDate, istanbulDaysAgo } from '../../../../lib/date';

const nf = new Intl.NumberFormat('tr-TR', { maximumFractionDigits: 1 });
const nf0 = new Intl.NumberFormat('tr-TR', { maximumFractionDigits: 0 });

/** Tam sayı (binlik ayraçlı). */
export const formatInt = (n: number | null | undefined): string =>
  n === null || n === undefined || !Number.isFinite(n) ? '—' : nf0.format(n);

/** Ondalıklı sayı (en çok 1 hane): 3,4. */
export const formatDec = (n: number | null | undefined): string =>
  n === null || n === undefined || !Number.isFinite(n) ? '—' : nf.format(n);

/** Süre (ms) -> "2 dk 14 sn", "45 sn", "1 sa 5 dk", "< 1 sn". Veri yoksa "—". */
export function formatDuration(ms: number | null | undefined): string {
  if (ms === null || ms === undefined || !Number.isFinite(ms) || ms < 0) return '—';
  const totalSec = Math.round(ms / 1000);
  if (totalSec < 1) return ms > 0 ? '< 1 sn' : '0 sn';
  if (totalSec < 60) return `${totalSec} sn`;
  if (totalSec < 3600) {
    const m = Math.floor(totalSec / 60);
    const s = totalSec % 60;
    return s ? `${m} dk ${s} sn` : `${m} dk`;
  }
  const h = Math.floor(totalSec / 3600);
  const m = Math.floor((totalSec % 3600) / 60);
  return m ? `${h} sa ${m} dk` : `${h} sa`;
}

/** Oran (0..1) -> "%12,3". */
export function formatPct(ratio: number | null | undefined): string {
  if (ratio === null || ratio === undefined || !Number.isFinite(ratio)) return '—';
  return `%${nf.format(ratio * 100)}`;
}

/** Yüzde olarak gelen değer (0..100, ör. sharePct) -> "%12,3". */
export function formatPctPoints(p: number | null | undefined): string {
  return p === null || p === undefined || !Number.isFinite(p) ? '—' : `%${nf.format(p)}`;
}

// ---------------------------------------------------------------------------------------------
// Ekran adları

const SCREEN_LABELS: Record<string, string> = {
  home: 'Ana Sayfa',
  discover: 'Keşfet',
  explore: 'Keşfet',
  chat: 'Sohbetler',
  chats: 'Sohbetler',
  chat_list: 'Sohbetler',
  chat_detail: 'Sohbet',
  chat_info: 'Sohbet Bilgisi',
  new_chat: 'Yeni Sohbet',
  message_requests: 'Mesaj İstekleri',
  contacts_match: 'Kişi Eşleştirme',
  clubs: 'Kulüpler',
  club_detail: 'Kulüp Detayı',
  club_form: 'Kulüp Oluştur / Düzenle',
  club_members: 'Kulüp Üyeleri',
  club_requests: 'Kulüp Başvuruları',
  events: 'Etkinlikler',
  event_detail: 'Etkinlik Detayı',
  event_form: 'Etkinlik Oluştur / Düzenle',
  event_qr: 'Etkinlik QR',
  event_attendance: 'Etkinlik Yoklama',
  menu: 'Yemek Listesi',
  food: 'Yemek Listesi',
  news: 'Haberler',
  news_detail: 'Haber Detayı',
  announcements: 'Duyurular',
  announcement_detail: 'Duyuru Detayı',
  unit_news: 'Birim Haberleri',
  unit_news_detail: 'Birim Haber Detayı',
  notifications: 'Bildirimler',
  notification_settings: 'Bildirim Ayarları',
  search: 'Arama',
  support: 'Destek',
  support_ticket: 'Destek Talebi',
  support_new: 'Yeni Destek Talebi',
  faq: 'Sıkça Sorulan Sorular',
  feedback: 'Geri Bildirim',
  profile: 'Profil',
  profile_edit: 'Profili Düzenle',
  edit_profile: 'Profili Düzenle',
  user_profile: 'Kullanıcı Profili',
  settings: 'Ayarlar',
  privacy: 'Gizlilik',
  language: 'Dil',
  theme: 'Tema',
  about: 'Hakkında',
  polls: 'Anketler',
  poll_detail: 'Anket',
  posts: 'Gönderiler',
  post_detail: 'Gönderi',
  post_create: 'Gönderi Oluştur',
  follow_list: 'Takip Listesi',
  follow_requests: 'Takip İstekleri',
  academic: 'Akademik',
  academic_hub: 'Akademik',
  academic_calendar: 'Akademik Takvim',
  timetable: 'Ders Programı',
  exams: 'Sınavlar',
  reminder_settings: 'Hatırlatıcı Ayarları',
  login: 'Giriş',
  register: 'Kayıt Ol',
  welcome: 'Karşılama',
  verify_code: 'Kod Doğrulama',
  forgot_password: 'Şifremi Unuttum',
  reset_code: 'Sıfırlama Kodu',
  new_password: 'Yeni Şifre',
  reset_success: 'Şifre Sıfırlandı',
  permissions: 'İzinler',
  legal: 'Sözleşmeler',
  legal_reaccept: 'Sözleşme Onayı',
  maintenance: 'Bakım',
};

/** Rota adını karşılaştırma anahtarına çevirir: "/chat-detail" ve "ChatDetailPage" -> "chat_detail". */
export function screenKey(raw: string): string {
  return raw
    .trim()
    .replace(/([a-z0-9])([A-Z])/g, '$1_$2')
    .toLowerCase()
    .replace(/^\/+|\/+$/g, '')
    .replace(/[\s/\-.]+/g, '_')
    .replace(/_(page|screen|route)$/, '');
}

/** Okunur ekran adı; bilinmeyen rota adı olduğu gibi döner (boş: "Bilinmeyen"). */
export function screenLabel(raw: string | null | undefined): string {
  if (!raw) return 'Bilinmeyen';
  return SCREEN_LABELS[screenKey(raw)] ?? raw;
}

// ---------------------------------------------------------------------------------------------
// Eylemler

const ACTION_LABELS: Record<string, string> = {
  like: 'Beğeni',
  unlike: 'Beğeniyi geri alma',
  follow: 'Takip etme',
  unfollow: 'Takipten çıkma',
  share: 'Paylaşma',
  bookmark: 'Kaydetme / favori',
  join_club: 'Kulübe katılma',
  leave_club: 'Kulüpten ayrılma',
  rsvp: 'Etkinliğe katılım bildirme',
  checkin: 'Etkinlik yoklaması',
  vote: 'Anket oyu',
  rate_menu: 'Menü puanlama',
  search_submit: 'Arama gönderme',
  send_message: 'Mesaj gönderme',
  post_create: 'Gönderi oluşturma',
  ticket_create: 'Destek talebi açma',
  ticket_reply: 'Destek talebi yanıtlama',
  profile_edit: 'Profil düzenleme',
  notif_open: 'Bildirim açma',
  push_open: 'Push ile uygulamayı açma',
  pull_refresh: 'Yenileme (aşağı çekme)',
  tab_switch: 'Sekme değiştirme',
};

export function actionLabel(kind: string | null | undefined): string {
  if (!kind) return 'Eylem';
  return ACTION_LABELS[kind] ?? kind;
}

const REASON_LABELS: Record<string, string> = {
  background: 'Arka plana atıldı',
  exit: 'Uygulamadan çıkıldı',
  timeout: 'Hareketsizlik (zaman aşımı)',
  derived: 'Türetilmiş (eski sürüm)',
};

export function reasonLabel(reason: string): string {
  return REASON_LABELS[reason] ?? reason;
}

// ---------------------------------------------------------------------------------------------
// Tarih aralığı (en çok 45 gün; sunucu gün sınırı Europe/Istanbul)

export const MAX_RANGE_DAYS = 45;
export const RANGE_PRESETS = [7, 14, 30, 45] as const;
export const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

export interface Range {
  from: string;
  to: string;
}

const toUtc = (iso: string) => {
  const [y, m, d] = iso.split('-').map(Number);
  return Date.UTC(y, m - 1, d);
};
const fromUtc = (ms: number) => {
  const t = new Date(ms);
  return `${t.getUTCFullYear()}-${String(t.getUTCMonth() + 1).padStart(2, '0')}-${String(t.getUTCDate()).padStart(2, '0')}`;
};

/** Uçlar dahil gün sayısı (from > to ise 0). */
export function rangeDays(r: Range): number {
  const n = Math.round((toUtc(r.to) - toUtc(r.from)) / 86_400_000) + 1;
  return n > 0 ? n : 0;
}

/** Bugün dahil son `days` gün (İstanbul gününe göre). */
export function presetRange(days: number, now = new Date()): Range {
  return { from: istanbulDaysAgo(days - 1, now), to: istanbulDate(now) };
}

/** Ters aralığı düzeltir (yer değiştirir); 45 günü aşıyorsa başlangıç öne çekilir (bitiş korunur). */
export function clampRange(r: Range): Range {
  let { from, to } = r;
  if (toUtc(from) > toUtc(to)) [from, to] = [to, from];
  if (rangeDays({ from, to }) > MAX_RANGE_DAYS) from = fromUtc(toUtc(to) - (MAX_RANGE_DAYS - 1) * 86_400_000);
  return { from, to };
}

/** Aralığın hangi hazır seçime denk geldiği (yoksa null = özel aralık). */
export function activePreset(r: Range, now = new Date()): number | null {
  return (
    RANGE_PRESETS.find((d) => {
      const p = presetRange(d, now);
      return p.from === r.from && p.to === r.to;
    }) ?? null
  );
}

/** URL'den okunan aralık: geçersiz/eksikse son 7 gün; her durumda 45 günle sınırlı. */
export function parseRange(from: string | null, to: string | null, now = new Date()): Range {
  if (from && to && DATE_RE.test(from) && DATE_RE.test(to)) return clampRange({ from, to });
  return presetRange(7, now);
}

/** Isı çubuğu doluluğu (0..1). */
export function heat(value: number, max: number): number {
  return max > 0 && Number.isFinite(value) ? Math.max(0, Math.min(1, value / max)) : 0;
}

/** Kullanıcı çekmecesi için gün sayısı: seçili aralığın gün sayısı, en çok 45, en az 1. */
export function drawerDays(r: Range): number {
  return Math.max(1, Math.min(MAX_RANGE_DAYS, rangeDays(r)));
}

// ---------------------------------------------------------------------------------------------
// Zaman çizelgesi (İstanbul saati)

const clockFmt = new Intl.DateTimeFormat('tr-TR', {
  timeZone: 'Europe/Istanbul',
  hour: '2-digit',
  minute: '2-digit',
  second: '2-digit',
  hour12: false,
});
const dayFmt = new Intl.DateTimeFormat('tr-TR', {
  timeZone: 'Europe/Istanbul',
  day: 'numeric',
  month: 'short',
  weekday: 'short',
});

/** "14:03:22" (İstanbul). Geçersiz değerde "—". */
export function formatClock(iso: string | null | undefined): string {
  const d = iso ? new Date(iso) : null;
  return d && !Number.isNaN(d.getTime()) ? clockFmt.format(d) : '—';
}

/** "3 Kas Sal" (İstanbul). */
export function formatDayShort(iso: string | null | undefined): string {
  const d = iso ? new Date(iso) : null;
  return d && !Number.isNaN(d.getTime()) ? dayFmt.format(d) : '—';
}

/** Oturum başlangıcından geçen süre: "+0:12", "+2:05" (dk:sn). */
export function formatOffset(startIso: string, atIso: string): string {
  const ms = new Date(atIso).getTime() - new Date(startIso).getTime();
  if (!Number.isFinite(ms)) return '';
  const s = Math.max(0, Math.round(ms / 1000));
  return `+${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
}
