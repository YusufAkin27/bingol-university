import type { Lang } from '../../../api/types';
import { FormField, Input, Tabs, Textarea } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import {
  BODY_MAX,
  LANGS,
  TITLE_MAX,
  contentErrors,
  counterTone,
  type ContentError,
  type LangContent,
} from './lib';
import { CharCounter } from './shared';
import styles from './campaigns.module.css';

/** tr / en / ar sekmeleri; başlık ≤100, metin ≤300 sayaçlı. */
export function ContentEditor({
  lang,
  onLangChange,
  contents,
  onChange,
  showErrors,
}: {
  lang: Lang;
  onLangChange: (l: Lang) => void;
  contents: Record<Lang, LangContent>;
  onChange: (l: Lang, c: LangContent) => void;
  showErrors: boolean;
}) {
  const { t } = useI18n();
  const errors = contentErrors(contents);
  const cur = contents[lang];
  const err: ContentError | undefined = errors[lang];
  const filled = (l: Lang) => !!contents[l].title.trim() && !!contents[l].body.trim();

  const tabs = LANGS.map((l) => ({
    id: l,
    label: (
      <span className={styles.langTab}>
        {t(`admin.campaigns.lang.${l}`)}
        {l === 'tr' && <span className={styles.req}>{t('admin.campaigns.content.required')}</span>}
        <span
          className={`${styles.langDot} ${filled(l) ? styles.langDotOn : ''} ${errors[l] ? styles.langDotErr : ''}`}
          role="img"
          aria-label={t(filled(l) ? 'admin.campaigns.content.filled' : 'admin.campaigns.content.empty')}
        />
      </span>
    ),
  }));

  const isAr = lang === 'ar';
  const titleErr =
    err === 'TOO_LONG' && cur.title.length > TITLE_MAX ? t('admin.campaigns.content.err.TOO_LONG') : null;
  const bodyErr =
    err === 'TOO_LONG' && cur.body.length > BODY_MAX ? t('admin.campaigns.content.err.TOO_LONG') : null;
  const partialErr =
    showErrors && (err === 'TR_REQUIRED' || err === 'PARTIAL')
      ? t(err === 'TR_REQUIRED' ? 'admin.campaigns.content.err.TR_REQUIRED' : 'admin.campaigns.content.err.PARTIAL')
      : null;

  return (
    <div>
      <Tabs tabs={tabs} value={lang} onChange={(id) => onLangChange(id as Lang)} label={t('admin.campaigns.content.langs')} />
      <div className={styles.contentForm} key={lang}>
        <FormField label={t('admin.campaigns.content.title')} error={titleErr ?? partialErr}>
          <Input
            value={cur.title}
            lang={lang}
            dir={isAr ? 'rtl' : 'ltr'}
            onChange={(e) => onChange(lang, { ...cur, title: e.target.value })}
          />
        </FormField>
        <div className={styles.counterRight}>
          <CharCounter length={cur.title.length} max={TITLE_MAX} tone={counterTone(cur.title.length, TITLE_MAX)} />
        </div>
        <FormField label={t('admin.campaigns.content.body')} error={bodyErr}>
          <Textarea
            rows={4}
            value={cur.body}
            lang={lang}
            dir={isAr ? 'rtl' : 'ltr'}
            onChange={(e) => onChange(lang, { ...cur, body: e.target.value })}
          />
        </FormField>
        <div className={styles.counterRight}>
          <CharCounter length={cur.body.length} max={BODY_MAX} tone={counterTone(cur.body.length, BODY_MAX)} />
        </div>
      </div>
    </div>
  );
}
