import { useEffect, useId, useRef, useState, type ReactNode } from 'react';
import { useI18n } from '../i18n/I18nProvider';
import { acknowledgeCookies, isPrefStorageAllowed, setPrefStorageAllowed } from '../lib/cookieConsent';
import { Button, Icon, Modal } from './ui';
import type { IconName } from './ui/Icon';
import styles from './CookiePrefsModal.module.css';

interface RowProps {
  icon: IconName;
  title: string;
  badge?: string;
  text: string;
  /** Anahtar yoksa satır yalnızca bilgilendirir (kapatılamaz / kullanılmıyor). */
  control?: ReactNode;
}

function Row({ icon, title, badge, text, control }: RowProps) {
  const id = useId();
  return (
    <li className={styles.row}>
      <span className={styles.rowIcon} aria-hidden="true">
        <Icon name={icon} size={20} />
      </span>
      <div className={styles.rowBody}>
        <p className={styles.rowTitle} id={`${id}-t`}>
          {title}
          {badge && <span className={styles.badge}>{badge}</span>}
        </p>
        <p className={styles.rowText} id={`${id}-d`}>
          {text}
        </p>
      </div>
      {control}
    </li>
  );
}

/**
 * Depolama tercihleri. Gerçekte yalnız iki kayıt grubu vardır: zorunlu (`bu.cookies`, kapatılamaz) ve dil/tema
 * hatırlama (`bu.lang`, `bu.theme`, kapatılabilir). Analiz/reklam/izleme yoktur; satır yalnızca bunu bildirir.
 */
export function CookiePrefsModal({ open, onClose }: { open: boolean; onClose: () => void }) {
  const { t } = useI18n();
  const [prefs, setPrefs] = useState(isPrefStorageAllowed);
  const switchId = useId();
  const wasOpen = useRef(open);

  // Yeniden açılışta kayıtlı değeri oku (ilk çizimde başlangıç durumu zaten doğrudur)
  useEffect(() => {
    if (open && !wasOpen.current) setPrefs(isPrefStorageAllowed());
    wasOpen.current = open;
  }, [open]);

  const save = () => {
    setPrefStorageAllowed(prefs);
    acknowledgeCookies();
    onClose();
  };

  return (
    <Modal
      open={open}
      onClose={onClose}
      title={t('site.rd10.modal.title')}
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            {t('site.rd10.modal.cancel')}
          </Button>
          <Button onClick={save}>{t('site.rd10.modal.save')}</Button>
        </>
      }
    >
      <p className={styles.lead}>{t('site.rd10.modal.lead')}</p>
      <ul className={styles.list}>
        <Row
          icon="lock"
          title={t('site.rd10.modal.necessary')}
          badge={t('site.rd10.modal.necessaryBadge')}
          text={t('site.rd10.modal.necessaryText')}
          control={
            <span className={`${styles.switch} ${styles.locked}`} aria-hidden="true">
              <span className={styles.knob} />
            </span>
          }
        />
        <Row
          icon="settings"
          title={t('site.rd10.modal.prefs')}
          text={t('site.rd10.modal.prefsText')}
          control={
            <label className={styles.switchWrap} htmlFor={switchId}>
              <span className="sr-only">{t('site.rd10.modal.prefs')}</span>
              <input
                id={switchId}
                type="checkbox"
                role="switch"
                className={styles.input}
                checked={prefs}
                onChange={(e) => setPrefs(e.target.checked)}
              />
              <span className={styles.switch} aria-hidden="true">
                <span className={styles.knob} />
              </span>
            </label>
          }
        />
        <Row
          icon="eyeOff"
          title={t('site.rd10.modal.tracking')}
          badge={t('site.rd10.modal.trackingBadge')}
          text={t('site.rd10.modal.trackingText')}
        />
      </ul>
    </Modal>
  );
}
