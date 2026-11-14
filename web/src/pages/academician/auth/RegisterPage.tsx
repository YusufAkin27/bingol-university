// SAYFA: Akademisyen kaydı (/akademisyen/kayit): 1) e-posta + parola -> 2) e-postadaki 6 haneli kod -> 3) unvan/ad/soyad/birim ->
// başvuru. API: POST /api/auth/register (faculty/department/grade GÖNDERİLMEZ), POST /api/auth/verify-email, POST /api/academician/apply.
// Hesap oluşunca oturum açılır (bu.acad.*); 3. adımda kapatılırsa sonraki girişte `beklemede` aynı formu gösterir.
import { useState, type FormEvent } from 'react';
import { Link, Navigate, useNavigate } from 'react-router-dom';
import * as acad from '../../../api/academician';
import * as authApi from '../../../api/auth';
import { Logo } from '../../../components/brand/Logo';
import { ThemeToggle } from '../../../components/ThemeToggle';
import { Button, Checkbox, FormField, Icon, Input, PasswordInput } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { usePageTitle } from '../../../lib/hooks';
import { paths } from '../../../paths';
import { ApplyForm } from '../components/ApplyForm';
import { useT } from '../dict';
import { acadError } from '../errors';
import { acadPaths } from '../paths';
import styles from '../../admin/LoginPage.module.css';
import { useAcadAuth } from './AcadAuth';

/** Sunucudaki genel parola alt sınırı (app.auth.password-min-length, varsayılan 6). */
const MIN_PASSWORD = 6;

