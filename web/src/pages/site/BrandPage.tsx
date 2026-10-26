// SAYFA: Basın / marka kiti (/brand)
// API: yok. Logolar web/public/brand/ altında (brand/dist'ten kopyalanır); kurallar brand/README.md ile tutarlıdır.
import { ButtonLink, Icon } from '../../components/ui';
import type { TranslationKey } from '../../i18n';
import { useI18n } from '../../i18n/I18nProvider';
import { paths } from '../../paths';
import { PageHero } from './components/PageHero';
import { usePageMeta } from './components/usePageMeta';
import shared from './components/site.module.css';
import styles from './BrandPage.module.css';

interface LogoFile {
  file: string;
  name: TranslationKey;
  /** Önizleme zemini */
  bg: 'light' | 'dark' | 'red';
}

export const BRAND_LOGOS: LogoFile[] = [
  { file: 'mark', name: 'pg.brand.logo.mark', bg: 'light' },
  { file: 'horizontal-light', name: 'pg.brand.logo.horizontalLight', bg: 'light' },
  { file: 'horizontal-dark', name: 'pg.brand.logo.horizontalDark', bg: 'dark' },
  { file: 'vertical-light', name: 'pg.brand.logo.verticalLight', bg: 'light' },
  { file: 'vertical-dark', name: 'pg.brand.logo.verticalDark', bg: 'dark' },
  { file: 'horizontal-white', name: 'pg.brand.logo.horizontalWhite', bg: 'red' },
  { file: 'horizontal-black', name: 'pg.brand.logo.horizontalBlack', bg: 'light' },
  { file: 'mark-white', name: 'pg.brand.logo.markWhite', bg: 'red' },
  { file: 'mark-black', name: 'pg.brand.logo.markBlack', bg: 'light' },
];

export const BRAND_COLORS = [
  { id: 'brand', hex: '#F73A2E' },
  { id: 'action', hex: '#C62A20' },
  { id: 'ink', hex: '#171E33' },
  { id: 'bg', hex: '#FAF6F3' },
] as const;

/** public/brand içinde SVG'si de bulunan dosyalar (tek renk sürümler yalnızca PNG). */
const SVG_FILES = new Set(['mark', 'horizontal-light', 'horizontal-dark', 'vertical-light', 'vertical-dark']);

const RULES =[1, 2, 3, 4, 5, 6] as const;

export default function BrandPage() {
  const { t } = useI18n();
  const title = t('pg.brand.title');
  usePageMeta({ title, description: t('pg.brand.meta'), path: paths.site.brand });
  return (
    <>
      <PageHero title={title} lead={t('pg.brand.lead')} crumbs={[{ label: title }]} />
      <section className={`${shared.section} ${shared.sectionTop}`}>
        <div className={`container ${styles.wrap}`}>
          <section aria-labelledby="brand-logos">
            <h2 id="brand-logos" className={shared.h3}>
              {t('pg.brand.logos')}
            </h2>
            <p className={shared.muted}>{t('pg.brand.logosText')}</p>
            <ul className={styles.logos}>
              {BRAND_LOGOS.map((l) => {
                const name = t(l.name);
                return (
                  <li key={l.file} className={styles.logo}>
                    <div className={`${styles.preview} ${styles[l.bg]}`}>
                      <img src={`/brand/${l.file}.png`} alt={name} loading="lazy" />
                    </div>
                    <strong>{name}</strong>
                    <span className={styles.dl}>
                      {(['svg', 'png'] as const)
                        .filter((f) => f === 'png' || SVG_FILES.has(l.file))
                        .map((f) => (
                          <a key={f} href={`/brand/${l.file}.${f}`} download>
                            <Icon name="download" size={16} />
                            {t('pg.brand.download', { name, format: f.toUpperCase() })}
                          </a>
                        ))}
                    </span>
                  </li>
                );
              })}
            </ul>
          </section>

          <section aria-labelledby="brand-colors">
            <h2 id="brand-colors" className={shared.h3}>
              {t('pg.brand.colors')}
            </h2>
            <ul className={styles.colors}>
              {BRAND_COLORS.map((c) => (
                <li key={c.id} className={styles.color}>
                  <span className={styles.swatch} style={{ background: c.hex }} aria-hidden="true" />
                  <strong>{t(`pg.brand.color.${c.id}` as TranslationKey)}</strong>
                  <code className="ltr">{c.hex}</code>
                  <span className={shared.muted}>{t(`pg.brand.color.${c.id}Use` as TranslationKey)}</span>
                </li>
              ))}
            </ul>
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

          <section aria-labelledby="brand-press">
            <h2 id="brand-press" className={shared.h3}>
              {t('pg.brand.pressTitle')}
            </h2>
            <p className={shared.muted}>{t('pg.brand.pressText')}</p>
            <ButtonLink to={paths.site.contact}>{t('site.nav.contact')}</ButtonLink>
          </section>
        </div>
      </section>
    </>
  );
}
