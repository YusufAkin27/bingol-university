// Operasyon sayfasının üst özeti: trafik ışığı (İyi / Dikkat / Acil) + tek cümle. Sağlık, kuyruk ve yedek sorgularını
// sekmelerle PAYLAŞIR (aynı sorgu anahtarı): ek istek atmaz.
import { Link } from 'react-router-dom';
import { Insight } from '../../../components/ui';
import type { I18n } from '../../../i18n/I18nProvider';
import { paths } from '../../../paths';
import { s1 } from './dict';
import { verdictOf, type OpsSummaryResult } from './logic';
import { TrafficLight } from './Visuals';
import styles from './sistem1.module.css';

export function OpsSummary({ i18n, summary }: { i18n: I18n; summary: OpsSummaryResult }) {
  const t = s1(i18n);
  const v = verdictOf(summary.level);
  const parts: string[] = summary.problems.map((p) => {
    switch (p) {
      case 'health':
        return t('admin.s1.ops.p.health');
      case 'queues':
        return t('admin.s1.ops.p.queues', { n: i18n.formatNumber(summary.deadTotal) });
      case 'backupFailed':
        return t('admin.s1.ops.p.backupFailed');
      case 'backupNever':
        return t('admin.s1.ops.p.backupNever');
      default:
        return t('admin.s1.ops.p.backupStale', { h: i18n.formatNumber(Math.floor(summary.backupHours ?? 0)) });
    }
  });
  const sentence =
    summary.known === 0
      ? t('admin.s1.ops.none')
      : parts.length === 0
        ? t('admin.s1.ops.ok')
        : `${t('admin.s1.ops.bad')} ${parts.join('; ')}.`;
  return (
    <section className={styles.summary} data-verdict={v} aria-label={t('admin.s1.ops.title')} data-testid="ops-summary" data-search-anchor="ops-summary">
      <TrafficLight i18n={i18n} level={summary.level} />
      <div className={styles.summaryText}>
        <h2 className={styles.summaryTitle}>{t('admin.s1.ops.title')}</h2>
        <Insight tone={v === 'good' ? 'good' : v === 'urgent' ? 'bad' : v === 'attention' ? 'warn' : 'neutral'} parts={sentence} />
        <p className={styles.note}>
          {t('admin.s1.ops.more')} <Link to={paths.admin.system}>{t('admin.s1.ops.moreLink')}</Link>
        </p>
      </div>
    </section>
  );
}
