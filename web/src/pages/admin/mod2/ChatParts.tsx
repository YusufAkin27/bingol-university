// Sohbet medyası sayfasının ek parçaları: medya dağılım grafikleri ve güvenli gezinme çubuğu.
import { Button, Checkbox, Icon, RankedBars } from '../../../components/ui';
import { useScrolledPast } from './chatNav';
import { useGt } from './dict';
import { StackedShare } from './StackedShare';
import styles from './mod2.module.css';

export interface ChatMediaCounts {
  imageCount: number;
  videoCount: number;
  viewOnceCount: number;
  deletedMessageMediaCount: number;
  purgedCount: number;
}

/** Fotoğraf/video payı ve dikkat edilecek medya (tek seferlik, silinmiş, temizlenmiş) sıralaması. */
export function ChatMediaCharts({ stats }: { stats: ChatMediaCounts }) {
  const t = useGt();
  const attention = [
    { key: 'viewOnce', label: t('admin.mod2.chat.state.viewOnce'), value: stats.viewOnceCount },
    { key: 'deleted', label: t('admin.mod2.chat.state.deleted'), value: stats.deletedMessageMediaCount },
    { key: 'purged', label: t('admin.mod2.chat.state.purged'), value: stats.purgedCount },
  ].filter((x) => x.value > 0);
  return (
    <section className={styles.chartGrid} aria-label={t('admin.mod2.chat.mediaStatsLabel')}>
      <div className={styles.chartCard} data-search-anchor="chatfeed-split-chart">
        <h2 className={styles.chartTitle}>{t('admin.mod2.chat.splitTitle')}</h2>
        <StackedShare
          ariaLabel={t('admin.mod2.chat.splitTitle')}
          segments={[
            { key: 'img', label: t('admin.mod2.chat.splitImages'), value: stats.imageCount, tone: 'info' },
            { key: 'vid', label: t('admin.mod2.chat.splitVideos'), value: stats.videoCount, tone: 'primary' },
          ]}
        />
      </div>
      <div className={styles.chartCard} data-search-anchor="chatfeed-state-chart">
        <h2 className={styles.chartTitle}>{t('admin.mod2.chat.stateTitle')}</h2>
        <p className={styles.chartHint}>{t('admin.mod2.chat.stateHint')}</p>
        <RankedBars
          items={attention}
          limit={3}
          ariaLabel={t('admin.mod2.chat.stateTitle')}
          emptyLabel={t('admin.mod2.chat.stateNone')}
        />
      </div>
    </section>
  );
}

/** Bulanık gösterim anahtarı + klavye ipucu; sayfa aşağı kayınca "Başa dön" düğmesi. */
export function ChatSafeBar({ safe, onChange }: { safe: boolean; onChange: (v: boolean) => void }) {
  const t = useGt();
  const past = useScrolledPast(900);
  return (
    <div className={styles.safeRow} role="group" aria-label={t('admin.mod2.chat.safeTitle')} data-search-anchor="chatfeed-safe-view">
      <Checkbox label={t('admin.mod2.chat.safeLabel')} checked={safe} onChange={(e) => onChange(e.target.checked)} />
      <p className={styles.safeHint}>{t('admin.mod2.chat.safeHint')}</p>
      <p className={`${styles.safeHint} ${styles.keys}`}>
        <kbd>J</kbd> / <kbd>K</kbd> {t('admin.mod2.chat.keysHint')}
      </p>
      {past && (
        <Button
          variant="secondary"
          className={styles.toTop}
          leftIcon={<Icon name="arrowUp" size={18} aria-hidden="true" />}
          onClick={() => window.scrollTo({ top: 0, behavior: 'smooth' })}
        >
          {t('admin.mod2.chat.top')}
        </Button>
      )}
    </div>
  );
}
