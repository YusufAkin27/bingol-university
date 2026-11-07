// Kullanıcı ayrıntısı: risk özeti. Etkenler gerçek alanlardan türetilir (insanData.computeRisk); renk + simge + metin birlikte.
import type { AdminUserDetail } from '../../../api/types';
import { Card, Icon, Insight, StatusPill } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { computeRisk, type RiskFactor, type RiskLevel } from './insanData';
import { it } from './insan';
import styles from './insan.module.css';

const LEVEL_TONE: Record<RiskLevel, 'danger' | 'warning' | 'info' | 'success' | 'neutral'> = {
  high: 'danger',
  medium: 'warning',
  low: 'info',
  clean: 'success',
  deleted: 'neutral',
};
const INSIGHT_TONE = { high: 'bad', medium: 'warn', low: 'info', clean: 'good', deleted: 'neutral' } as const;

export function UserRiskCard({
  user,
  onGoto,
}: {
  user: AdminUserDetail;
  /** "Şikâyetlere bak" gibi bağlantılar sekme değiştirir. */
  onGoto?: (tab: 'support' | 'security') => void;
}) {
  const i18n = useI18n();
  const t = it(i18n);
  const { formatNumber } = i18n;
  const risk = computeRisk(user);
  const text = (f: RiskFactor) => t(`admin.insan.risk.f.${f.id}`, { n: formatNumber(f.n ?? 0) });
  return (
    <Card title={t('admin.insan.risk.title')} data-search-anchor="ud-risk">
      <div className={styles.cardBody}>
        <div className={styles.riskHead}>
          {risk.level !== 'deleted' && (
            <StatusPill tone={LEVEL_TONE[risk.level]}>{t(`admin.insan.risk.level.${risk.level}`)}</StatusPill>
          )}
        </div>
        <Insight
          tone={INSIGHT_TONE[risk.level]}
          parts={risk.level === 'deleted' ? t('admin.insan.risk.deleted') : t(`admin.insan.risk.sentence.${risk.level}`)}
        />
        {risk.factors.length > 0 && (
          <ul className={styles.riskList}>
            {risk.factors.map((f) => (
              <li key={f.id} className={styles.riskItem} data-tone={f.tone}>
                <Icon name={f.tone === 'info' ? 'info' : 'alert'} size={18} aria-hidden="true" />
                <span className={styles.riskItemText}>{text(f)}</span>
                {f.goto && onGoto && (
                  <button type="button" className={styles.linkBtn} onClick={() => onGoto(f.goto!)}>
                    {t(`admin.insan.risk.go.${f.goto}`)}
                  </button>
                )}
              </li>
            ))}
          </ul>
        )}
      </div>
    </Card>
  );
}
