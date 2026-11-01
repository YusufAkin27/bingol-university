// Kullanıcı listesi: "Dikkat gerektirenler" şeridi. Her kutu tek tıkla listeyi o kişilere daraltır (süzgeç URL'ye yazılır).
// API: sayılar GET /api/admin/analytics/overview (askıda, doğrulamayan; üst bileşenden gelir) + GET /api/admin/users?role=ADMIN&twoFactor=false&size=1 (yalnız totalItems okunur).
import { useQuery } from '@tanstack/react-query';
import { listUsers } from '../../../api/users';
import { qk } from '../../../api/queryKeys';
import { Icon, Insight, Skeleton } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { attentionItems, type AttentionKind } from './insanData';
import { it } from './insan';
import styles from './insan.module.css';

const ADMIN_NO_2FA = { role: 'ADMIN', twoFactor: false, size: 1, page: 0 } as const;

interface Props {
  suspended: number | undefined;
  unverified: number | undefined;
  loading: boolean;
  /** Şu an listeyi daraltan kutu (aria-pressed). */
  active: AttentionKind | null;
  onPick: (kind: AttentionKind) => void;
}

export function UsersAttention({ suspended, unverified, loading, active, onPick }: Props) {
  const i18n = useI18n();
  const t = it(i18n);
  const { formatNumber } = i18n;
  const admins = useQuery({
    queryKey: qk.users.list({ ...ADMIN_NO_2FA }),
    queryFn: () => listUsers({ ...ADMIN_NO_2FA }),
    staleTime: 60_000,
  });
  const adminsNo2fa = typeof admins.data?.totalItems === 'number' ? admins.data.totalItems : undefined;
  const items = attentionItems({ suspended, unverified, adminsNo2fa });
  const busy = loading || admins.isLoading;

  return (
    <section className={styles.section} aria-labelledby="users-attention-h" data-search-anchor="users-attention">
      <h2 id="users-attention-h" className={styles.h2}>
        {t('admin.insan.attn.title')}
      </h2>
      {busy ? (
        <Skeleton height="4.5rem" width="100%" />
      ) : items.length === 0 ? (
        <Insight tone="good" parts={t('admin.insan.attn.none')} />
      ) : (
        <>
          <Insight tone="warn" parts={t('admin.insan.attn.some')} />
          <div className={styles.attnGrid}>
            {items.map((a) => (
              <button
                key={a.kind}
                type="button"
                className={styles.attn}
                data-tone={a.tone}
                aria-pressed={active === a.kind}
                title={t('admin.insan.attn.open')}
                onClick={() => onPick(a.kind)}
              >
                <span className={styles.attnNum}>{formatNumber(a.count)}</span>
                <span className={styles.attnLabel}>
                  <Icon name={a.tone === 'danger' ? 'alert' : 'info'} size={14} aria-hidden="true" />{' '}
                  {t(`admin.insan.attn.${a.kind}`)}
                </span>
                <span className={styles.attnHint}>{t(`admin.insan.attn.${a.kind}.hint`)}</span>
              </button>
            ))}
          </div>
        </>
      )}
    </section>
  );
}
