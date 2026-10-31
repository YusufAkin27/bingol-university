import type { ReactNode } from 'react';
import type { TranslationKey } from '../../../i18n';
import { useI18n } from '../../../i18n/I18nProvider';
import { PageHero } from './PageHero';
import { PointList, type Point } from './PointList';
import { Reveal } from './Reveal';
import { Steps } from './Steps';
import { infoRouteId } from '../../../seo/routeMeta';
import { usePageMeta } from './usePageMeta';
import styles from './InfoPage.module.css';

/** Bölüm tanımı: `p` paragraf, `l` madde, `o` numaralı adım sayısı. Anahtarlar: pg.<slug>.<id>.h | p1.. | l1.. | o1.. */
export interface SectionSpec {
  id: string;
  p?: number;
  l?: number;
  o?: number;
  /** Paragraflardan sonra gelen ikinci paragraf grubu (örn. s3.p2) için başlangıç numarası. */
  pAfter?: number;
}

const k = (s: string) => s as TranslationKey;

/** Bir sayfanın tüm çeviri anahtarları (testlerde üç dilde varlığı doğrulanır). */
export function infoKeys(slug: string, sections: SectionSpec[]): string[] {
  const keys = [`pg.${slug}.title`, `pg.${slug}.lead`, `pg.${slug}.meta`];
  for (const s of sections) {
    keys.push(`pg.${slug}.${s.id}.h`);
    for (let i = 1; i <= (s.p ?? 0) + (s.pAfter ?? 0); i++) keys.push(`pg.${slug}.${s.id}.p${i}`);
    for (let i = 1; i <= (s.l ?? 0); i++) keys.push(`pg.${slug}.${s.id}.l${i}`);
    for (let i = 1; i <= (s.o ?? 0); i++) keys.push(`pg.${slug}.${s.id}.o${i}`);
  }
  return keys;
}

interface Props {
  slug: string;
  path: string;
  sections: SectionSpec[];
  /** Sayfa sonuna eklenen özel içerik (bağlantılar, iletişim vb.). */
  children?: ReactNode;
  /** Bölümlerden önce gösterilen kısa giriş (örn. uygulama/geliştirici satırı). */
  intro?: ReactNode;
  /** Belirli bölümün altına eklenen özel içerik. */
  after?: Record<string, ReactNode>;
  /** Belirli bölümün yanında (>= 860 px) / altında (mobil) gösterilen görsel (örn. telefon). */
  figure?: Record<string, ReactNode>;
  /** "Kısaca": başlığın hemen altındaki simgeli kısa maddeler (yalnız sayfanın kendi metinlerini özetler). */
  highlights?: Point[];
  /** Geniş ekranda yapışkan "Bu sayfada" içindekiler; varsayılan: 5 ve üzeri bölümde açık. */
  toc?: boolean;
}

/** Çeviri anahtarlarından üretilen, bölüm tabanlı bilgi sayfası (çerez, güvenlik, erişilebilirlik vb.). */
export function InfoPage({ slug, sections, children, after, intro, figure, highlights, toc }: Props) {
  const { t } = useI18n();
  const title = t(k(`pg.${slug}.title`));
  usePageMeta({ route: infoRouteId(slug) });
  const showToc = toc ?? sections.length >= 5;
  return (
    <>
      <PageHero title={title} lead={t(k(`pg.${slug}.lead`))} crumbs={[{ label: title }]} />
      {highlights && highlights.length > 0 && (
        <section className={`container ${styles.glance}`} aria-labelledby={`${slug}-glance`}>
          <h2 id={`${slug}-glance`} className={styles.glanceTitle}>
            {t('site.trust.glance')}
          </h2>
          <PointList items={highlights} />
        </section>
      )}
      <div className={`container ${styles.layout} ${showToc ? styles.withToc : ''}`}>
        {showToc && (
          <nav className={styles.toc} aria-label={t('site.trust.toc')}>
            <p className={styles.tocTitle}>{t('site.trust.toc')}</p>
            <ol>
              {sections.map((s) => (
                <li key={s.id}>
                  <a href={`#${slug}-${s.id}`}>{t(k(`pg.${slug}.${s.id}.h`))}</a>
                </li>
              ))}
            </ol>
          </nav>
        )}
        <div className={styles.body}>
          {intro}
          {sections.map((s) => {
            const fig = figure?.[s.id];
            const copy = (
              <div className={styles.copy}>
                {Array.from({ length: s.p ?? 0 }, (_, i) => (
                  <p key={`p${i}`}>{t(k(`pg.${slug}.${s.id}.p${i + 1}`))}</p>
                ))}
                {!!s.l && (
                  <ul>
                    {Array.from({ length: s.l }, (_, i) => (
                      <li key={i}>{t(k(`pg.${slug}.${s.id}.l${i + 1}`))}</li>
                    ))}
                  </ul>
                )}
                {!!s.o && (
                  <Steps
                    stack
                    items={Array.from({ length: s.o }, (_, i) => ({ title: t(k(`pg.${slug}.${s.id}.o${i + 1}`)) }))}
                  />
                )}
                {Array.from({ length: s.pAfter ?? 0 }, (_, i) => (
                  <p key={`pa${i}`}>{t(k(`pg.${slug}.${s.id}.p${(s.p ?? 0) + i + 1}`))}</p>
                ))}
                {after?.[s.id]}
              </div>
            );
            return (
              <section
                key={s.id}
                aria-labelledby={`${slug}-${s.id}`}
                className={`${styles.block} ${fig ? styles.hasFigure : ''}`}
              >
                <h2 id={`${slug}-${s.id}`} className={styles.h2}>
                  {t(k(`pg.${slug}.${s.id}.h`))}
                </h2>
                {fig ? (
                  <div className={styles.split}>
                    {copy}
                    <Reveal className={styles.figure}>{fig}</Reveal>
                  </div>
                ) : (
                  copy
                )}
              </section>
            );
          })}
          {children}
        </div>
      </div>
    </>
  );
}
