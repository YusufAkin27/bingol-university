/**
 * Panel klavye kısayolları: TEK kaynak (yardım penceresi ve dinleyici aynı tabloyu kullanır).
 * "g" + harf: sayfaya git (gmail/github deseni). Hedefler menü sayfası kimliğidir (`adminNav`); izni olmayan kullanıcıda sessizce yok sayılır.
 */
export interface GoShortcut {
  key: string;
  /** adminNav öğe kimliği */
  page: string;
}

export const GO_SHORTCUTS: readonly GoShortcut[] = [
  { key: 'd', page: 'dashboard' },
  { key: 'a', page: 'analytics' },
  { key: 'u', page: 'users' },
  { key: 'r', page: 'reports' },
  { key: 'm', page: 'chatFeed' },
  { key: 'p', page: 'posts' },
  { key: 'k', page: 'communities' },
  { key: 'e', page: 'events' },
  { key: 't', page: 'tickets' },
  { key: 'c', page: 'campaigns' },
  { key: 'n', page: 'news' },
  { key: 'y', page: 'menu' },
  { key: 's', page: 'system' },
  { key: 'b', page: 'backup' },
  { key: 'l', page: 'audit' },
  { key: 'o', page: 'settings' },
];

/** "g" sonrası ikinci tuş için bekleme süresi (ms). */
export const GO_TIMEOUT_MS = 1500;

export interface KeyDescriptor {
  /** Görüntülenecek tuşlar (her biri ayrı kbd). */
  keys: string[];
  /** i18n anahtarı (admin.kbd.*) */
  labelKey: 'admin.kbd.search' | 'admin.kbd.searchSlash' | 'admin.kbd.help' | 'admin.kbd.sidebar' | 'admin.kbd.favorite' | 'admin.kbd.close';
}

export const GENERAL_SHORTCUTS: readonly KeyDescriptor[] = [
  { keys: ['Ctrl', 'K'], labelKey: 'admin.kbd.search' },
  { keys: ['/'], labelKey: 'admin.kbd.searchSlash' },
  { keys: ['?'], labelKey: 'admin.kbd.help' },
  { keys: ['['], labelKey: 'admin.kbd.sidebar' },
  { keys: ['f'], labelKey: 'admin.kbd.favorite' },
  { keys: ['Esc'], labelKey: 'admin.kbd.close' },
];

/** Olay hedefi yazı alanı mı (kısayollar yazarken devreye girmemeli). */
export function isTypingTarget(el: EventTarget | null): boolean {
  if (!(el instanceof HTMLElement)) return false;
  if (el.isContentEditable) return true;
  // harfle öne atlayan (type-ahead) bileşenler: liste kutusu, menü, arama kutusu, ızgara
  if (el.closest('[role="listbox"],[role="menu"],[role="combobox"],[role="textbox"],[role="searchbox"],[role="grid"]')) return true;
  const tag = el.tagName;
  if (tag === 'TEXTAREA' || tag === 'SELECT') return true;
  if (tag === 'INPUT') {
    const type = (el as HTMLInputElement).type;
    return !['button', 'checkbox', 'radio', 'submit', 'reset', 'range', 'file', 'color'].includes(type);
  }
  return false;
}
