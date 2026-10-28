import { useQuery } from '@tanstack/react-query';
import { previewDraft, previewSaved, type MailContent, type MailLang } from '../../../api/adminMail';
import { ErrorState, Spinner } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { useDebouncedValue } from '../../../lib/hooks';
import { Callout } from '../campaigns/shared';
import { mailErrorMessage } from './mailLogic';
import styles from './mail.module.css';

type Source = { kind: 'draft'; content: MailContent } | { kind: 'saved'; id: number; version?: number };

/**
 * Sunucu önizlemesi (tam e-posta belgesi). HTML ASLA sayfaya basılmaz: boş `sandbox` özniteliğiyle
 * (script, form, üst gezinme yok) `iframe srcdoc` içinde gösterilir.
 */
export function TemplatePreview({ lang, source }: { lang: MailLang; source: Source }) {
  const i18n = useI18n();
  const { t } = i18n;
  const draft = source.kind === 'draft' ? source.content : null;
  const debounced = useDebouncedValue(draft, 600);
  const ready = source.kind === 'saved' || (!!debounced && !!debounced.subject.trim() && !!debounced.html.trim());

  const q = useQuery({
    queryKey: ['adminMail', 'preview', lang, source.kind === 'saved' ? [source.id, source.version] : debounced],
    queryFn: () =>
      source.kind === 'saved'
        ? previewSaved(source.id, { lang, version: source.version })
        : previewDraft(lang, debounced as MailContent),
    enabled: ready,
    staleTime: 30_000,
  });

  return (
    <div className={styles.previewBox} aria-live="polite">
      {!ready && <p className={`${styles.previewMsg} ${styles.muted}`}>{t('admin.mail.preview.empty')}</p>}
      {ready && q.isLoading && (
        <div className={styles.previewMsg}>
          <Spinner label={t('common.loading')} />
        </div>
      )}
      {ready && q.isError && (
        <ErrorState compact description={mailErrorMessage(i18n, q.error)} onRetry={() => void q.refetch()} />
      )}
      {ready && q.data && (
        <>
          <div className={styles.previewHead}>
            <span className={styles.muted}>{t('admin.mail.preview.subject')}</span>
            <span className={styles.previewSubject}>{q.data.subject}</span>
          </div>
          {q.data.fallback && (
            <Callout tone="warning" role="status">
              {t('admin.mail.preview.fallback', { lang: q.data.usedLang.toUpperCase() })}
            </Callout>
          )}
          <iframe
            className={styles.previewFrame}
            title={t('admin.mail.preview.frameTitle')}
            sandbox=""
            srcDoc={q.data.html}
          />
        </>
      )}
    </div>
  );
}
