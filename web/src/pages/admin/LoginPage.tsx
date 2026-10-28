import { useNoIndex } from '../../lib/useNoIndex';
// SAYFA: Yönetici girişi (/admin/login): yalnız Türkçe, sade krem zemin, mobil uygulamayla aynı tasarım dili.
// API: POST /api/auth/login, ardından GET /api/admin/me (AuthProvider.login); rol ADMIN değilse "yetkiniz yok" ekranı.
import { useState, type FormEvent } from 'react';
import { Link, Navigate, useLocation } from 'react-router-dom';
import { isApiError } from '../../api/client';
import { isAdminPath } from '../../adminBase';
import { useAuth } from '../../auth/AuthProvider';
import { ForbiddenScreen } from '../../auth/ForbiddenScreen';
import { Logo } from '../../components/brand/Logo';
import { ThemeToggle } from '../../components/ThemeToggle';
import { Button, FormField, Icon, Input, PasswordInput } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { errorMessage } from '../../lib/errors';
import { usePageTitle } from '../../lib/hooks';
import { paths } from '../../paths';
import styles from './LoginPage.module.css';

export default function LoginPage() {
  useNoIndex();
  const i18n = useI18n();
  const { t } = i18n;
  const { status, login } = useAuth();
  const location = useLocation();
  const from = (location.state as { from?: string } | null)?.from;
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [touched, setTouched] = useState(false);
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
      await login(email, password);
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
        </form>
        <Link to={paths.site.home} className={styles.back}>
          {t('admin.login.backToSite')}
        </Link>
      </main>
    </div>
  );
}
