import { useNoIndex } from '../../lib/useNoIndex';
// SAYFA: Yönetici hesabı kaydı (/admin/register): e-posta + şifre + kabul -> e-postaya 6 haneli kod -> doğrula -> otomatik giriş.
// API: POST /api/auth/register, POST /api/auth/verify-email (parola kanıtı), ardından AuthProvider.login (GET /api/admin/me).
// Alan adı kısıtı İSTEMCİDE YOKTUR: karar yalnız sunucudadır (bingol.edu.tr ya da sunucudaki ADMIN_EMAILS listesi);
// reddedilirse sunucunun EMAIL_DOMAIN_NOT_ALLOWED mesajı gösterilir. Yönetici olmayan hesap panele girince "yetkiniz yok" ekranı çıkar.
import { useState, type FormEvent } from 'react';
import { Link, Navigate } from 'react-router-dom';
import { authApi } from '../../api';
import { isApiError } from '../../api/client';
import { useAuth } from '../../auth/AuthProvider';
import { ForbiddenScreen } from '../../auth/ForbiddenScreen';
import { Logo } from '../../components/brand/Logo';
import { ThemeToggle } from '../../components/ThemeToggle';
import { Button, Checkbox, FormField, Icon, Input, PasswordInput } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { errorMessage } from '../../lib/errors';
import { usePageTitle } from '../../lib/hooks';
import { paths } from '../../paths';
import styles from './LoginPage.module.css';

type Step = 'form' | 'code';

