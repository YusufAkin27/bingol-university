// Karar sayfalarında (askı önerisi, itiraz) "Kullanıcı #102" yerine kişinin adı: GET /api/admin/users/{id} (users.read).
// Satır API'si yalnız userId verdiği için sayfa başına en çok ~20 kullanıcı için tek tek sorulur (5 dk önbellek);
// adı alınamazsa (izin yok, silinmiş, hata) "#102" ile eski görünüm korunur. Kalıcı çözüm: liste uçlarının ad döndürmesi (backend gerekir).
import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { qk } from '../../../api/queryKeys';
import { getUser } from '../../../api/users';
import { useCan } from '../../../auth/permissions';
import { Avatar } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { paths } from '../../../paths';
import styles from './people.module.css';

export function UserLabel({ userId, fallback }: { userId: number; fallback: string }) {
  const { t } = useI18n();
  const canRead = useCan('users.read');
  const q = useQuery({
    queryKey: qk.users.detail(userId),
    queryFn: () => getUser(userId),
    enabled: canRead,
    staleTime: 5 * 60_000,
    retry: false,
  });
  // sunucu eksik/boş gövde dönerse (ya da hata) ad yok sayılır: "#id" görünümü korunur
  const u = q.data && typeof q.data.displayName === "string" && q.data.displayName ? q.data : undefined;
  return (
    <Link to={paths.admin.user(userId)} className={styles.userLink}>
      {u ? <Avatar name={u.displayName} src={u.avatarUrl} size={32} /> : null}
      <span className={styles.userText}>
        <strong dir="auto">{u ? u.displayName : fallback}</strong>
        {u && (
          <span className={styles.userSub}>
            #{userId} · {t('admin.v2p.mod.memberFor', { when: u.createdAt ? u.createdAt.slice(0, 10) : '—' })}
          </span>
        )}
      </span>
    </Link>
  );
}
