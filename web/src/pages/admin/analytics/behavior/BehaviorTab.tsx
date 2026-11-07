// "Davranış" sekmesi: oturumlar, ekran süreleri, akışlar, eylemler ve (izinliyse) kullanıcı bazlı zaman çizelgesi.
// Alt bölüm `?sub=`, aralık `?from=&to=` (en çok 45 gün), açık kullanıcı `?uid=` adreste durur.
import { useMemo } from 'react';
import { useSearchParams } from 'react-router-dom';
import { usePermGate } from '../../../../auth/permissions';
import { Skeleton, Tabs } from '../../../../components/ui';
import { useI18n } from '../../../../i18n/I18nProvider';
import analytics from '../analytics.module.css';
import styles from './behavior.module.css';
import ActionsSection from './ActionsSection';
import FlowsSection from './FlowsSection';
import OverviewSection from './OverviewSection';
import ScreensSection from './ScreensSection';
import UsersSection from './UsersSection';
import { parseRange } from './format';
import { BehaviorRangeBar } from './shared';

export const SUBS = ['overview', 'screens', 'flows', 'actions', 'users'] as const;
export type SubId = (typeof SUBS)[number];

export function parseSub(v: string | null | undefined, canUsers: boolean): SubId {
  const s = (SUBS as readonly string[]).includes(v ?? '') ? (v as SubId) : 'overview';
  return s === 'users' && !canUsers ? 'overview' : s;
}

export default function BehaviorTab() {
  const { t } = useI18n();
  const [sp, setSp] = useSearchParams();
  // kullanıcı bazlı bölüm users.pii ister (sunucu da denetler). İzin yüklenirken bölüm açılmaz: izinsiz profile 403 gürültüsü/denetim kaydı olmasın
  const gate = usePermGate('users.pii');
  const canUsers = gate !== 'denied';
  const sub = parseSub(sp.get('sub'), canUsers);
  const from = sp.get('from');
  const to = sp.get('to');
  const range = useMemo(() => parseRange(from, to), [from, to]);

  const patch = (changes: Record<string, string | null>) => {
    const next = new URLSearchParams(sp);
    for (const [k, v] of Object.entries(changes)) {
      if (v === null) next.delete(k);
      else next.set(k, v);
    }
    setSp(next, { replace: true });
  };

  const tabs = SUBS.filter((id) => id !== 'users' || canUsers).map((id) => ({
    id,
    label: t(`admin.bh.sub.${id}` as const),
  }));

  return (
    <div className={styles.stack}>
      <p className={analytics.kvkk} role="note">
        <span>{t('admin.bh.kvkk')}</span>
      </p>
      <BehaviorRangeBar value={range} onChange={(r) => patch({ from: r.from, to: r.to, uid: null })} />
      <Tabs
        label={t('admin.bh.sub.label')}
        value={sub}
        onChange={(id) => patch({ sub: id, uid: null })}
        tabs={tabs}
      >
        {sub === 'overview' && <OverviewSection range={range} />}
        {sub === 'screens' && <ScreensSection range={range} />}
        {sub === 'flows' && <FlowsSection range={range} />}
        {sub === 'actions' && <ActionsSection range={range} />}
        {sub === 'users' && gate === 'allowed' && <UsersSection range={range} />}
        {sub === 'users' && gate === 'loading' && <Skeleton height={240} width="100%" radius="var(--radius-sm)" style={{ display: 'block' }} />}
      </Tabs>
    </div>
  );
}
