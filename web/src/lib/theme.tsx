import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import { readStorage, writeStorage } from './storage';

export type ThemeChoice = 'light' | 'dark' | 'system';
export type ResolvedTheme = 'light' | 'dark';

interface ThemeCtx {
  /** Kullanıcının seçimi; 'system' ise işletim sistemi tercihi izlenir. */
  choice: ThemeChoice;
  resolved: ResolvedTheme;
  setChoice: (c: ThemeChoice) => void;
  /** Açık ↔ koyu (sistem seçiliyken görünen temanın tersine) */
  toggle: () => void;
}

const KEY = 'bu.theme';
const Ctx = createContext<ThemeCtx | null>(null);

function readChoice(): ThemeChoice {
  const v = readStorage('local', KEY);
  return v === 'light' || v === 'dark' ? v : 'system';
}

function systemTheme(): ResolvedTheme {
  try {
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  } catch {
    return 'light';
  }
}

export function ThemeProvider({ children }: { children: ReactNode }) {
  const [choice, setChoiceState] = useState<ThemeChoice>(readChoice);
  const [system, setSystem] = useState<ResolvedTheme>(systemTheme);

  useEffect(() => {
    let mq: MediaQueryList;
    try {
      mq = window.matchMedia('(prefers-color-scheme: dark)');
    } catch {
      return;
    }
    const on = () => setSystem(mq.matches ? 'dark' : 'light');
    mq.addEventListener?.('change', on);
    return () => mq.removeEventListener?.('change', on);
  }, []);

  // 'system' iken data-theme kaldırılır; CSS prefers-color-scheme medya sorgusu devreye girer
  useEffect(() => {
    const el = document.documentElement;
    if (choice === 'system') el.removeAttribute('data-theme');
    else el.setAttribute('data-theme', choice);
  }, [choice]);

  const setChoice = useCallback((c: ThemeChoice) => {
    setChoiceState(c);
    if (c === 'system') writeStorage('local', KEY, 'system');
    else writeStorage('local', KEY, c);
  }, []);

  const resolved: ResolvedTheme = choice === 'system' ? system : choice;
  const value = useMemo<ThemeCtx>(
    () => ({ choice, resolved, setChoice, toggle: () => setChoice(resolved === 'dark' ? 'light' : 'dark') }),
    [choice, resolved, setChoice],
  );
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useTheme(): ThemeCtx {
  const v = useContext(Ctx);
  if (!v) throw new Error('useTheme yalnızca <ThemeProvider> içinde kullanılabilir');
  return v;
}
