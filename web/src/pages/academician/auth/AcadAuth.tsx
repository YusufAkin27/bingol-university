// Akademisyen paneli oturumu: yönetim AuthProvider'ından AYRI. Token'lar `bu.acad.*`, doğrulama `GET /academician/me`,
// oturum düşünce `/akademisyen/giris`e gidilir (yönetim girişine asla). Yönetici oturumu bunu açmaz, bunun oturumu yönetimi açmaz.
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
import { Navigate, useLocation, useNavigate } from 'react-router-dom';
import * as acad from '../../../api/academician';
import * as authApi from '../../../api/auth';
import { isApiError, setUnauthorizedHandler } from '../../../api/client';
import type { TokenResponse, TwoFactorChallenge } from '../../../api/types';
import { tokensFor } from '../../../auth/tokens';
import { Button, Spinner } from '../../../components/ui';
import { isNotApproved } from '../errors';
import { acadPaths } from '../paths';
import { useT } from '../dict';
import styles from '../academician.module.css';

const tokens = tokensFor('acad');

/** loading: doğrulanıyor · anonymous: oturum yok · ready: oturum var (`me.status` onay durumunu verir) · error: doğrulanamadı (ağ/sunucu) */
export type AcadStatus = 'loading' | 'anonymous' | 'ready' | 'error';

export interface AcadAuthValue {
  status: AcadStatus;
  me: acad.AcademicianMe | null;
  login: (email: string, password: string) => Promise<TwoFactorChallenge | null>;
  verifyTwoFactor: (challengeToken: string, code: string, trustDevice: boolean) => Promise<void>;
  resendTwoFactor: (challengeToken: string) => Promise<number>;
  /** Kayıt + e-posta doğrulamasından dönen token'larla oturumu açar. */
  adoptTokens: (t: TokenResponse) => Promise<acad.AcademicianMe | null>;
  /** `/academician/me`yi yeniden okur (başvuru sonrası, karar değişince). */
  refreshMe: () => Promise<acad.AcademicianMe | null>;
  setMe: (me: acad.AcademicianMe) => void;
  logout: () => Promise<void>;
}

const Ctx = createContext<AcadAuthValue | null>(null);

