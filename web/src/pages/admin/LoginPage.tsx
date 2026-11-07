import { useNoIndex } from '../../lib/useNoIndex';
// SAYFA: Yönetici girişi (/admin/login): yalnız Türkçe, sade krem zemin, mobil uygulamayla aynı tasarım dili.
// API: POST /api/auth/login, ardından GET /api/admin/me (AuthProvider.login); rol ADMIN değilse "yetkiniz yok" ekranı.
//      İki faktörlü doğrulama: login 202 {challengeToken,emailHint,expiresInSeconds} → "Giriş kodu" adımı:
//      POST /api/auth/login/2fa {challengeToken,code,trustDevice}, POST /api/auth/login/2fa/resend (docs/TWO_FACTOR_API.md).
import { useEffect, useState, type FormEvent } from 'react';
import { Link, Navigate, useLocation } from 'react-router-dom';
import { isApiError } from '../../api/client';
import type { TwoFactorChallenge } from '../../api/types';
import { isAdminPath } from '../../adminBase';
import { useAuth } from '../../auth/AuthProvider';
import { ForbiddenScreen } from '../../auth/ForbiddenScreen';
import { Logo } from '../../components/brand/Logo';
import { ThemeToggle } from '../../components/ThemeToggle';
import { Button, Checkbox, FormField, Icon, Input, PasswordInput } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { errorMessage } from '../../lib/errors';
import { usePageTitle } from '../../lib/hooks';
import { paths } from '../../paths';
import { gt } from './twofactor/dict';
import styles from './LoginPage.module.css';

export default function LoginPage() {
  useNoIndex();
  const i18n = useI18n();
  const { t } = i18n;
  const { status, login, verifyTwoFactor, resendTwoFactor } = useAuth();
  const location = useLocation();
  const from = (location.state as { from?: string } | null)?.from;
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [touched, setTouched] = useState(false);
  const [challenge, setChallenge] = useState<TwoFactorChallenge | null>(null);
  usePageTitle(t('admin.login.title'));

  if (status === 'authenticated') {
    return <Navigate to={from && isAdminPath(from) ? from : paths.admin.dashboard} replace />;
  }
  if (status === 'forbidden') return <ForbiddenScreen />;

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setTouched(true);
    setError(null);
    if (!email.trim() || !password || !email.includes('@')) return;
    setBusy(true);
    try {
      const c = await login(email, password);
      if (c) setChallenge(c);
    } catch (err) {
      // 429: sunucunun hız sınırı; 401: hatalı bilgiler (sızıntısız tek genel metin)
      setError(
        isApiError(err) && err.status === 429
          ? t('admin.login.rateLimited')
          : isApiError(err) && err.status === 401
            ? t('common.error.INVALID_CREDENTIALS')
            : errorMessage(i18n, err),
      );
    } finally {
      setBusy(false);
    }
  }

  const required = t('admin.login.required');
  const emailError = touched ? (!email.trim() ? required : !email.includes('@') ? t('admin.login.invalidEmail') : null) : null;
  return (
    <div className={styles.page}>
      <div className={styles.tools}>
        <ThemeToggle />
      </div>
      <main className={styles.center}>
        {challenge ? (
          <TwoFactorStep
            challenge={challenge}
            onVerify={verifyTwoFactor}
            onResend={resendTwoFactor}
            onBack={() => {
              setChallenge(null);
              setPassword('');
            }}
          />
        ) : (
          <form className={styles.card} onSubmit={onSubmit} noValidate aria-busy={busy || undefined}>
            <Logo to={paths.site.home} height={32} className={styles.logo} />
            <div className={styles.head}>
              <h1 className={styles.title}>{t('admin.login.title')}</h1>
              <p className={styles.sub}>{t('admin.login.subtitle')}</p>
            </div>
            {error && (
              <div className={styles.alert} role="alert">
                <Icon name="alert" size={18} />
                <span>{error}</span>
              </div>
            )}
            <FormField label={t('admin.login.email')} error={emailError} required>
              <Input
                type="email"
                name="email"
                autoComplete="username"
                inputMode="email"
                autoCapitalize="none"
                spellCheck={false}
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                dir="ltr"
              />
            </FormField>
            <FormField label={t('admin.login.password')} error={touched && !password ? required : null} required>
              <PasswordInput
                name="password"
                autoComplete="current-password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                dir="ltr"
                showLabel={t('admin.login.showPassword')}
                hideLabel={t('admin.login.hidePassword')}
              />
            </FormField>
            <Button type="submit" size="lg" fullWidth loading={busy}>
              {busy ? t('admin.login.submitting') : t('admin.login.submit')}
            </Button>
            <p className={styles.note}>{t('admin.login.restricted')}</p>
            <p className={styles.note}>{t('admin.v2n.login.help')}</p>
          </form>
        )}
        <Link to={paths.admin.register} className={styles.back}>
          {t('admin.reg.linkFromLogin')}
        </Link>
        <Link to={paths.site.home} className={styles.back}>
          {t('admin.login.backToSite')}
        </Link>
      </main>
    </div>
  );
}

