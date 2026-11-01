// E-posta kampanyaları özeti: son kampanyaların durum dağılımı ve alıcıların kuyruğa alınma oranı.
// API: GET /api/admin/mail/campaigns?size=50 (liste süzgecinden bağımsız). Açılma/tıklama izi toplanmaz; yalnız
// kuyruğa alınan / atlanan / başarısız alıcı sayıları vardır, bu yüzden "teslim" değil "kuyruğa alınma" oranı gösterilir.
import { useQuery } from '@tanstack/react-query';
import { listMailCampaigns, mailKeys, type CampaignStatus } from '../../../api/adminMail';
import {
  StackedShare,
  type ShareSegment,
  type ShareTone,
} from '../../../components/kit/StackedShareIletisim';
import { Card, Insight, ProgressRing } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { isCampaignLive } from '../mail/mailLogic';
import { useIl } from './il';
import { statusCounts } from './logic';
import styles from './iletisim.module.css';

const ORDER: CampaignStatus[] = ['DRAFT', 'SCHEDULED', 'SENDING', 'PAUSED', 'DONE', 'CANCELLED', 'FAILED'];
const TONE: Record<CampaignStatus, ShareTone> = {
  DRAFT: 'neutral',
  SCHEDULED: 'info',
  SENDING: 'primary',
  PAUSED: 'warning',
  DONE: 'success',
  CANCELLED: 'neutral',
  FAILED: 'danger',
};
const SIZE = 50;

export interface MailCampaignsOverviewProps {
  status: CampaignStatus | '';
  onStatus: (s: CampaignStatus | '') => void;
}

export function MailCampaignsOverview({ status, onStatus }: MailCampaignsOverviewProps) {
  const { td, formatNumber } = useI18n();
  const il = useIl();
  const q = useQuery({
    queryKey: mailKeys.campaigns({ overview: true, size: SIZE }),
    queryFn: () => listMailCampaigns({ size: SIZE }),
    staleTime: 30_000,
    refetchInterval: (query) =>
      query.state.data?.items.some((c) => isCampaignLive(c.status)) ? 5000 : false,
  });
  const items = q.data?.items ?? [];
  if (!q.isLoading && !q.isError && items.length === 0) return null;

  const counts = statusCounts(items, ORDER);
  const segments: ShareSegment[] = counts.map((c) => ({
    key: c.key,
    label: td(`admin.mail.cstatus.${c.key}`, c.key),
    value: c.count,
    tone: TONE[c.key as CampaignStatus],
  }));

  // Gönderim yapılmış (bitmiş ya da sürüyor) kampanyalarda alıcıların kuyruğa alınma oranı
  const sending = items.filter((c) => c.status === 'DONE' || c.status === 'SENDING' || c.status === 'PAUSED');
  const target = sending.reduce((s, c) => s + c.counters.target, 0);
  const queued = sending.reduce((s, c) => s + c.counters.queued, 0);
  const failed = items.reduce((s, c) => s + c.counters.failed, 0);
  const percent = target > 0 ? Math.round((queued / target) * 100) : null;
  const failedCampaigns = counts.find((c) => c.key === 'FAILED')?.count ?? 0;

  const tone = failedCampaigns > 0 || failed > 0 ? ('warn' as const) : ('info' as const);
  const sentence = il(
    failedCampaigns > 0 || failed > 0 ? 'admin.il.mc.sentence.problem' : 'admin.il.mc.sentence.ok',
    {
      n: formatNumber(items.length),
      queued: formatNumber(queued),
      target: formatNumber(target),
      failed: formatNumber(failed),
      campaigns: formatNumber(failedCampaigns),
    },
  );

  return (
    <section data-search-anchor="mc-summary" aria-label={il('admin.il.mc.summary')}>
      {q.data && <Insight className={styles.sentence} tone={tone} parts={sentence} />}
      <div className={styles.grid2}>
        <Card title={il('admin.il.mc.dist.title')} data-search-anchor="mc-status-dist">
          {q.isError ? (
            <p role="alert">{il('admin.il.err.load')}</p>
          ) : (
            <StackedShare
              segments={segments}
              ariaLabel={il('admin.il.mc.dist.aria', { n: formatNumber(items.length) })}
              selectedKey={status || null}
              onSelect={(k) => onStatus(k === status ? '' : (k as CampaignStatus))}
            />
          )}
        </Card>
        <div className={styles.ringBox} data-search-anchor="mc-queued-ring">
          <ProgressRing
            value={percent}
            label={il('admin.il.mc.ring')}
            tone={
              percent === null ? 'neutral' : percent >= 90 ? 'success' : percent >= 60 ? 'warning' : 'danger'
            }
            size={112}
            loading={q.isLoading}
          />
          <p className={styles.panelNote}>{il('admin.il.mc.ringNote')}</p>
        </div>
      </div>
    </section>
  );
}
