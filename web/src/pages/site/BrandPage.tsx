// SAYFA: Basın / marka kiti (/brand)
// API: GET /api/app/info (contactEmail / supportEmail → basın iletişimi). Logolar web/public/brand/ altındadır
// (brand/dist'ten kopyalanır, bkz. brand/README.md); indirmeler düz <a download> bağlantılarıdır.
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

type Group = 'horizontal' | 'vertical' | 'mark';

interface LogoFile {
  file: string;
  name: TranslationKey;
  group: Group;
  /** Önizleme zemini */
  bg: 'light' | 'dark' | 'red';
  /** Piksel boyutu (PNG) ve dosya boyutları (bayt) */
  w: number;
  h: number;
  pngBytes: number;
  svgBytes?: number;
}

export const BRAND_LOGOS: LogoFile[] = [
  {
    file: 'horizontal-light',
    name: 'pg.brand.logo.horizontalLight',
    group: 'horizontal',
    bg: 'light',
    w: 1965,
    h: 512,
    pngBytes: 45867,
    svgBytes: 69438,
  },
  {
    file: 'horizontal-dark',
    name: 'pg.brand.logo.horizontalDark',
    group: 'horizontal',
    bg: 'dark',
    w: 1965,
    h: 512,
    pngBytes: 46171,
    svgBytes: 69438,
  },
  {
    file: 'horizontal-white',
    name: 'pg.brand.logo.horizontalWhite',
    group: 'horizontal',
    bg: 'red',
    w: 1965,
    h: 512,
    pngBytes: 60612,
  },
  {
    file: 'horizontal-black',
    name: 'pg.brand.logo.horizontalBlack',
    group: 'horizontal',
    bg: 'light',
    w: 1965,
    h: 512,
    pngBytes: 60474,
  },
  {
    file: 'vertical-light',
    name: 'pg.brand.logo.verticalLight',
    group: 'vertical',
    bg: 'light',
    w: 958,
    h: 776,
    pngBytes: 40311,
    svgBytes: 69437,
  },
  {
    file: 'vertical-dark',
    name: 'pg.brand.logo.verticalDark',
    group: 'vertical',
    bg: 'dark',
    w: 958,
    h: 776,
    pngBytes: 40183,
    svgBytes: 69437,
  },
  {
    file: 'mark',
    name: 'pg.brand.logo.mark',
    group: 'mark',
    bg: 'light',
    w: 1024,
    h: 1024,
    pngBytes: 730629,
    svgBytes: 60280,
  },
  {
    file: 'mark-white',
    name: 'pg.brand.logo.markWhite',
    group: 'mark',
    bg: 'red',
    w: 1024,
    h: 1024,
    pngBytes: 247394,
  },
  {
    file: 'mark-black',
    name: 'pg.brand.logo.markBlack',
    group: 'mark',
    bg: 'light',
    w: 1024,
    h: 1024,
    pngBytes: 243622,
  },
];

const GROUPS: Group[] = ['horizontal', 'vertical', 'mark'];

/** `token`: tokens.css değişken adı (web arayüzünde aynı değer bu adla kullanılır). */
export const BRAND_COLORS = [
  { id: 'campus', hex: '#F73A2E', token: '--red-600' },
  { id: 'action', hex: '#C62A20', token: '--red-700' },
  { id: 'deep', hex: '#8E1B13', token: '--red-800' },
  { id: 'soft', hex: '#FDE7E4', token: '--red-100' },
  { id: 'ink', hex: '#171E33', token: '--ink' },
  { id: 'paper', hex: '#FAF6F3', token: '--bg' },
] as const;

/** Tipografi ölçeği (tokens.css ile aynı değerler: --weight-display 800, --text-3xl 36-60 px, --text-base 16 px, --text-xs 13 px). */
const TYPE_SCALE = [
  { id: 'display', spec: 'Inter 800 · 36–60 px' },
  { id: 'body', spec: 'Inter 400 · 16 px' },
  { id: 'caption', spec: 'Inter 400 · 13 px' },
] as const;

const TR_CHARS = 'ğ ü ş ı ö ç İ Ğ Ü Ş Ö Ç';