function formatRemaining(sec: number): string {
  const m = Math.floor(sec / 60);
  const r = sec % 60;
  return `${m}:${String(r).padStart(2, '0')}`;
}

interface StepProps {
  challenge: TwoFactorChallenge;
  onVerify: (challengeToken: string, code: string, trustDevice: boolean) => Promise<void>;
  onResend: (challengeToken: string) => Promise<number>;
  onBack: () => void;
}

/** "Giriş kodu" adımı: e-postadaki 6 haneli kod, "bu tarayıcıya güven", yeniden gönder, süre sayacı. */
function TwoFactorStep({ challenge, onVerify, onResend, onBack }: StepProps) {
  const i18n = useI18n();
  const t = gt(i18n);
  const [code, setCode] = useState('');
  const [trust, setTrust] = useState(true);
  const [busy, setBusy] = useState(false);
  const [resending, setResending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);
  const [touched, setTouched] = useState(false);
  const [remaining, setRemaining] = useState(challenge.expiresInSeconds);

  useEffect(() => {
    const id = window.setInterval(() => setRemaining((r) => (r > 0 ? r - 1 : 0)), 1000);
    return () => window.clearInterval(id);
  }, []);

  const codeValid = /^\d{6}$/.test(code);

  async function submit(e: FormEvent) {
    e.preventDefault();
    setTouched(true);
    setError(null);
    setInfo(null);
    if (!codeValid) return;
    setBusy(true);
    try {
      await onVerify(challenge.challengeToken, code, trust);
    } catch (err) {
      setError(errorMessage(i18n, err));
      setBusy(false);
    }
  }

  async function resend() {
    setResending(true);
    setError(null);
    setInfo(null);
    try {
      const sec = await onResend(challenge.challengeToken);
      setRemaining(sec);
      setCode('');
      setTouched(false);
      setInfo(t('admin.login.2fa.resent'));
    } catch (err) {
      setError(errorMessage(i18n, err));
    } finally {
      setResending(false);
    }
  }

  return (
    <form className={styles.card} onSubmit={submit} noValidate aria-busy={busy || undefined}>
      <Logo to={paths.site.home} height={32} className={styles.logo} />
      <div className={styles.head}>
        <h1 className={styles.title}>{t('admin.login.2fa.title')}</h1>
        <p className={styles.sub}>
          {t('admin.login.2fa.subtitle')} <span className="ltr">{challenge.emailHint}</span>
        </p>
      </div>
      {error && (
        <div className={styles.alert} role="alert">
          <Icon name="alert" size={18} />
          <span>{error}</span>
        </div>
      )}
      {info && !error && (
        <p className={styles.sub} role="status">
          {info}
        </p>
      )}
      <FormField
        label={t('admin.login.2fa.code')}
        error={touched && !codeValid ? t('admin.login.2fa.codeRequired') : null}
        required
      >
        <Input
          name="code"
          inputMode="numeric"
          autoComplete="one-time-code"
          maxLength={6}
          value={code}
          onChange={(e) => setCode(e.target.value.replace(/\D/g, '').slice(0, 6))}
          dir="ltr"
          data-autofocus
        />
      </FormField>
      <p className={styles.sub} role="timer" aria-live="off">
        {remaining > 0
          ? t('admin.login.2fa.remaining', { time: formatRemaining(remaining) })
          : t('admin.login.2fa.expired')}
      </p>
      <Checkbox checked={trust} onChange={(e) => setTrust(e.target.checked)} label={t('admin.login.2fa.trust')} />
      <Button type="submit" size="lg" fullWidth loading={busy}>
        {busy ? t('admin.login.2fa.submitting') : t('admin.login.2fa.submit')}
      </Button>
      <Button type="button" variant="secondary" fullWidth loading={resending} onClick={() => void resend()}>
        {t('admin.login.2fa.resend')}
      </Button>
      <Button type="button" variant="ghost" fullWidth onClick={onBack}>
        {t('admin.login.2fa.back')}
      </Button>
    </form>
  );
}
