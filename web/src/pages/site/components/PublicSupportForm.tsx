// "Bize ulaşın" formu (T27). Akış: form -> e-postaya kod -> kod doğrulama -> talep numarası + durum bağlantısı.
// API: POST /api/public/support/tickets, POST /api/public/support/tickets/verify (api/publicSupport.ts).
import { useMutation } from '@tanstack/react-query';
import { useEffect, useRef, useState, type FormEvent, type ReactNode } from 'react';
import { Link } from '../../../components/LocalizedLink';
import {
  DEFAULT_MIN_FILL_SECONDS,
  MESSAGE_MAX,
  MESSAGE_MIN,
  NAME_MAX,
  formTokenStale,
  getPublicFormToken,
  msUntilFillAllowed,
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

interface HeldToken {
  token: string;
  issuedAt: number;
  minFillSeconds: number;
}

const STEPS: Step[] = ['form', 'code', 'done'];

export const trackPath = (token: string) => `/support/track?token=${encodeURIComponent(token)}`;

export function PublicSupportForm() {
  const i18n = useI18n();
  const { t } = i18n;
  const openedAt = useRef(Date.now());
  // Sunucu imzalı form jetonu (T-062): formu açarken alınır, gönderimde `formToken` ile yollanır
  const held = useRef<HeldToken | null>(null);
  const loading = useRef<Promise<HeldToken> | null>(null);
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

  /** Geçerli jeton; yoksa/eskiyse sunucudan yenisini alır (aynı anda tek istek). */
  function ensureToken(): Promise<HeldToken> {
    const cur = held.current;
    if (cur && !formTokenStale(cur.issuedAt, Date.now())) return Promise.resolve(cur);
    if (!loading.current) {
      loading.current = getPublicFormToken()
        .then((r) => {
          const h = { token: r.formToken, issuedAt: Date.now(), minFillSeconds: r.minFillSeconds ?? DEFAULT_MIN_FILL_SECONDS };
          held.current = h;
          return h;
        })
        .finally(() => {
          loading.current = null;
        });
    }
    return loading.current;
  }
  // formu açar açmaz jeton alınır (hata sessizdir; gönderimde yeniden denenir ve hata o zaman gösterilir)
  useEffect(() => {
    void ensureToken().catch(() => undefined);
  }, []);

  const send = useMutation({
    mutationFn: async () => {
      const h = await ensureToken();
      // çok hızlı gönderimi sunucu sessizce düşürür: gerekirse asgari doldurma süresi tamamlanana dek bekle
      const wait = msUntilFillAllowed(h.issuedAt, h.minFillSeconds, Date.now());
      if (wait > 0) await new Promise((res) => setTimeout(res, wait));
      return submitPublicTicket({
        name: name.trim(),
        email: email.trim(),
        category,
        message: message.trim(),
        website,
        elapsedMs: Date.now() - openedAt.current,
        formToken: h.token,
      });
    },
    onSuccess: (r) => {
      held.current = null; // jeton başına en çok 3 gönderim: sonraki gönderim yeni jeton alır
      void ensureToken().catch(() => undefined);
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
    held.current = null;
    void ensureToken().catch(() => undefined);
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

  const frame = (node: ReactNode) => (
    <div className={styles.frame}>
      <ol className={styles.steps} aria-label={t('site.rd06.pubsup.stepsLabel')}>
        {STEPS.map((k, i) => {
          const state = k === step ? 'now' : i < STEPS.indexOf(step) ? 'past' : 'next';
          return (
            <li
              key={k}
              className={`${styles.stepItem} ${styles[state]}`}
              aria-current={state === 'now' ? 'step' : undefined}
            >
              <span className={styles.stepNum} aria-hidden="true">
                {state === 'past' ? <Icon name="check" size={16} /> : i + 1}
              </span>
              <span className={styles.stepText}>
                <span className={styles.stepKicker}>{t('site.rd06.pubsup.step', { n: i + 1 })}</span>
                <span className={styles.stepName}>{t(`site.rd06.pubsup.step${i + 1}` as TranslationKey)}</span>
              </span>
            </li>
          );
        })}
      </ol>
      {node}
    </div>
  );

  if (step === 'done' && result) {
    return frame(
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
      </div>,
    );
  }

  if (step === 'code') {
    return frame(
      <form className={styles.card} onSubmit={onVerify} noValidate>
        <h2 className={shared.h3}>{t('site.pubsup.codeTitle')}</h2>
        <p className={shared.muted}>{t('site.pubsup.codeLead', { email: email.trim(), min: minutes })}</p>
        <FormField label={t('site.pubsup.codeLabel')} required error={codeError ?? (verify.error ? errorMessage(i18n, verify.error) : null)}>
          <Input
            className={`ltr ${styles.code}`}
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
      </form>,
    );
  }

  return frame(
    <form className={styles.card} onSubmit={onSubmit} noValidate aria-labelledby="pubsup-title">
      <header className={styles.head}>
        <h2 id="pubsup-title" className={styles.title}>
          {t('site.pubsup.title')}
        </h2>
        <p className={shared.muted}>{t('site.pubsup.lead')}</p>
        <p className={styles.req}>{t('site.rd06.pubsup.required')}</p>
      </header>
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
      <div className={styles.footer}>
        <p className={styles.privacy}>
          {t('site.pubsup.privacy')}{' '}
          <Link to={paths.site.dataRequest}>{t('site.pubsup.privacyLink')}</Link>
        </p>
        <Button type="submit" size="lg" loading={send.isPending}>
          {t('site.pubsup.submit')}
        </Button>
      </div>
    </form>,
  );
}
