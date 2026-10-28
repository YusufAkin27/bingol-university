// "Bize ulaşın" formu (T27). Akış: form -> e-postaya kod -> kod doğrulama -> talep numarası + durum bağlantısı.
// API: POST /api/public/support/tickets, POST /api/public/support/tickets/verify (api/publicSupport.ts).
import { useMutation } from '@tanstack/react-query';
import { useRef, useState, type FormEvent } from 'react';
import { Link } from '../../../components/LocalizedLink';
import {
  MESSAGE_MAX,
  MESSAGE_MIN,
  NAME_MAX,
  submitPublicTicket,
  validatePublicForm,
  verifyPublicTicket,
  type PublicFormErrors,
  type PublicSupportVerified,
} from '../../../api/publicSupport';
import type { TicketCategory } from '../../../api/types';
import { Button, FormField, Icon, Input, Select, Textarea } from '../../../components/ui';
import type { TranslationKey } from '../../../i18n';
import { useI18n } from '../../../i18n/I18nProvider';
import { errorMessage } from '../../../lib/errors';
import { paths } from '../../../paths';
import shared from './site.module.css';
import styles from './PublicSupportForm.module.css';

const CATEGORIES: TicketCategory[] = ['ACCOUNT', 'TECHNICAL', 'CONTENT', 'OTHER'];
type Step = 'form' | 'code' | 'done';

export const trackPath = (token: string) => `/support/track?token=${encodeURIComponent(token)}`;

