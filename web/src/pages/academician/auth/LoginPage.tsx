// SAYFA: Akademisyen girişi (/akademisyen/giris). API: POST /api/auth/login (202 = iki faktörlü doğrulama gerekli ->
// POST /api/auth/login/2fa, /resend), ardından GET /api/academician/me. Yönetim girişinin kart düzenini kullanır.
import { useEffect, useState, type FormEvent } from 'react';
import { Link, Navigate } from 'react-router-dom';
import { isApiError } from '../../../api/client';
import type { TwoFactorChallenge } from '../../../api/types';
import { Logo } from '../../../components/brand/Logo';
import { ThemeToggle } from '../../../components/ThemeToggle';
import { Button, Checkbox, FormField, Icon, Input, PasswordInput } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { usePageTitle } from '../../../lib/hooks';
import { paths } from '../../../paths';
import { useT } from '../dict';
import { acadError } from '../errors';
import { acadPaths } from '../paths';
import styles from '../../admin/LoginPage.module.css';
import { useAcadAuth, useAuthedTarget } from './AcadAuth';

export default function AcadLoginPage() {
  const i18n = useI18n();
  const t = useT();
  const { login, verifyTwoFactor, resendTwoFactor } = useAcadAuth();
  const target = useAuthedTarget();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [touched, setTouched] = useState(false);
  const [challenge, setChallenge] = useState<TwoFactorChallenge | null>(null);
  usePageTitle(t('ac.login.title'));

  if (target) return <Navigate to={target} replace />;

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
      setError(
        isApiError(err) && err.status === 401 ? t('ac.err.INVALID_CREDENTIALS') : acadError(i18n, err),
      );
    } finally {
      setBusy(false);
    }
  }

  const required = t('ac.field.required');
  const emailError = touched ? (!email.trim() ? required : !email.includes('@') ? t('ac.field.invalidEmail') : null) : null;
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
            <Logo height={32} className={styles.logo} />
            <div className={styles.head}>
              <h1 className={styles.title}>{t('ac.login.title')}</h1>
              <p className={styles.sub}>{t('ac.login.subtitle')}</p>
            </div>
            {error && (
              <div className={styles.alert} role="alert">
                <Icon name="alert" size={18} />
                <span>{error}</span>
              </div>
            )}
            <FormField label={t('ac.field.email')} error={emailError} required>
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
            <FormField label={t('ac.field.password')} error={touched && !password ? required : null} required>
              <PasswordInput
                name="password"
                autoComplete="current-password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                dir="ltr"
                showLabel={t('ac.field.showPassword')}
                hideLabel={t('ac.field.hidePassword')}
              />
            </FormField>
            <Button type="submit" size="lg" fullWidth loading={busy}>
              {busy ? t('ac.login.submitting') : t('ac.login.submit')}
            </Button>
            <p className={styles.note}>{t('ac.login.note')}</p>
          </form>
        )}
        <Link to={acadPaths.register} className={styles.back}>
          {t('ac.login.toRegister')}
        </Link>
        <Link to={paths.site.home} className={styles.back}>
          {t('ac.backToSite')}
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
  const t = useT();
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
      setError(acadError(i18n, err));
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
      setInfo(t('ac.2fa.resent'));
    } catch (err) {
      setError(acadError(i18n, err));
    } finally {
      setResending(false);
    }
  }

  return (
    <form className={styles.card} onSubmit={submit} noValidate aria-busy={busy || undefined}>
      <Logo height={32} className={styles.logo} />
      <div className={styles.head}>
        <h1 className={styles.title}>{t('ac.2fa.title')}</h1>
        <p className={styles.sub}>
          {t('ac.2fa.subtitle')} <span className="ltr">{challenge.emailHint}</span>
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
      <FormField label={t('ac.2fa.code')} error={touched && !codeValid ? t('ac.2fa.codeRequired') : null} required>
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
        {remaining > 0 ? t('ac.2fa.remaining', { time: formatRemaining(remaining) }) : t('ac.2fa.expired')}
      </p>
      <Checkbox checked={trust} onChange={(e) => setTrust(e.target.checked)} label={t('ac.2fa.trust')} />
      <Button type="submit" size="lg" fullWidth loading={busy}>
        {busy ? t('ac.2fa.submitting') : t('ac.2fa.submit')}
      </Button>
      <Button type="button" variant="secondary" fullWidth loading={resending} onClick={() => void resend()}>
        {t('ac.2fa.resend')}
      </Button>
      <Button type="button" variant="ghost" fullWidth onClick={onBack}>
        {t('ac.2fa.back')}
      </Button>
    </form>
  );
}
