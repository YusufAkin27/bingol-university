// E-posta şablonları özeti: durum dağılımı ve yayındaki şablonlarda eksik dil uyarısı.
// API: GET /api/admin/mail/templates?size=50 (liste süzgecinden bağımsız).
import { useQuery } from '@tanstack/react-query';
import { listTemplates, mailKeys, type TemplateStatus } from '../../../api/adminMail';
import {
  StackedShare,
  type ShareSegment,
  type ShareTone,
} from '../../../components/kit/StackedShareIletisim';
import { Insight } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { useIl } from './il';
import { statusCounts } from './logic';
import styles from './iletisim.module.css';

const ORDER: TemplateStatus[] = ['PUBLISHED', 'DRAFT', 'ARCHIVED'];
const TONE: Record<TemplateStatus, ShareTone> = {
  PUBLISHED: 'success',
  DRAFT: 'warning',
  ARCHIVED: 'neutral',
};
const LANGS = ['tr', 'en', 'ar'] as const;

export interface TemplatesOverviewProps {
  status: TemplateStatus | '';
  onStatus: (s: TemplateStatus | '') => void;
}

export function TemplatesOverview({ status, onStatus }: TemplatesOverviewProps) {
  const { td, formatNumber } = useI18n();
  const il = useIl();
  const q = useQuery({
    queryKey: mailKeys.templates({ overview: true, size: 50 }),
    queryFn: () => listTemplates({ size: 50 }),
    staleTime: 30_000,
  });
  const items = q.data?.items ?? [];
  if (q.isLoading)
    return (
      <div
        style={{ minBlockSize: '7rem' }}
        aria-busy="true"
        role="status"
        aria-label={il('admin.il.tp.loading')}
      />
    );
  if (q.isError || items.length === 0) return null;

  const counts = statusCounts(items, ORDER);
  const segments: ShareSegment[] = counts.map((c) => ({
    key: c.key,
    label: td(`admin.mail.tstatus.${c.key}`, c.key),
    value: c.count,
    tone: TONE[c.key as TemplateStatus],
  }));
  // Yayındaki şablonların hangi dili eksik: kullanıcı o dilde mail alacaksa Türkçe'ye düşer
  const published = items.filter((r) => r.status === 'PUBLISHED');
  const missing = published.filter((r) => LANGS.some((l) => !r.languages.includes(l)));
  const pubCount = published.length;

  return (
    <section
      className={styles.spaced}
      data-search-anchor="tpl-summary"
      aria-label={il('admin.il.tp.summary')}
    >
      <Insight
        className={styles.sentence}
        tone={missing.length > 0 ? 'warn' : 'good'}
        parts={
          missing.length > 0
            ? [
                {
                  text: il('admin.il.tp.sentence.missing', {
                    n: formatNumber(missing.length),
                    pub: formatNumber(pubCount),
                  }),
                  tone: 'warn',
                },
              ]
            : [il('admin.il.tp.sentence.ok', { pub: formatNumber(pubCount) })]
        }
      />
      <StackedShare
        segments={segments}
        ariaLabel={il('admin.il.tp.dist.aria', { n: formatNumber(items.length) })}
        selectedKey={status || null}
        onSelect={(k) => onStatus(k === status ? '' : (k as TemplateStatus))}
      />
    </section>
  );
}