export function PublicSupportForm() {
  const i18n = useI18n();
  const { t } = i18n;
  const openedAt = useRef(Date.now());
  const [step, setStep] = useState<Step>('form');
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [category, setCategory] = useState<TicketCategory>('TECHNICAL');
  const [message, setMessage] = useState('');
  const [website, setWebsite] = useState('');
  const [errors, setErrors] = useState<PublicFormErrors>({});
  const [code, setCode] = useState('');
  const [codeError, setCodeError] = useState<string | null>(null);
  const [minutes, setMinutes] = useState(10);
  const [result, setResult] = useState<PublicSupportVerified | null>(null);

  const send = useMutation({
    mutationFn: () =>
      submitPublicTicket({
        name: name.trim(),
        email: email.trim(),
        category,
        message: message.trim(),
        website,
        elapsedMs: Date.now() - openedAt.current,
      }),
    onSuccess: (r) => {
      setMinutes(r.expiresInMinutes);
      setCode('');
      setCodeError(null);
      setStep('code');
    },
  });
  const verify = useMutation({
    mutationFn: () => verifyPublicTicket(email.trim(), code.trim()),
    onSuccess: (r) => {
      setResult(r);
      setStep('done');
    },
  });

  function onSubmit(e: FormEvent) {
    e.preventDefault();
    const v = validatePublicForm({ name, email, message });
    setErrors(v);
    if (Object.keys(v).length === 0) send.mutate();
  }
  function onVerify(e: FormEvent) {
    e.preventDefault();
    if (!/^\d{6}$/.test(code.trim())) {
      setCodeError(t('site.pubsup.codeInvalid'));
      return;
    }
    setCodeError(null);
    verify.mutate();
  }
  function reset() {
    setName('');
    setEmail('');
    setMessage('');
    setCategory('TECHNICAL');
    setErrors({});
    setResult(null);
    openedAt.current = Date.now();
    send.reset();
    verify.reset();
    setStep('form');
  }

  const errText = (k: keyof PublicFormErrors): string | null => {
    const v = errors[k];
    if (!v) return null;
    const key = `site.pubsup.err.${k}${v[0].toUpperCase()}${v.slice(1)}` as TranslationKey;
    return t(key, { max: k === 'name' ? NAME_MAX : MESSAGE_MAX, min: MESSAGE_MIN });
  };

  if (step === 'done' && result) {
    return (
      <div className={styles.card} role="status">
        <span className={styles.okIcon}>
          <Icon name="check" size={24} />
        </span>
        <h2 className={shared.h3}>{t('site.pubsup.doneTitle')}</h2>
        <p className={shared.muted}>{t('site.pubsup.doneText', { id: result.ticketId })}</p>
        <div className={styles.actions}>
          <Link to={trackPath(result.trackToken)} className={styles.primaryLink}>
            {t('site.pubsup.doneTrack')}
          </Link>
          <Button variant="ghost" onClick={reset}>
            {t('site.pubsup.doneNew')}
          </Button>
        </div>
      </div>
    );
  }

  if (step === 'code') {
    return (
      <form className={styles.card} onSubmit={onVerify} noValidate>
        <h2 className={shared.h3}>{t('site.pubsup.codeTitle')}</h2>
        <p className={shared.muted}>{t('site.pubsup.codeLead', { email: email.trim(), min: minutes })}</p>
        <FormField label={t('site.pubsup.codeLabel')} required error={codeError ?? (verify.error ? errorMessage(i18n, verify.error) : null)}>
          <Input
            className="ltr"
            inputMode="numeric"
            autoComplete="one-time-code"
            maxLength={6}
            value={code}
            onChange={(e) => setCode(e.target.value.replace(/\D/g, ''))}
          />
        </FormField>
        <div className={styles.actions}>
          <Button type="submit" loading={verify.isPending}>
            {t('site.pubsup.codeSubmit')}
          </Button>
          <Button variant="ghost" onClick={() => setStep('form')}>
            {t('site.pubsup.codeBack')}
          </Button>
        </div>
      </form>
    );
  }

  return (
    <form className={styles.card} onSubmit={onSubmit} noValidate aria-labelledby="pubsup-title">
      <h2 id="pubsup-title" className={shared.h3}>
        {t('site.pubsup.title')}
      </h2>
      <p className={shared.muted}>{t('site.pubsup.lead')}</p>
      <div className={styles.row}>
        <FormField label={t('site.pubsup.name')} required error={errText('name')}>
          <Input value={name} maxLength={NAME_MAX + 20} autoComplete="name" onChange={(e) => setName(e.target.value)} />
        </FormField>
        <FormField label={t('site.pubsup.email')} required error={errText('email')}>
          <Input
            className="ltr"
            type="email"
            autoComplete="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
          />
        </FormField>
      </div>
      <FormField label={t('site.pubsup.category')}>
        <Select value={category} onChange={(e) => setCategory(e.target.value as TicketCategory)}>
          {CATEGORIES.map((c) => (
            <option key={c} value={c}>
              {t(`site.pubsup.category.${c}` as TranslationKey)}
            </option>
          ))}
        </Select>
      </FormField>
      <FormField
        label={t('site.pubsup.message')}
        required
        error={errText('message')}
        hint={
          <span className="ltr">{t('site.pubsup.counter', { n: message.length, max: MESSAGE_MAX })}</span>
        }
      >
        <Textarea
          rows={6}
          dir="auto"
          value={message}
          maxLength={MESSAGE_MAX + 200}
          onChange={(e) => setMessage(e.target.value)}
        />
      </FormField>
      {/* Bal kabağı: insanlara görünmez, botlar doldurur */}
      <div className={styles.hp} aria-hidden="true">
        <label>
          {t('site.pubsup.honeypot')}
          <input type="text" name="website" tabIndex={-1} autoComplete="off" value={website} onChange={(e) => setWebsite(e.target.value)} />
        </label>
      </div>
      {send.error && (
        <p className={styles.error} role="alert">
          {errorMessage(i18n, send.error)}
        </p>
      )}
      <Button type="submit" loading={send.isPending}>
        {t('site.pubsup.submit')}
      </Button>
      <p className={styles.privacy}>
        {t('site.pubsup.privacy')}{' '}
        <Link to={paths.site.dataRequest}>{t('site.pubsup.privacyLink')}</Link>
      </p>
    </form>
  );
}