/** Bölüm başlığı: numara + h2 + açıklama. */
function SecHead({ n, id, title, text }: { n: string; id: string; title: string; text?: string }) {
  return (
    <header className={styles.secHead}>
      <span className={styles.secNum} aria-hidden="true">
        {n}
      </span>
      <h2 id={id} className={shared.h3}>
        {title}
      </h2>
      {text && <p className={shared.muted}>{text}</p>}
    </header>
  );
}

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
          <aside className={styles.notice} aria-labelledby="brand-note">
            <Icon name="shield" size={22} />
            <div>
              <strong id="brand-note">{t('site.rd08.note.title')}</strong>
              <p>{t('site.v3.independent')}</p>
            </div>
          </aside>

          <section aria-labelledby="brand-use">
            <SecHead n="01" id="brand-use" title={t('site.rd08.use.title')} text={t('site.rd08.use.text')} />
            <div className={styles.useGrid}>
              <figure className={`${styles.usePanel} ${styles.light}`}>
                <span className={styles.useTag}>{t('site.rd08.use.primary')}</span>
                <img
                  src="/brand/horizontal-light.svg"
                  alt={t('pg.brand.logo.horizontalLight')}
                  width={1965}
                  height={512}
                  loading="lazy"
                  decoding="async"
                />
                <figcaption>
                  <strong>{t('site.rd08.use.light')}</strong>
                  <span>{t('site.rd08.use.lightText')}</span>
                </figcaption>
              </figure>
              <figure className={`${styles.usePanel} ${styles.dark}`}>
                <span className={styles.useTag}>{t('site.rd08.use.alt')}</span>
                <img
                  src="/brand/horizontal-dark.svg"
                  alt={t('pg.brand.logo.horizontalDark')}
                  width={1965}
                  height={512}
                  loading="lazy"
                  decoding="async"
                />
                <figcaption>
                  <strong>{t('site.rd08.use.dark')}</strong>
                  <span>{t('site.rd08.use.darkText')}</span>
                </figcaption>
              </figure>
            </div>
            <div className={styles.two}>
              <div className={styles.panel}>
                <h3 id="brand-space" className={styles.panelTitle}>
                  {t('pg.brand.space.title')}
                </h3>
                <p className={shared.muted}>{t('pg.brand.space.text')}</p>
                <div className={styles.spaceBox} aria-hidden="true">
                  <div className={styles.spaceInner}>
                    <img src="/brand/horizontal-light.svg" alt="" height={64} loading="lazy" decoding="async" />
                  </div>
                  <span className={`${styles.x} ${styles.xTop}`}>x</span>
                  <span className={`${styles.x} ${styles.xBottom}`}>x</span>
                  <span className={`${styles.x} ${styles.xStart}`}>x</span>
                  <span className={`${styles.x} ${styles.xEnd}`}>x</span>
                </div>
              </div>
              <div className={styles.panel}>
                <h3 className={styles.panelTitle}>{t('pg.brand.min.title')}</h3>
                <p className={shared.muted}>{t('pg.brand.min.text')}</p>
                <ul className={styles.minRow}>
                  <li>
                    <img src="/brand/mark.svg" alt="" width={16} height={16} loading="lazy" decoding="async" />
                    <span>{t('pg.brand.min.mark')}</span>
                  </li>
                  <li>
                    <img src="/brand/horizontal-light.svg" alt="" height={28} loading="lazy" decoding="async" />
                    <span>{t('pg.brand.min.horizontal')}</span>
                  </li>
                  <li>
                    <img src="/brand/vertical-light.svg" alt="" height={64} loading="lazy" decoding="async" />
                    <span>{t('pg.brand.min.vertical')}</span>
                  </li>
                </ul>
              </div>
            </div>
          </section>

          <section aria-labelledby="brand-dont">
            <SecHead n="02" id="brand-dont" title={t('pg.brand.dont.title')} text={t('pg.brand.dont.text')} />
            <ul className={styles.donts}>
              <li className={styles.dont}>
                <div className={`${styles.preview} ${styles.light}`}>
                  <img src="/brand/horizontal-light.svg" alt="" height={56} loading="lazy" decoding="async" />
                  <span className={`${styles.badge} ${styles.badgeOk}`}>
                    <Icon name="check" size={14} />
                    <span className="sr-only">{t('pg.brand.do.label')}</span>
                  </span>
                </div>
                <span>{t('pg.brand.do.label')}</span>
              </li>
              {(['stretch', 'rotate', 'recolor', 'shadow', 'busy'] as const).map((k) => (
                <li key={k} className={styles.dont}>
                  <div className={`${styles.preview} ${k === 'busy' ? styles.red : styles.light}`}>
                    <img
                      className={styles[`bad_${k}`]}
                      src={k === 'busy' ? '/brand/horizontal-light.svg' : '/brand/mark.svg'}
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
            <SecHead n="03" id="brand-colors" title={t('pg.brand.colors')} text={t('pg.brand.colorsText')} />
            <ul className={styles.colors}>
              {BRAND_COLORS.map((c) => (
                <li key={c.id} className={styles.color}>
                  <span className={styles.swatch} style={{ background: c.hex }} aria-hidden="true" />
                  <div className={styles.colorBody}>
                    <strong>{t(`pg.brand.color.${c.id}` as TranslationKey)}</strong>
                    <span className={shared.muted}>{t(`pg.brand.color.${c.id}Use` as TranslationKey)}</span>
                    <dl className={styles.codes}>
                      <div>
                        <dt>HEX</dt>
                        <dd className={styles.hexRow}>
                          <code className="ltr">{c.hex}</code>
                          <CopyButton value={c.hex} label={t('pg.brand.copyHex', { hex: c.hex })} />
                        </dd>
                      </div>
                      <div>
                        <dt>RGB</dt>
                        <dd>
                          <code className="ltr">{hexToRgb(c.hex)}</code>
                        </dd>
                      </div>
                      <div>
                        <dt>{t('site.rd08.color.token')}</dt>
                        <dd>
                          <code className="ltr">{c.token}</code>
                        </dd>
                      </div>
                    </dl>
                    <span className={styles.contrast}>
                      {t(`pg.brand.color.${c.id}Contrast` as TranslationKey)}
                    </span>
                  </div>
                </li>
              ))}
            </ul>
          </section>

          <section aria-labelledby="brand-type">
            <SecHead n="04" id="brand-type" title={t('pg.brand.type.title')} text={t('pg.brand.type.text')} />
            <div className={styles.typeGrid}>
              <div className={`${styles.panel} ${styles.family}`}>
                <span className={styles.typeLabel}>{t('site.rd08.type.family')}</span>
                <p className={styles.aa} aria-hidden="true">
                  Aa
                </p>
                <p className={styles.familyName}>Inter</p>
                <p className={shared.muted}>{t('site.rd08.type.familyText')}</p>
              </div>
              <div className={styles.panel}>
                <span className={styles.typeLabel}>{t('site.rd08.type.scale')}</span>
                <ul className={styles.scale}>
                  {TYPE_SCALE.map((r) => (
                    <li key={r.id} className={styles.scaleRow}>
                      <span className={styles.scaleMeta}>
                        <strong>{t(`site.rd08.type.scale${r.id[0].toUpperCase()}${r.id.slice(1)}` as TranslationKey)}</strong>
                        <code className="ltr">{r.spec}</code>
                      </span>
                      <span className={styles[`sample_${r.id}`]}>
                        {r.id === 'display'
                          ? t('pg.brand.type.displaySample')
                          : r.id === 'body'
                            ? t('pg.brand.type.bodySample')
                            : t('site.rd08.type.captionSample')}
                      </span>
                    </li>
                  ))}
                </ul>
                <div className={styles.chars}>
                  <span className={styles.typeLabel}>{t('site.rd08.type.chars')}</span>
                  <p lang="tr" dir="ltr">
                    {TR_CHARS}
                  </p>
                </div>
              </div>
            </div>
          </section>

          <section aria-labelledby="brand-logos">
            <SecHead
              n="05"
              id="brand-logos"
              title={t('site.rd08.assets.title')}
              text={`${t('site.rd08.assets.text')} ${t('pg.brand.logosText')}`}
            />
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

          <section aria-labelledby="brand-rules">
            <SecHead n="06" id="brand-rules" title={t('pg.brand.rules')} />
            <ul className={styles.rules}>
              {RULES.map((n) => (
                <li key={n}>{t(`pg.brand.rule.${n}` as TranslationKey)}</li>
              ))}
            </ul>
          </section>

          <section aria-labelledby="brand-shots">
            <SecHead n="07" id="brand-shots" title={t('site.s2.brand.shotsTitle')} text={t('site.s2.brand.shotsText')} />
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
