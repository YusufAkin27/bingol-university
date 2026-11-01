import type { CampaignStatus, MailLang, TemplateStatus } from '../../../api/adminMail';
import { Badge, Icon, StatusPill, type IconName } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { campaignTone, templateTone } from './mailLogic';
import styles from './mail.module.css';

const CAMPAIGN_ICON: Record<CampaignStatus, IconName> = {
  DRAFT: 'file',
  SCHEDULED: 'calendar',
  SENDING: 'mail',
  PAUSED: 'alert',
  DONE: 'check',
  CANCELLED: 'x',
  FAILED: 'alert',
};

/** Durum yalnız renkle değil, simge + metinle gösterilir. */
export function TemplateStatusPill({ status }: { status: TemplateStatus }) {
  const { t } = useI18n();
  return (
    <StatusPill tone={templateTone(status)}>
      {t(`admin.mail.tstatus.${status}`)}
    </StatusPill>
  );
}

export function CampaignStatusPill({ status }: { status: CampaignStatus }) {
  const { t } = useI18n();
  return (
    <StatusPill tone={campaignTone(status)}>
      <span className={styles.pillInner}>
        <Icon name={CAMPAIGN_ICON[status]} size={14} aria-hidden="true" />
        {t(`admin.mail.cstatus.${status}`)}
      </span>
    </StatusPill>
  );
}

export function LangBadges({ languages }: { languages: MailLang[] }) {
  const { t } = useI18n();
  return (
    <span className={styles.langBadges}>
      {(['tr', 'en', 'ar'] as MailLang[]).map((l) => {
        const has = languages.includes(l);
        return (
          <Badge key={l} tone={has ? 'primary' : 'neutral'}>
            <span className={has ? undefined : styles.langOff} title={t(has ? 'admin.mail.lang.has' : 'admin.mail.lang.missing')}>
              {has ? l.toUpperCase() : t('admin.v2n.mail.langMissing', { l: l.toUpperCase() })}
              <span className="sr-only"> {t(has ? 'admin.mail.lang.has' : 'admin.mail.lang.missing')}</span>
            </span>
          </Badge>
        );
      })}
    </span>
  );
}

export type ProgressTone = 'info' | 'success' | 'warning' | 'danger' | 'neutral';

/** Kampanya durumundan çubuk rengi: devam eden mavi, biten yeşil, duran sarı, hata kırmızı (kırmızı hata demektir). */
export function progressToneOf(status: string | undefined): ProgressTone {
  if (status === 'DONE') return 'success';
  if (status === 'FAILED') return 'danger';
  if (status === 'PAUSED') return 'warning';
  if (status === 'SENDING') return 'info';
  return 'neutral';
}

export function ProgressBar({ percent, label, tone = 'info' }: { percent: number; label: string; tone?: ProgressTone }) {
  const p = Math.max(0, Math.min(100, Math.round(percent)));
  return (
    <div className={styles.progress} data-tone={tone}>
      <div
        className={styles.progressTrack}
        role="progressbar"
        aria-label={label}
        aria-valuemin={0}
        aria-valuemax={100}
        aria-valuenow={p}
      >
        <div className={styles.progressFill} style={{ inlineSize: `${p}%` }} />
      </div>
      <span className={`${styles.progressText} ltr`}>%{p}</span>
    </div>
  );
}
