/**
 * Hata toleranslı depolama sarmalayıcıları. Özel pencere, engellenmiş site verisi veya kota hatasında
 * erişim exception fırlatabilir; bu durumda bellek içi yedeğe düşülür.
 */
type Kind = 'local' | 'session';

const memory: Record<Kind, Map<string, string>> = { local: new Map(), session: new Map() };

function area(kind: Kind): Storage | null {
  try {
    return kind === 'local' ? window.localStorage : window.sessionStorage;
  } catch {
    return null;
  }
}

export function readStorage(kind: Kind, key: string): string | null {
  try {
    const v = area(kind)?.getItem(key);
    if (v !== undefined && v !== null) return v;
  } catch {
    /* yoksay */
  }
  return memory[kind].get(key) ?? null;
}

export function writeStorage(kind: Kind, key: string, value: string): void {
  memory[kind].set(key, value);
  try {
    area(kind)?.setItem(key, value);
  } catch {
    /* bellek yedeği yeterli */
  }
}

export function removeStorage(kind: Kind, key: string): void {
  memory[kind].delete(key);
  try {
    area(kind)?.removeItem(key);
  } catch {
    /* yoksay */
  }
}
