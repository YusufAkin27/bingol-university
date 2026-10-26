import type { ReactNode } from 'react';
import type { TranslationKey } from '../../../i18n';
import { useI18n } from '../../../i18n/I18nProvider';
import { PageHero } from './PageHero';
import { usePageMeta } from './usePageMeta';
import shared from './site.module.css';
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
  /** Belirli bölümün altına eklenen özel içerik. */
  after?: Record<string, ReactNode>;
}

/** Çeviri anahtarlarından üretilen, bölüm tabanlı bilgi sayfası (çerez, güvenlik, erişilebilirlik vb.). */
export function InfoPage({ slug, path, sections, children, after }: Props) {
  const { t } = useI18n();
  const title = t(k(`pg.${slug}.title`));
  usePageMeta({ title, description: t(k(`pg.${slug}.meta`)), path });
  return (
    <>
      <PageHero title={title} lead={t(k(`pg.${slug}.lead`))} crumbs={[{ label: title }]} />
      <section className={`${shared.section} ${shared.sectionTop}`}>
        <div className={`container ${styles.body}`}>
          {sections.map((s) => (
            <section key={s.id} aria-labelledby={`${slug}-${s.id}`} className={styles.block}>
              <h2 id={`${slug}-${s.id}`} className={shared.h3}>
                {t(k(`pg.${slug}.${s.id}.h`))}
              </h2>
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
                <ol>
                  {Array.from({ length: s.o }, (_, i) => (
                    <li key={i}>{t(k(`pg.${slug}.${s.id}.o${i + 1}`))}</li>
                  ))}
                </ol>
              )}
              {Array.from({ length: s.pAfter ?? 0 }, (_, i) => (
                <p key={`pa${i}`}>{t(k(`pg.${slug}.${s.id}.p${(s.p ?? 0) + i + 1}`))}</p>
              ))}
              {after?.[s.id]}
            </section>
          ))}
          {children}
        </div>
      </section>
    </>
  );
}
