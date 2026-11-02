import { paths } from '../paths';
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import { authApi } from '../api';
import { isApiError, setUnauthorizedHandler } from '../api/client';
import type { AdminMe, TokenResponse, TwoFactorChallenge } from '../api/types';
import { resendSecondsOf } from '../lib/resendCountdown';
import { clearTokens, getAccessToken, getRefreshToken, setTokens } from './tokens';

/**
 * loading: oturum doğrulanıyor · anonymous: giriş yok · authenticated: ADMIN ·
 * forbidden: giriş yapılmış ama ADMIN değil ("yetkiniz yok" ekranı).
 */
export type AuthStatus = 'loading' | 'anonymous' | 'authenticated' | 'forbidden';

export interface AuthContextValue {
  status: AuthStatus;
  user: AdminMe | null;
  /**
   * Hata durumunda ApiError fırlatır (kod: INVALID_CREDENTIALS, EMAIL_NOT_VERIFIED, ...).
   * İki faktörlü doğrulama gerekiyorsa (202) oturum AÇILMAZ ve challenge döner; null = oturum açıldı.
   */
  login: (email: string, password: string) => Promise<TwoFactorChallenge | null>;
  /** Giriş kodunu doğrular (TWO_FACTOR_CODE_INVALID, TWO_FACTOR_CHALLENGE_EXPIRED, 429) ve oturumu açar. */
  verifyTwoFactor: (challengeToken: string, code: string, trustDevice: boolean) => Promise<void>;
  /** Kodu e-postaya yeniden gönderir; geçerlilik süresini (sn) döndürür. */
  resendTwoFactor: (challengeToken: string) => Promise<{ expiresInSeconds: number; resendAfterSeconds: number }>;
  logout: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [status, setStatus] = useState<AuthStatus>(() =>
    getAccessToken() || getRefreshToken() ? 'loading' : 'anonymous',
  );
  const [user, setUser] = useState<AdminMe | null>(null);
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const navigateRef = useRef(navigate);
  navigateRef.current = navigate;

  /** /admin/me ile rolü doğrula. 403 ya da ADMIN olmayan rol → forbidden. */
  const verify = useCallback(async () => {
    try {
      const me = await authApi.getAdminMe();
      if (me.role !== 'ADMIN') {
        setUser(null);
        setStatus('forbidden');
        return;
      }
      setUser(me);
      setStatus('authenticated');
    } catch (e) {
      setUser(null);
      if (isApiError(e) && e.status === 403) {
        setStatus('forbidden');
      } else if (isApiError(e) && (e.status === 401 || e.status === 400)) {
        clearTokens();
        setStatus('anonymous');
      } else {
        // Ağ/sunucu hatası: oturum belirsiz; giriş ekranına düş ama token'ı silme
        setStatus('anonymous');
      }
    }
  }, []);

  // Açılışta mevcut oturumu doğrula
  useEffect(() => {
    if (status === 'loading') void verify();
    // yalnızca ilk yüklemede
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // İstemci refresh'i başaramazsa: oturumu kapat, girişe yönlendir
  useEffect(() => {
    setUnauthorizedHandler(() => {
      setUser(null);
      setStatus('anonymous');
      queryClient.clear();
      const from = window.location.pathname + window.location.search;
      if (!window.location.pathname.startsWith(paths.admin.login)) {
        navigateRef.current(paths.admin.login, { replace: true, state: { from } });
      }
    });
    return () => setUnauthorizedHandler(null);
  }, [queryClient]);

  const completeLogin = useCallback(
    async (t: TokenResponse) => {
      setTokens(t.accessToken, t.refreshToken);
      await verify();
    },
    [verify],
  );

  const login = useCallback(
    async (email: string, password: string): Promise<TwoFactorChallenge | null> => {
      const r = await authApi.login({ email: email.trim(), password });
      if (authApi.isTwoFactorChallenge(r)) return r;
      await completeLogin(r);
      return null;
    },
    [completeLogin],
  );

  const verifyTwoFactor = useCallback(
    async (challengeToken: string, code: string, trustDevice: boolean) => {
      const t = await authApi.verifyTwoFactorLogin({ challengeToken, code: code.trim(), trustDevice });
      await completeLogin(t);
    },
    [completeLogin],
  );

  const resendTwoFactor = useCallback(async (challengeToken: string) => {
    const r = await authApi.resendTwoFactorCode(challengeToken);
    return { expiresInSeconds: r?.expiresInSeconds ?? 600, resendAfterSeconds: resendSecondsOf(r) };
  }, []);

  const logout = useCallback(async () => {
    const rt = getRefreshToken();
    clearTokens();
    setUser(null);
    setStatus('anonymous');
    queryClient.clear();
    if (rt) {
      try {
        await authApi.logout(rt);
      } catch {
        /* sunucu tarafı en iyi çaba */
      }
    }
  }, [queryClient]);

  const value = useMemo(
    () => ({ status, user, login, verifyTwoFactor, resendTwoFactor, logout }),
    [status, user, login, verifyTwoFactor, resendTwoFactor, logout],
  );
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const v = useContext(AuthContext);
  if (!v) throw new Error('useAuth yalnızca <AuthProvider> içinde kullanılabilir');
  return v;
}
