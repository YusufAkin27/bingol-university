// Birim haberleri: hangi birimden kaç duyuru çekilmiş (yatay sıralı çubuklar + tek cümle yorum).
import { useMemo } from 'react';
import type { UnitSource } from '../../../api/adminUnitNews';
import { Card, Insight, RankedBars, type RankedItem } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { gt } from '../icerik/dict';

/** Duyurusu olan kaynaklar, çubuk listesi için. */
export function unitDistribution(sources: UnitSource[]): { items: RankedItem[]; total: number } {
  const items = sources
    .filter((s) => s.announcementCount > 0)
    .map((s) => ({ key: s.code, label: s.name, value: s.announcementCount }));
  return { items, total: items.reduce((n, i) => n + i.value, 0) };
}

export function UnitDistribution({ sources }: { sources: UnitSource[] }) {
  const i18n = useI18n();
  const t = gt(i18n);
  const { formatNumber } = i18n;
  const { items, total } = useMemo(() => unitDistribution(sources), [sources]);
  const top = useMemo(() => [...items].sort((a, b) => b.value - a.value)[0], [items]);
  return (
    <Card title={t('admin.icerik.unit.dist.title')} data-search-anchor="unitnews-distribution" data-testid="unit-distribution">
      <div style={{ display: 'grid', gap: 'var(--space-3)' }}>
        <Insight
          tone="info"
          parts={
            top
              ? t('admin.icerik.unit.dist.insight', { total: formatNumber(total), top: top.label, n: formatNumber(top.value) })
              : t('admin.icerik.unit.dist.insightEmpty')
          }
        />
        {items.length > 0 && (
          <RankedBars
            items={items}
            ariaLabel={t('admin.icerik.unit.dist.label')}
            limit={6}
            showShare
            formatValue={(n) => t('admin.icerik.unit.dist.hint', { n: formatNumber(n) })}
          />
        )}
      </div>
    </Card>
  );
}
