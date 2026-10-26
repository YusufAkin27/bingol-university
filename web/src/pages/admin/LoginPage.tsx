import { useNoIndex } from '../../lib/useNoIndex';
// SAYFA: Yönetici girişi (/admin/login) — iskelet tarafından tamamlanmıştır.
// API: POST /api/auth/login, ardından GET /api/admin/me (AuthProvider.login); rol ADMIN değilse "yetkiniz yok" ekranı.
import { useState, type FormEvent } from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { useAuth } from '../../auth/AuthProvider';
import { ForbiddenScreen } from '../../auth/ForbiddenScreen';
import { LanguageSwitcher } from '../../components/LanguageSwitcher';
import { Logo } from '../../components/brand/Logo';
import { ThemeToggle } from '../../components/ThemeToggle';
import { Button, ContourBackdrop, FormField, Icon, Input, PasswordInput } from '../../components/ui';
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
      await login(email, password);
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
      </main>
    </div>
  );
}
