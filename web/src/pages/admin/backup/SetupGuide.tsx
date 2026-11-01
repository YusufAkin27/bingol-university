// Google Drive kurulum rehberi: katlanır numaralı adımlar, kopyalanabilir komut blokları, uyarı kutuları.
// Sayfa hiçbir sır toplamaz: komutlardaki <...> yer tutucudur. Adımlar ve komutlar guide.ts içindedir.
import { useState, type ReactNode } from 'react';
import { Button, CopyButton, Icon } from '../../../components/ui';
import type { I18n } from '../../../i18n/I18nProvider';
import { useSearchReveal } from '../../../search/anchor';
import { Callout } from '../campaigns/shared';
import { gt } from './dict';
import { FAQ_IDS, GUIDE_STEPS, type GuideItem } from './guide';
import styles from './backup.module.css';

const ALL_IDS = [...GUIDE_STEPS.map((s) => s.id), 'faq'];

function CodeBlock({ i18n, caption, code }: { i18n: I18n; caption: string; code: string }) {
  return (
    <figure className={styles.code}>
      <figcaption className={styles.codeHead}>
        <span className={styles.codeCap}>{caption}</span>
        <CopyButton value={code} label={gt(i18n)('admin.gd1.guide.copy', { name: caption })} />
      </figcaption>
      <pre className={styles.pre} tabIndex={0} aria-label={gt(i18n)('admin.gd1.guide.codeLabel', { name: caption })}>
        <code>{code}</code>
      </pre>
    </figure>
  );
}

function Item({ i18n, item }: { i18n: I18n; item: GuideItem }) {
  const text = i18n.td(item.key, item.key);
  if (item.kind === 'text') return <p className={styles.text}>{text}</p>;
  if (item.kind === 'code') return <CodeBlock i18n={i18n} caption={text} code={item.code} />;
  return (
    <Callout tone={item.tone} title={item.titleKey ? i18n.td(item.titleKey, item.titleKey) : undefined}>
      {text}
    </Callout>
  );
}

function Step({
  i18n,
  id,
  open,
  onToggle,
  children,
}: {
  i18n: I18n;
  id: string;
  open: boolean;
  onToggle: () => void;
  children: ReactNode;
}) {
  const title = i18n.td(`admin.gd1.step.${id}.title`, id);
  return (
    <li className={styles.step} data-testid={`gd-step-${id}`} data-search-anchor={`gd-step-${id}`}>
      <h3 className={styles.stepHead}>
        <button
          type="button"
          id={`gd-step-btn-${id}`}
          className={styles.stepBtn}
          aria-expanded={open}
          aria-controls={`gd-step-body-${id}`}
          onClick={onToggle}
        >
          <span>{title}</span>
          <Icon name="chevronDown" size={20} className={styles.chev} aria-hidden="true" />
        </button>
      </h3>
      <div
        id={`gd-step-body-${id}`}
        role="region"
        aria-labelledby={`gd-step-btn-${id}`}
        className={styles.stepBody}
        hidden={!open}
      >
        {children}
      </div>
    </li>
  );
}

/** `connected`: Drive bağlı ve doğrulandıysa rehber kapalı başlar (yalnız başvuru); değilse 0. adım açık. */
export function SetupGuide({ i18n, connected }: { i18n: I18n; connected: boolean }) {
  const t = gt(i18n);
  // null = kullanıcı henüz dokunmadı: varsayılan durum bağlantı durumundan türetilir.
  const [open, setOpen] = useState<Record<string, boolean> | null>(null);
  const isOpen = (id: string) => (open ? !!open[id] : !connected && id === GUIDE_STEPS[0].id);
  const toggle = (id: string) => {
    const base = open ?? Object.fromEntries(ALL_IDS.map((x) => [x, isOpen(x)]));
    setOpen({ ...base, [id]: !base[id] });
  };
  // Arama bir adımı hedefleyince o adım açılır (yan etkisiz, tekrar çağrılabilir).
  useSearchReveal((anchor) => {
    const id = anchor.startsWith('gd-step-') ? anchor.slice('gd-step-'.length) : null;
    if (!id || !ALL_IDS.includes(id)) return;
    setOpen((cur) => {
      const base = cur ?? Object.fromEntries(ALL_IDS.map((x) => [x, !connected && x === GUIDE_STEPS[0].id]));
      return base[id] ? cur : { ...base, [id]: true };
    });
  });
  const setAll = (v: boolean) => setOpen(Object.fromEntries(ALL_IDS.map((x) => [x, v])));

  return (
    <section id="gd-guide" className={styles.section} aria-labelledby="gd-guide-h" data-search-anchor="backup-guide">
      <h2 id="gd-guide-h" className={styles.h2}>
        {t('admin.gd1.guide.heading')}
      </h2>
      {connected ? (
        <Callout tone="info">{t('admin.gd1.guide.done')}</Callout>
      ) : (
        <p className={styles.muted}>{t('admin.gd1.guide.intro')}</p>
      )}
      <div className={styles.toolbar}>
        <Button variant="secondary" size="sm" onClick={() => setAll(true)}>
          {t('admin.gd1.guide.expandAll')}
        </Button>
        <Button variant="secondary" size="sm" onClick={() => setAll(false)}>
          {t('admin.gd1.guide.collapseAll')}
        </Button>
      </div>
      <ol className={styles.steps}>
        {GUIDE_STEPS.map((s) => (
          <Step key={s.id} i18n={i18n} id={s.id} open={isOpen(s.id)} onToggle={() => toggle(s.id)}>
            {s.items.map((it, i) => (
              <Item key={`${s.id}-${i}`} i18n={i18n} item={it} />
            ))}
          </Step>
        ))}
        <Step i18n={i18n} id="faq" open={isOpen('faq')} onToggle={() => toggle('faq')}>
          <dl className={styles.faq}>
            {FAQ_IDS.map((f) => (
              <div key={f}>
                <dt className={styles.faqQ}>{i18n.td(`admin.gd1.faq.${f}.q`, f)}</dt>
                <dd className={styles.faqA}>{i18n.td(`admin.gd1.faq.${f}.a`, f)}</dd>
              </div>
            ))}
          </dl>
        </Step>
      </ol>
    </section>
  );
}