export default function AcadRegisterPage() {
  const i18n = useI18n();
  const t = useT();
  const navigate = useNavigate();
  const { status, me, adoptTokens, setMe } = useAcadAuth();
  const [step, setStep] = useState<'form' | 'code'>('form');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [terms, setTerms] = useState(false);
  const [code, setCode] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);
  const [touched, setTouched] = useState(false);
  usePageTitle(t('ac.reg.title'));

  const signedIn = status === 'ready' && me;
  // Oturum var ve başvuru zaten verilmişse (ya da onaylıysa) ilgili sayfaya
  if (signedIn && me.status === 'APPROVED') return <Navigate to={acadPaths.home} replace />;
  if (signedIn && me.status !== 'NONE') return <Navigate to={acadPaths.pending} replace />;
  const profileStep = Boolean(signedIn && me.status === 'NONE');

  const required = t('ac.field.required');
  const cleanEmail = email.trim();
  const emailError = touched ? (!cleanEmail ? required : !cleanEmail.includes('@') ? t('ac.field.invalidEmail') : null) : null;
  const passError = touched ? (!password ? required : password.length < MIN_PASSWORD ? t('ac.reg.passwordShort', { n: MIN_PASSWORD }) : null) : null;
  const termsError = touched && !terms ? t('ac.reg.termsRequired') : null;
  const codeOk = /^\d{6}$/.test(code.trim());

  async function onRegister(e: FormEvent) {
    e.preventDefault();
    setTouched(true);
    setError(null);
    setInfo(null);
    if (!cleanEmail.includes('@') || password.length < MIN_PASSWORD || !terms) return;
    setBusy(true);
    try {
      // fakülte/bölüm/sınıf bilerek gönderilmez: akademisyen öğrenci sinyali taşımamalı (otomatik onay kuralı)
      await authApi.register({ email: cleanEmail, password, acceptTerms: true, language: 'tr' } as authApi.RegisterRequest);
      setStep('code');
    } catch (err) {
      setError(acadError(i18n, err));
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
      const tokens = await authApi.verifyEmail({ email: cleanEmail, code: code.trim(), password });
      await adoptTokens(tokens);
      // oturum açıldı: `profileStep` devreye girer
    } catch (err) {
      setError(acadError(i18n, err));
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
      setInfo(t('ac.reg.resent'));
    } catch (err) {
      setError(acadError(i18n, err));
    } finally {
      setBusy(false);
    }
  }

  async function onApply(b: acad.ApplyBody) {
    const r = await acad.apply(b);
    const fresh = await acad.getMe();
    setMe(fresh);
    navigate(r.status === 'APPROVED' ? acadPaths.home : acadPaths.pending, { replace: true });
  }

  return (
    <div className={styles.page}>
      <div className={styles.tools}>
        <ThemeToggle />
      </div>
      <main className={styles.center}>
        {profileStep ? (
          <section className={styles.card} aria-labelledby="acad-reg-profile">
            <Logo height={32} className={styles.logo} />
            <div className={styles.head}>
              <h1 id="acad-reg-profile" className={styles.title}>
                {t('ac.reg.profileTitle')}
              </h1>
              <p className={styles.sub}>{t('ac.reg.profileSubtitle')}</p>
            </div>
            <ApplyForm submitLabel={t('ac.reg.profileSubmit')} busyLabel={t('ac.reg.profileSubmitting')} onSubmit={onApply} />
          </section>
        ) : step === 'form' ? (
          <form className={styles.card} onSubmit={onRegister} noValidate aria-busy={busy || undefined}>
            <Logo height={32} className={styles.logo} />
            <div className={styles.head}>
              <h1 className={styles.title}>{t('ac.reg.title')}</h1>
              <p className={styles.sub}>{t('ac.reg.subtitle')}</p>
            </div>
            {error && (
              <div className={styles.alert} role="alert">
                <Icon name="alert" size={18} />
                <span>{error}</span>
              </div>
            )}
            <FormField label={t('ac.field.email')} error={emailError} hint={t('ac.reg.emailHint')} required>
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
            <FormField label={t('ac.field.password')} error={passError} required>
              <PasswordInput
                name="password"
                autoComplete="new-password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                dir="ltr"
                showLabel={t('ac.field.showPassword')}
                hideLabel={t('ac.field.hidePassword')}
              />
            </FormField>
            <div>
              <Checkbox
                checked={terms}
                onChange={(e) => setTerms(e.target.checked)}
                label={
                  <>
                    {t('ac.reg.terms')}{' '}
                    <a href={paths.site.legalIndex} target="_blank" rel="noreferrer">
                      {t('ac.reg.termsLink')}
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
              {busy ? t('ac.reg.submitting') : t('ac.reg.submit')}
            </Button>
            <p className={styles.note}>{t('ac.reg.note')}</p>
          </form>
        ) : (
          <form className={styles.card} onSubmit={onVerify} noValidate aria-busy={busy || undefined}>
            <Logo height={32} className={styles.logo} />
            <div className={styles.head}>
              <h1 className={styles.title}>{t('ac.reg.codeTitle')}</h1>
              <p className={styles.sub}>{t('ac.reg.codeSubtitle', { email: cleanEmail })}</p>
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
            <FormField label={t('ac.reg.code')} error={touched && !codeOk ? t('ac.2fa.codeRequired') : null} required>
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
            <Button type="submit" size="lg" fullWidth loading={busy}>
              {busy ? t('ac.reg.verifying') : t('ac.reg.verify')}
            </Button>
            <Button type="button" variant="secondary" fullWidth disabled={busy} onClick={() => void onResend()}>
              {t('ac.reg.resend')}
            </Button>
            <Button
              type="button"
              variant="ghost"
              fullWidth
              onClick={() => {
                setStep('form');
                setCode('');
                setError(null);
                setInfo(null);
              }}
            >
              {t('ac.reg.back')}
            </Button>
            <p className={styles.note}>{t('ac.reg.codeNote')}</p>
          </form>
        )}
        {!profileStep && (
          <Link to={acadPaths.login} className={styles.back}>
            {t('ac.reg.toLogin')}
          </Link>
        )}
        <Link to={paths.site.home} className={styles.back}>
          {t('ac.backToSite')}
        </Link>
      </main>
    </div>
  );
}
