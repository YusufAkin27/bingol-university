// Gönderi denetimi ek parçaları: durum dağılımı, liste/ızgara görünüm anahtarı ve fotoğraf ızgarası.
// Izgara: bir bakışta çok gönderi (fotoğraf ağırlıklı); karta dokununca ayrıntı çekmecesi açılır. Medya yetkili uçtan blob alınır.
import type { AdminPostRow, AdminPostStats } from '../../../api/adminPosts';
import { useI18n } from '../../../i18n/I18nProvider';
import { useBlobUrl } from '../chat/useBlobUrl';
import { excerpt } from '../posts/postsLogic';
import { StatusBadges } from '../posts/PostParts';
import { useGt } from './dict';
import { StackedShare, type ShareSegment } from './StackedShare';
import styles from './mod2.module.css';

export type PostView = 'list' | 'grid';

/** Yayında / gizli / silinmiş payı. `postCount` silinmişleri içermez, gizliler içerir (sunucu sözleşmesi). */
export function postStateSegments(s: Pick<AdminPostStats, 'postCount' | 'hiddenCount' | 'deletedCount'>, label: (k: string) => string): ShareSegment[] {
  return [
    { key: 'visible', label: label('visible'), value: Math.max(0, s.postCount - s.hiddenCount), tone: 'success' },
    { key: 'hidden', label: label('hidden'), value: s.hiddenCount, tone: 'warning' },
    { key: 'deleted', label: label('deleted'), value: s.deletedCount, tone: 'danger' },
  ];
}

export function PostStateChart({ stats }: { stats: AdminPostStats }) {
  const t = useGt();
  const { formatNumber } = useI18n();
  return (
    <div className={styles.chartCard} data-search-anchor="posts-state-chart">
      <h2 className={styles.chartTitle}>{t('admin.mod2.posts.stateTitle')}</h2>
      <p className={styles.chartHint}>{t('admin.mod2.posts.stateHint')}</p>
      <StackedShare
        ariaLabel={t('admin.mod2.posts.stateTitle')}
        segments={postStateSegments(stats, (k) => t(`admin.mod2.posts.state.${k}`))}
      />
      <p className={styles.chartHint}>{t('admin.mod2.posts.totals', { likes: formatNumber(stats.likeCount), media: formatNumber(stats.mediaCount) })}</p>
    </div>
  );
}

export function PostViewSwitch({ value, onChange }: { value: PostView; onChange: (v: PostView) => void }) {
  const t = useGt();
  return (
    <div className={styles.viewSwitch} role="group" aria-label={t('admin.mod2.posts.viewLabel')} data-search-anchor="posts-view">
      {(['list', 'grid'] as const).map((v) => (
        <button key={v} type="button" className={styles.viewBtn} aria-pressed={value === v} onClick={() => onChange(v)}>
          {t(`admin.mod2.posts.view.${v}`)}
        </button>
      ))}
    </div>
  );
}

function GridCell({ post, onOpen }: { post: AdminPostRow; onOpen: () => void }) {
  const { t, formatNumber } = useI18n();
  const gt = useGt();
  const first = post.media[0];
  const { src, failed } = useBlobUrl(first?.thumbUrl ?? null);
  const name = post.author.displayName ?? `#${post.author.id}`;
  const dim = post.hidden || post.deleted;
  return (
    <li className={`${styles.postCell} ${dim ? styles.dimmed : ''}`} data-testid="post-cell">
      <button type="button" className={styles.postBtn} onClick={onOpen} aria-label={gt('admin.mod2.posts.gridOpen', { name })}>
        <span className={styles.postPic}>
          {first && src && !failed ? (
            <img src={src} alt={t('admin.posts.image')} loading="lazy" />
          ) : (
            <span className={styles.postNoPic}>
              {first ? (failed ? t('admin.posts.mediaFailed') : t('admin.posts.image')) : gt('admin.mod2.posts.gridNoMedia')}
            </span>
          )}
          <span className={styles.postFlags}>
            <StatusBadges post={post} />
          </span>
          {post.media.length > 1 && (
            <span className={styles.postMore}>{gt('admin.mod2.posts.gridMore', { n: formatNumber(post.media.length - 1) })}</span>
          )}
        </span>
        <span className={styles.postInfo}>
          <span className={styles.postWho} dir="auto">
            {name}
          </span>
          {post.text && (
            <span className={styles.postText} dir="auto">
              {excerpt(post.text)}
            </span>
          )}
          <span className={styles.postMeta}>{gt('admin.mod2.posts.likesShort', { n: formatNumber(post.likeCount) })}</span>
        </span>
      </button>
    </li>
  );
}

export function PostGrid({ rows, onOpen }: { rows: AdminPostRow[]; onOpen: (id: number) => void }) {
  const t = useGt();
  return (
    <ul className={styles.postGrid} aria-label={t('admin.mod2.posts.gridLabel')} data-testid="post-grid" data-search-anchor="posts-grid">
      {rows.map((p) => (
        <GridCell key={p.id} post={p} onOpen={() => onOpen(p.id)} />
      ))}
    </ul>
  );
}