export function AcadAuthProvider({ children }: { children: ReactNode }) {
  const [status, setStatus] = useState<AcadStatus>(() =>
    tokens.getAccessToken() || tokens.getRefreshToken() ? 'loading' : 'anonymous',
  );
  const [me, setMe] = useState<acad.AcademicianMe | null>(null);
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const navigateRef = useRef(navigate);
  navigateRef.current = navigate;

  const refreshMe = useCallback(async (): Promise<acad.AcademicianMe | null> => {
    try {
      const m = await acad.getMe();
      setMe(m);
      setStatus('ready');
      return m;
    } catch (e) {
      setMe(null);
      if (isApiError(e) && (e.status === 401 || e.status === 400)) {
        tokens.clearTokens();
        setStatus('anonymous');
      } else {
        // Ağ/sunucu hatası: oturum belirsiz; token'a dokunma, yeniden deneme göster
        setStatus('error');
      }
      return null;
    }
  }, []);

  useEffect(() => {
    if (status === 'loading') void refreshMe();
    // yalnızca ilk yüklemede
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // İstemci refresh'i başaramazsa: yalnız akademisyen oturumunu kapat, akademisyen girişine git
  useEffect(() => {
    setUnauthorizedHandler(
      () => {
        setMe(null);
        setStatus('anonymous');
        queryClient.clear();
        const from = window.location.pathname + window.location.search;
        if (!window.location.pathname.startsWith(acadPaths.login)) {
          navigateRef.current(acadPaths.login, { replace: true, state: { from } });
        }
      },
      'acad',
    );
    return () => setUnauthorizedHandler(null, 'acad');
  }, [queryClient]);

  // Herhangi bir istek 403 ACADEMICIAN_NOT_APPROVED dönerse (yetki kaldırıldı/başvuru değişti) durum yeniden okunur;
  // korumalı rota o zaman `beklemede`ye yönlendirir.
  useEffect(() => {
    const onErr = (error: unknown) => {
      if (isNotApproved(error)) void refreshMe();
    };
    const unQ = queryClient.getQueryCache().subscribe((ev) => {
      if (ev.type === 'updated' && ev.action.type === 'error') onErr(ev.action.error);
    });
    const unM = queryClient.getMutationCache().subscribe((ev) => {
      if (ev.type === 'updated' && ev.action.type === 'error') onErr(ev.action.error);
    });
    return () => {
      unQ();
      unM();
    };
  }, [queryClient, refreshMe]);

  const adoptTokens = useCallback(
    async (t: TokenResponse) => {
      tokens.setTokens(t.accessToken, t.refreshToken);
      return refreshMe();
    },
    [refreshMe],
  );

  const login = useCallback(
    async (email: string, password: string): Promise<TwoFactorChallenge | null> => {
      const r = await authApi.login({ email: email.trim(), password });
      if (authApi.isTwoFactorChallenge(r)) return r;
      await adoptTokens(r);
      return null;
    },
    [adoptTokens],
  );

  const verifyTwoFactor = useCallback(
    async (challengeToken: string, code: string, trustDevice: boolean) => {
      const t = await authApi.verifyTwoFactorLogin({ challengeToken, code: code.trim(), trustDevice });
      await adoptTokens(t);
    },
    [adoptTokens],
  );

  const resendTwoFactor = useCallback(async (challengeToken: string) => {
    const r = await authApi.resendTwoFactorCode(challengeToken);
    return r?.expiresInSeconds ?? 600;
  }, []);

  const logout = useCallback(async () => {
    const rt = tokens.getRefreshToken();
    tokens.clearTokens();
    setMe(null);
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

  const value = useMemo<AcadAuthValue>(
    () => ({ status, me, login, verifyTwoFactor, resendTwoFactor, adoptTokens, refreshMe, setMe, logout }),
    [status, me, login, verifyTwoFactor, resendTwoFactor, adoptTokens, refreshMe, logout],
  );
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useAcadAuth(): AcadAuthValue {
  const v = useContext(Ctx);
  if (!v) throw new Error('useAcadAuth yalnızca <AcadAuthProvider> içinde kullanılabilir');
  return v;
}

function Loading() {
  const t = useT();
  return (
    <div className={styles.centerFill}>
      <Spinner size="lg" label={t('ac.loading')} />
    </div>
  );
}

/**
 * Panel rotalarını korur: oturum yoksa `giris`e; oturum var ama başvuru onaylı değilse (yok/bekliyor/reddedildi/iptal)
 * `beklemede`ye. Onaylı akademisyen çocuk rotaları görür.
 */
export function RequireAcademician({ children }: { children: ReactNode }) {
  const { status, me, refreshMe } = useAcadAuth();
  const t = useT();
  const location = useLocation();
  if (status === 'loading') return <Loading />;
  if (status === 'error') {
    return (
      <div className={styles.centerFill} role="alert">
        <p>{t('ac.session.error')}</p>
        <Button variant="secondary" onClick={() => void refreshMe()}>
          {t('ac.retry')}
        </Button>
      </div>
    );
  }
  if (status === 'anonymous') {
    return <Navigate to={acadPaths.login} replace state={{ from: location.pathname + location.search }} />;
  }
  if (me?.status !== 'APPROVED') return <Navigate to={acadPaths.pending} replace />;
  return <>{children}</>;
}

/** Oturum açık ama onaylı olmayan kullanıcı için (`beklemede`): oturum yoksa girişe. */
export function RequireSession({ children }: { children: ReactNode }) {
  const { status } = useAcadAuth();
  const location = useLocation();
  if (status === 'loading') return <Loading />;
  if (status !== 'ready') {
    return <Navigate to={acadPaths.login} replace state={{ from: location.pathname + location.search }} />;
  }
  return <>{children}</>;
}

/** Giriş/kayıt sayfaları: oturum zaten varsa durumuna göre gidilecek yol (yoksa null). */
export function useAuthedTarget(): string | null {
  const { status, me } = useAcadAuth();
  const location = useLocation();
  if (status !== 'ready' || !me) return null;
  if (me.status === 'APPROVED') {
    const from = (location.state as { from?: string } | null)?.from;
    return from && from.startsWith(`${acadPaths.home}/`) && !from.startsWith(acadPaths.login) ? from : acadPaths.home;
  }
  return acadPaths.pending;
}
