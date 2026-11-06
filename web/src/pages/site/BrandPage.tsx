// SAYFA: Basın / marka kiti (/brand)
// API: GET /api/app/info (contactEmail / supportEmail → basın iletişimi). Logolar web/public/brand/ altındadır
// (web/scripts/build-brand.py üretir; kaynak dark_logo.png / light_logo.png); indirmeler düz <a download> bağlantılarıdır.
import { ButtonLink, CopyButton, Icon } from '../../components/ui';
import { useAppInfo } from '../../api/hooks';
import type { TranslationKey } from '../../i18n';
import { useI18n } from '../../i18n/I18nProvider';
import { paths } from '../../paths';
import { PageHero } from './components/PageHero';
import { PhoneMockup } from './components/PhoneMockup';
import { Reveal } from './components/Reveal';
import type { ShotId } from './components/screenshots';
import { usePageMeta } from './components/usePageMeta';
import shared from './components/site.module.css';
import styles from './BrandPage.module.css';

type Group = 'mark' | 'square';

interface LogoFile {
  file: string;
  name: TranslationKey;
  group: Group;
  /** Önizleme zemini */
  bg: 'light' | 'dark';
  /** Piksel boyutu (PNG) ve dosya boyutları (bayt) */
  w: number;
  h: number;
  pngBytes: number;
  svgBytes?: number;
}

/** Dosyalar `web/scripts/build-brand.py` ile üretilir (kaynak: dark_logo.png / light_logo.png). */
export const BRAND_LOGOS: LogoFile[] = [
  { file: 'mark-light', name: 'pg.brand.logo.markLight', group: 'mark', bg: 'light', w: 512, h: 371, pngBytes: 19437 },
  { file: 'mark-dark', name: 'pg.brand.logo.markDark', group: 'mark', bg: 'dark', w: 512, h: 363, pngBytes: 15863 },
  {
    file: 'square-light',
    name: 'pg.brand.logo.squareLight',
    group: 'square',
    bg: 'light',
    w: 1024,
    h: 1024,
    pngBytes: 11079,
  },
  {
    file: 'square-dark',
    name: 'pg.brand.logo.squareDark',
    group: 'square',
    bg: 'dark',
    w: 1024,
    h: 1024,
    pngBytes: 9055,
  },
];

const GROUPS: Group[] = ['mark', 'square'];

/** Marka siyah-beyazdır; eylem kırmızısı yalnız arayüz vurgusudur (logoda kullanılmaz). */
export const BRAND_COLORS = [
  { id: 'ink', hex: '#09090B' },
  { id: 'paper', hex: '#FFFFFF' },
  { id: 'action', hex: '#C62A20' },
] as const;

const RULES = [1, 2, 3, 4, 5] as const;

/** Basın için uygulama ekranları (gerçek ekran çıktıları, kişisel veri içermez). */
const PRESS_SHOTS: ShotId[] = ['home', 'events', 'chat'];

export function hexToRgb(hex: string): string {
  const n = parseInt(hex.slice(1), 16);
  return `${(n >> 16) & 255}, ${(n >> 8) & 255}, ${n & 255}`;
}

const kb = (bytes: number) => String(Math.max(1, Math.round(bytes / 1024)));

/** Önizleme için hafif olan SVG tercih edilir; yoksa PNG. */
const previewSrc = (l: LogoFile) => `/brand/${l.file}.${l.svgBytes ? 'svg' : 'png'}`;

function Download({ l, format }: { l: LogoFile; format: 'png' | 'svg' }) {
  const { t } = useI18n();
  const name = t(l.name);
  const meta =
    format === 'png'
      ? t('pg.brand.pngMeta', { w: l.w, h: l.h, kb: kb(l.pngBytes) })
      : t('pg.brand.svgMeta', { kb: kb(l.svgBytes ?? 0) });
  return (
    <a
      className={styles.dlBtn}
      href={`/brand/${l.file}.${format}`}
      download={`bu-kampus-${l.file}.${format}`}
      aria-label={`${t('pg.brand.download', { name, format: format.toUpperCase() })} — ${meta}`}
    >
      <Icon name="download" size={16} />
      <span className={styles.dlText}>
        <strong>{format.toUpperCase()}</strong>
        <small dir="ltr">{meta.replace(/^(PNG|SVG) · /, '')}</small>
      </span>
    </a>
  );
}

