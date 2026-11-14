// SAYFA: Başvuru durumu (/akademisyen/beklemede). Durumlar: NONE (başvuru yok -> form), PENDING (inceleniyor; bilgiler
// `PUT /academician/me` ile düzeltilebilir), REJECTED (gerekçe + düzeltip yeniden başvur: `POST /academician/apply`),
// REVOKED (yetki kaldırıldı; yeniden başvuru sunucuda kapalıdır, gerekçe + iletişim yönlendirmesi). APPROVED -> panel.
import { useState } from 'react';
import { Navigate, useNavigate } from 'react-router-dom';
import * as acad from '../../../api/academician';
import { Logo } from '../../../components/brand/Logo';
import { ThemeToggle } from '../../../components/ThemeToggle';
import { Badge, Button, Icon, useToast } from '../../../components/ui';
import { usePageTitle } from '../../../lib/hooks';
import { ApplyForm } from '../components/ApplyForm';
import { useT } from '../dict';
import { acadPaths } from '../paths';
import page from '../../admin/LoginPage.module.css';
import styles from '../academician.module.css';
import { useAcadAuth, RequireSession } from './AcadAuth';

export default function PendingPage() {
  return (
    <RequireSession>
      <PendingInner />
    </RequireSession>
  );
}

function PendingInner() {
  const t = useT();
  const toast = useToast();
  const navigate = useNavigate();
  const { me, refreshMe, setMe, logout } = useAcadAuth();
  const [editing, setEditing] = useState(false);
  const [checking, setChecking] = useState(false);
  usePageTitle(t('ac.pending.title'));

  if (!me) return null;
  if (me.status === 'APPROVED') return <Navigate to={acadPaths.home} replace />;

  async function check() {
    setChecking(true);
    try {
      const m = await refreshMe();
      if (m?.status === 'APPROVED') navigate(acadPaths.home, { replace: true });
      else toast.info(t('ac.pending.stillWaiting'));
    } finally {
      setChecking(false);
    }
  }

  const apply = async (b: acad.ApplyBody) => {
    const r = await acad.apply(b);
    setMe(await acad.getMe());
    setEditing(false);
    toast.success(r.status === 'APPROVED' ? t('ac.pending.approvedNow') : t('ac.pending.reapplied'));
    if (r.status === 'APPROVED') navigate(acadPaths.home, { replace: true });
  };
  const save = async (b: acad.ApplyBody) => {
    // hata ApplyForm'a gider: hata gösterilir, girdi korunur
    setMe(await acad.updateMe(b));
    setEditing(false);
    toast.success(t('ac.pending.saved'));
  };

  const initial = { title: me.title ?? '', firstName: me.firstName ?? '', lastName: me.lastName ?? '', unit: me.unit ?? '' };
  const status = me.status;

  return (
    <div className={page.page}>
      <div className={page.tools}>
        <ThemeToggle />
      </div>
      <main className={page.center}>
        <section className={`${page.card} ${styles.wideCard}`} aria-labelledby="acad-pending-h">
          <Logo height={32} className={page.logo} />
          <div className={page.head}>
            <h1 id="acad-pending-h" className={page.title}>
              {status === 'NONE' ? t('ac.pending.noneTitle') : t(`ac.pending.${status}.title`)}
            </h1>
            <p className={page.sub}>{status === 'NONE' ? t('ac.pending.noneText') : t(`ac.pending.${status}.text`)}</p>
          </div>

          {status !== 'NONE' && (
            <dl className={styles.facts}>
              <div>
                <dt>{t('ac.pending.name')}</dt>
                <dd>{[me.title, me.firstName, me.lastName].filter(Boolean).join(' ') || '—'}</dd>
              </div>
              <div>
                <dt>{t('ac.apply.unit')}</dt>
                <dd>{me.unit || '—'}</dd>
              </div>
              <div>
                <dt>{t('ac.pending.state')}</dt>
                <dd>
                  <Badge tone={status === 'PENDING' ? 'info' : 'danger'}>{t(`ac.status.${status}`)}</Badge>
                </dd>
              </div>
            </dl>
          )}

          {(status === 'REJECTED' || status === 'REVOKED') && (
            <div className={styles.alertBox} role="note">
              <Icon name="info" size={18} />
              <span>
                <strong>{t('ac.pending.reason')}</strong>{' '}
                {me.rejectReason || t('ac.pending.noReason')}
              </span>
            </div>
          )}

          {status === 'NONE' && (
            <ApplyForm submitLabel={t('ac.pending.apply')} busyLabel={t('ac.pending.applying')} onSubmit={apply} />
          )}

          {status === 'REJECTED' &&
            (editing ? (
              <ApplyForm
                initial={initial}
                submitLabel={t('ac.pending.reapply')}
                busyLabel={t('ac.pending.applying')}
                onSubmit={apply}
                extra={
                  <Button variant="ghost" onClick={() => setEditing(false)}>
                    {t('ac.cancel')}
                  </Button>
                }
              />
            ) : (
              <Button onClick={() => setEditing(true)} leftIcon={<Icon name="pencil" size={18} />}>
                {t('ac.pending.editReapply')}
              </Button>
            ))}

          {status === 'PENDING' &&
            (editing ? (
              <ApplyForm
                initial={initial}
                submitLabel={t('ac.save')}
                busyLabel={t('ac.saving')}
                onSubmit={save}
                extra={
                  <Button variant="ghost" onClick={() => setEditing(false)}>
                    {t('ac.cancel')}
                  </Button>
                }
              />
            ) : (
              <div className={styles.actionsRow}>
                <Button variant="secondary" loading={checking} onClick={() => void check()} leftIcon={<Icon name="activity" size={18} />}>
                  {t('ac.pending.check')}
                </Button>
                <Button variant="ghost" onClick={() => setEditing(true)} leftIcon={<Icon name="pencil" size={18} />}>
                  {t('ac.pending.edit')}
                </Button>
              </div>
            ))}

          {status === 'REVOKED' && (
            <Button variant="secondary" loading={checking} onClick={() => void check()}>
              {t('ac.pending.check')}
            </Button>
          )}

          <Button variant="ghost" onClick={() => void logout().then(() => navigate(acadPaths.login, { replace: true }))}>
            {t('ac.logout')}
          </Button>
        </section>
      </main>
    </div>
  );
}
