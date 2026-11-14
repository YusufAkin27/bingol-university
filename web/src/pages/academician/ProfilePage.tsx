// SAYFA: Profil (/akademisyen/profil). Unvan/ad/soyad/birim düzenleme. API: GET/PUT /api/academician/me.
import * as acad from '../../api/academician';
import { Badge, Card, PageHeader, useToast } from '../../components/ui';
import { usePageTitle } from '../../lib/hooks';
import { useAcadAuth } from './auth/AcadAuth';
import { ApplyForm } from './components/ApplyForm';
import { useT } from './dict';
import styles from './academician.module.css';

export default function ProfilePage() {
  const t = useT();
  const toast = useToast();
  const { me, setMe } = useAcadAuth();
  usePageTitle(t('ac.profile.title'));
  if (!me) return null;

  return (
    <div className={styles.page}>
      <PageHeader title={t('ac.profile.title')} description={t('ac.profile.desc')} />
      <Card
        title={t('ac.profile.cardTitle')}
        actions={
          <Badge tone="success">
            {t(`ac.status.${me.status}`)}
            {me.approvalMode ? ` · ${t(`ac.approval.${me.approvalMode}`)}` : ''}
          </Badge>
        }
      >
        <ApplyForm
          initial={{ title: me.title ?? '', firstName: me.firstName ?? '', lastName: me.lastName ?? '', unit: me.unit ?? '' }}
          submitLabel={t('ac.save')}
          busyLabel={t('ac.saving')}
          onSubmit={async (b) => {
            setMe(await acad.updateMe(b));
            toast.success(t('ac.profile.saved'));
          }}
        />
      </Card>
    </div>
  );
}