export default function AdminRegisterPage() {
  useNoIndex();
  const i18n = useI18n();
  const { t } = i18n;
  const { status, login } = useAuth();
  const [step, setStep] = useState<Step>('form');
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [terms, setTerms] = useState(false);
  const [code, setCode] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);
  const [touched, setTouched] = useState(false);
  usePageTitle(t('admin.reg.title'));

  if (status === 'authenticated') return <Navigate to={paths.admin.dashboard} replace />;
  if (status === 'forbidden') return <ForbiddenScreen />;

  const required = t('admin.reg.required');
  const cleanEmail = email.trim();
  const emailError = touched ? (!cleanEmail ? required : !cleanEmail.includes('@') ? t('admin.reg.invalidEmail') : null) : null;
  const nameError = touched && !name.trim() ? required : null;
  const passError = touched ? (!password ? required : password.length < 8 ? t('admin.reg.passwordShort') : null) : null;
  const termsError = touched && !terms ? t('admin.reg.termsRequired') : null;
  const codeOk = /^\d{6}$/.test(code.trim());

  function fail(err: unknown) {
    setError(
      isApiError(err) && err.status === 429 && !err.retryAfter ? t('admin.login.rateLimited') : errorMessage(i18n, err),
    );
  }

  async function onRegister(e: FormEvent) {
    e.preventDefault();
    setTouched(true);
    setError(null);
    setInfo(null);
    if (!cleanEmail.includes('@') || !name.trim() || password.length < 8 || !terms) return;
    setBusy(true);
    try {
      await authApi.register({
        email: cleanEmail,
        password,
        displayName: name.trim(),
        acceptTerms: true,
        language: 'tr',
      });
      setStep('code');
    } catch (err) {
      fail(err);
    } finally {
      setBusy(false);
    }
  }

  async function onVerify(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setInfo(null);
    if (!codeOk) {
      setTouched(true);
      return;
    }
    setBusy(true);
    try {
      await authApi.verifyEmail({ email: cleanEmail, code: code.trim(), password });
      // Hesap doğrulandı: aynı bilgilerle giriş (rol ADMIN değilse AuthProvider "yetkiniz yok" ekranına düşürür).
      await login(cleanEmail, password);
    } catch (err) {
      fail(err);
    } finally {
      setBusy(false);
    }
  }

  async function onResend() {
    setError(null);
    setInfo(null);
    setBusy(true);
    try {
      await authApi.resendCode(cleanEmail);
      setInfo(t('admin.reg.resent'));
    } catch (err) {
      fail(err);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className={styles.page}>
      <div className={styles.tools}>
        <ThemeToggle />
      </div>
      <main className={styles.center}>
        {step === 'form' ? (
          <form className={styles.card} onSubmit={onRegister} noValidate aria-busy={busy || undefined}>
            <Logo to={paths.site.home} height={32} className={styles.logo} />
            <div className={styles.head}>
              <h1 className={styles.title}>{t('admin.reg.title')}</h1>
              <p className={styles.sub}>{t('admin.reg.subtitle')}</p>
            </div>
            {error && (
              <div className={styles.alert} role="alert">
                <Icon name="alert" size={18} />
                <span>{error}</span>
              </div>
            )}
            <FormField label={t('admin.reg.name')} error={nameError} required>
              <Input name="name" autoComplete="name" value={name} onChange={(e) => setName(e.target.value)} maxLength={80} />
            </FormField>
            <FormField label={t('admin.reg.email')} error={emailError} required>
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
            <FormField label={t('admin.reg.password')} error={passError} hint={t('admin.reg.passwordHint')} required>
              <PasswordInput
                name="password"
                autoComplete="new-password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                dir="ltr"
                showLabel={t('admin.login.showPassword')}
                hideLabel={t('admin.login.hidePassword')}
              />
            </FormField>
            <div>
              <Checkbox
                checked={terms}
                onChange={(e) => setTerms(e.target.checked)}
                label={
                  <>
                    {t('admin.reg.terms')}{' '}
                    <a href={paths.site.legalIndex} target="_blank" rel="noreferrer">
                      {t('admin.reg.termsLink')}
                    </a>
                  </>
                }
              />
              {termsError && (
                <p className={styles.note} role="alert">
                  {termsError}
                </p>
              )}
            </div>
            <Button type="submit" size="lg" fullWidth loading={busy}>
              {busy ? t('admin.reg.submitting') : t('admin.reg.submit')}
            </Button>
            <p className={styles.note}>{t('admin.reg.note')}</p>
          </form>
        ) : (
          <form className={styles.card} onSubmit={onVerify} noValidate aria-busy={busy || undefined}>
            <Logo to={paths.site.home} height={32} className={styles.logo} />
            <div className={styles.head}>
              <h1 className={styles.title}>{t('admin.reg.codeTitle')}</h1>
              <p className={styles.sub}>{t('admin.reg.codeSubtitle', { email: cleanEmail })}</p>
            </div>
            {error && (
              <div className={styles.alert} role="alert">
                <Icon name="alert" size={18} />
                <span>{error}</span>
              </div>
            )}
            {info && (
              <p className={styles.note} role="status">
                {info}
              </p>
            )}
            <FormField label={t('admin.reg.code')} error={touched && !codeOk && code ? t('admin.reg.codeInvalid') : null} required>
              <Input
                name="code"
                autoComplete="one-time-code"
                inputMode="numeric"
                maxLength={6}
                value={code}
                onChange={(e) => setCode(e.target.value.replace(/\D/g, ''))}
                dir="ltr"
              />
            </FormField>
            <Button type="submit" size="lg" fullWidth loading={busy} disabled={!codeOk}>
              {busy ? t('admin.reg.verifying') : t('admin.reg.verify')}
            </Button>
            <Button type="button" variant="ghost" fullWidth disabled={busy} onClick={onResend}>
              {t('admin.reg.resend')}
            </Button>
            <Button
              type="button"
              variant="ghost"
              fullWidth
              disabled={busy}
              onClick={() => {
                setStep('form');
                setCode('');
                setError(null);
                setInfo(null);
              }}
            >
              {t('admin.reg.changeEmail')}
            </Button>
          </form>
        )}
        <Link to={paths.admin.login} className={styles.back}>
          {t('admin.reg.backToLogin')}
        </Link>
      </main>
    </div>
  );
}