export default function BrandPage() {
  const { t } = useI18n();
  const info = useAppInfo();
  const email = info.data?.contactEmail || info.data?.supportEmail || null;
  const title = t('pg.brand.title');
  usePageMeta({ route: 'brand' });
  return (
    <>
      <PageHero eyebrow={t('site.v3.eyebrow')} title={title} lead={t('pg.brand.lead')} crumbs={[{ label: title }]} />
      <section className={`${shared.section} ${shared.sectionTop}`}>
        <div className={`container ${styles.wrap}`}>
          <section aria-labelledby="brand-logos">
            <h2 id="brand-logos" className={shared.h3}>
              {t('pg.brand.logos')}
            </h2>
            <p className={shared.muted}>{t('pg.brand.logosText')}</p>
            {GROUPS.map((g) => (
              <div key={g} className={styles.group}>
                <h3 className={styles.groupTitle}>{t(`pg.brand.group.${g}` as TranslationKey)}</h3>
                <p className={shared.muted}>{t(`pg.brand.group.${g}Text` as TranslationKey)}</p>
                <ul className={styles.logos}>
                  {BRAND_LOGOS.filter((l) => l.group === g).map((l) => {
                    const name = t(l.name);
                    return (
                      <li key={l.file} className={styles.logo}>
                        <div className={`${styles.preview} ${styles[l.bg]}`}>
                          <img src={previewSrc(l)} alt={name} width={l.w} height={l.h} loading="lazy" />
                        </div>
                        <strong>{name}</strong>
                        <span className={styles.dl}>
                          <Download l={l} format="png" />
                          {l.svgBytes && <Download l={l} format="svg" />}
                        </span>
                      </li>
                    );
                  })}
                </ul>
              </div>
            ))}
          </section>

          <section aria-labelledby="brand-space" className={styles.two}>
            <div className={styles.panel}>
              <h2 id="brand-space" className={shared.h3}>
                {t('pg.brand.space.title')}
              </h2>
              <p className={shared.muted}>{t('pg.brand.space.text')}</p>
              <div className={styles.spaceBox} aria-hidden="true">
                <div className={styles.spaceInner}>
                  <img src="/brand/mark-light.png" alt="" height={64} loading="lazy" decoding="async" />
                </div>
                <span className={`${styles.x} ${styles.xTop}`}>x</span>
                <span className={`${styles.x} ${styles.xBottom}`}>x</span>
                <span className={`${styles.x} ${styles.xStart}`}>x</span>
                <span className={`${styles.x} ${styles.xEnd}`}>x</span>
              </div>
            </div>
            <div className={styles.panel}>
              <h2 className={shared.h3}>{t('pg.brand.min.title')}</h2>
              <p className={shared.muted}>{t('pg.brand.min.text')}</p>
              <ul className={styles.minRow}>
                <li>
                  <img src="/brand/mark-light.png" alt="" width={22} height={16} loading="lazy" decoding="async" />
                  <span>{t('pg.brand.min.mark')}</span>
                </li>
                <li>
                  <img src="/brand/square-light.png" alt="" width={48} height={48} loading="lazy" decoding="async" />
                  <span>{t('pg.brand.min.square')}</span>
                </li>
              </ul>
            </div>
          </section>

          <section aria-labelledby="brand-dont">
            <h2 id="brand-dont" className={shared.h3}>
              {t('pg.brand.dont.title')}
            </h2>
            <p className={shared.muted}>{t('pg.brand.dont.text')}</p>
            <ul className={styles.donts}>
              <li className={styles.dont}>
                <div className={`${styles.preview} ${styles.light}`}>
                  <img src="/brand/mark-light.png" alt="" height={56} loading="lazy" decoding="async" />
                  <span className={`${styles.badge} ${styles.badgeOk}`}>
                    <Icon name="check" size={14} />
                    <span className="sr-only">{t('pg.brand.do.label')}</span>
                  </span>
                </div>
                <span>{t('pg.brand.do.label')}</span>
              </li>
              {(['stretch', 'rotate', 'recolor', 'shadow', 'busy'] as const).map((k) => (
                <li key={k} className={styles.dont}>
                  <div className={`${styles.preview} ${k === 'busy' ? styles.busy : styles.light}`}>
                    <img
                      className={styles[`bad_${k}`]}
                      src="/brand/mark-light.png"
                      alt=""
                      loading="lazy"
                      decoding="async"
                      height={56}
                    />
                    <span className={`${styles.badge} ${styles.badgeNo}`}>
                      <Icon name="x" size={14} />
                      <span className="sr-only">{t('pg.brand.dont.label')}</span>
                    </span>
                  </div>
                  <span>{t(`pg.brand.dont.${k}` as TranslationKey)}</span>
                </li>
              ))}
            </ul>
          </section>

          <section aria-labelledby="brand-colors">
            <h2 id="brand-colors" className={shared.h3}>
              {t('pg.brand.colors')}
            </h2>
            <p className={shared.muted}>{t('pg.brand.colorsText')}</p>
            <ul className={styles.colors}>
              {BRAND_COLORS.map((c) => (
                <li key={c.id} className={styles.color}>
                  <span className={styles.swatch} style={{ background: c.hex }} aria-hidden="true" />
                  <div className={styles.colorBody}>
                    <strong>{t(`pg.brand.color.${c.id}` as TranslationKey)}</strong>
                    <span className={styles.hexRow}>
                      <code className="ltr">{c.hex}</code>
                      <CopyButton value={c.hex} label={t('pg.brand.copyHex', { hex: c.hex })} />
                    </span>
                    <code className={`ltr ${styles.rgb}`}>RGB {hexToRgb(c.hex)}</code>
                    <span className={shared.muted}>{t(`pg.brand.color.${c.id}Use` as TranslationKey)}</span>
                    <span className={styles.contrast}>
                      {t(`pg.brand.color.${c.id}Contrast` as TranslationKey)}
                    </span>
                  </div>
                </li>
              ))}
            </ul>
          </section>

          <section aria-labelledby="brand-type">
            <h2 id="brand-type" className={shared.h3}>
              {t('pg.brand.type.title')}
            </h2>
            <p className={shared.muted}>{t('pg.brand.type.text')}</p>
            <div className={styles.two}>
              <div className={styles.panel}>
                <span className={styles.typeLabel}>{t('pg.brand.type.display')}</span>
                <p className={styles.specDisplay}>{t('pg.brand.type.displaySample')}</p>
              </div>
              <div className={styles.panel}>
                <span className={styles.typeLabel}>{t('pg.brand.type.body')}</span>
                <p className={styles.specBody}>{t('pg.brand.type.bodySample')}</p>
              </div>
            </div>
          </section>

          <section aria-labelledby="brand-rules">
            <h2 id="brand-rules" className={shared.h3}>
              {t('pg.brand.rules')}
            </h2>
            <ul className={styles.rules}>
              {RULES.map((n) => (
                <li key={n}>{t(`pg.brand.rule.${n}` as TranslationKey)}</li>
              ))}
            </ul>
          </section>

          <section aria-labelledby="brand-shots">
            <h2 id="brand-shots" className={shared.h3}>
              {t('site.s2.brand.shotsTitle')}
            </h2>
            <p className={shared.muted}>{t('site.s2.brand.shotsText')}</p>
            <ul className={styles.shots}>
              {PRESS_SHOTS.map((id, i) => (
                <li key={id}>
                  <Reveal delay={i * 80}>
                    <PhoneMockup shot={id} width="min(42vw, 200px)" />
                  </Reveal>
                </li>
              ))}
            </ul>
          </section>

          <section aria-labelledby="brand-press" className={styles.press}>
            <h2 id="brand-press" className={shared.h3}>
              {t('pg.brand.pressTitle')}
            </h2>
            <p className={shared.muted}>{t('pg.brand.pressText')}</p>
            <div className={styles.pressActions}>
              {email && (
                <a className={styles.mail} href={`mailto:${email}`}>
                  <Icon name="mail" size={18} />
                  <span dir="ltr">{email}</span>
                </a>
              )}
              <ButtonLink to={paths.site.contact} variant={email ? 'secondary' : 'primary'}>
                {t('pg.brand.pressContact')}
              </ButtonLink>
            </div>
          </section>
        </div>
      </section>
    </>
  );
}
