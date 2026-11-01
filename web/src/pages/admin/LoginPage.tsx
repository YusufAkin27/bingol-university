import { useNoIndex } from '../../lib/useNoIndex';
// SAYFA: Yönetici girişi (/admin/login) — iskelet tarafından tamamlanmıştır.
// API: POST /api/auth/login, ardından GET /api/admin/me (AuthProvider.login); rol ADMIN değilse "yetkiniz yok" ekranı.
//      İki faktörlü doğrulama: login 202 {challengeToken,emailHint,expiresInSeconds} → "Giriş kodu" adımı:
//      POST /api/auth/login/2fa {challengeToken,code,trustDevice}, POST /api/auth/login/2fa/resend (docs/TWO_FACTOR_API.md).
import { useEffect, useState, type FormEvent } from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { useAuth } from '../../auth/AuthProvider';
import { ForbiddenScreen } from '../../auth/ForbiddenScreen';
import { LanguageSwitcher } from '../../components/LanguageSwitcher';
import { Logo } from '../../components/brand/Logo';
import { ThemeToggle } from '../../components/ThemeToggle';
import type { TwoFactorChallenge } from '../../api/types';
import {
  Button,
  Checkbox,
  ContourBackdrop,
  FormField,
  Icon,
  Input,
  PasswordInput,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { errorMessage } from '../../lib/errors';
import { usePageTitle } from '../../lib/hooks';
import { paths } from '../../paths';
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
    return <Navigate to={from && from.startsWith('/admin') ? from : paths.admin.dashboard} replace />;
  }
  if (status === 'forbidden') return <ForbiddenScreen />;

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setTouched(true);
    setError(null);
    if (!email.trim() || !password) return;
    setBusy(true);
    try {
      const c = await login(email, password);
      if (c) setChallenge(c);
    } catch (err) {
      setError(errorMessage(i18n, err));
    } finally {
      setBusy(false);
    }
  }

  const required = t('admin.login.required');
  return (
    <div className={styles.page}>
      <aside className={styles.brand}>
        <ContourBackdrop className={styles.art} />
        <div className={styles.brandInner}>
          <Logo to={paths.site.home} tone="dark" height={44} />
          <p className={styles.line}>{t('admin.login.brandLine')}</p>
        </div>
      </aside>
      <main className={styles.formSide}>
        <div className={styles.tools}>
          <LanguageSwitcher compact />
          <ThemeToggle />
        </div>
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
          <form className={styles.form} onSubmit={onSubmit} noValidate>
            <div>
              <h1 className={styles.title}>{t('admin.login.title')}</h1>
              <p className={styles.sub}>{t('admin.login.subtitle')}</p>
            </div>
            {error && (
              <div className={styles.alert} role="alert">
                <Icon name="alert" size={18} />
                <span>{error}</span>
              </div>
            )}
            <FormField
              label={t('admin.login.email')}
              error={touched && !email.trim() ? required : null}
              required
            >
              <Input
                type="email"
                name="email"
                autoComplete="username"
                inputMode="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                dir="ltr"
              />
            </FormField>
            <FormField
              label={t('admin.login.password')}
              error={touched && !password ? required : null}
              required
            >
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
          </form>
        )}
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
  const { t } = i18n;
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
    <form className={styles.form} onSubmit={submit} noValidate>
      <div>
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
      <Checkbox
        checked={trust}
        onChange={(e) => setTrust(e.target.checked)}
        label={t('admin.login.2fa.trust')}
      />
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
