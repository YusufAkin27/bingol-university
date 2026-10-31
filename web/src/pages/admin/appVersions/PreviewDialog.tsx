// Güncelleme ekranı önizlemesi: telefon çerçevesinde, mobil uygulamadaki zorunlu güncelleme ekranının sade taklidi.
// Metin sunucu davranışıyla aynı kuralla seçilir: seçili dil, boşsa Türkçe, o da boşsa uygulamanın varsayılan metni.
import { useState } from 'react';
import type { AppPlatform } from '../../../api/appVersions';
import type { Lang } from '../../../api/types';
import { Icon, Modal } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { hasStoreLink, type StoreInfo } from './lib';
import styles from './appVersions.module.css';

const LANGS: Lang[] = ['tr', 'en', 'ar'];

export function PreviewDialog({
  platform,
  settings,
  store,
  onClose,
}: {
  platform: AppPlatform;
  settings: Record<string, string>;
  store: StoreInfo;
  onClose: () => void;
}) {
  const { t } = useI18n();
  const [lang, setLang] = useState<Lang>('tr');
  const own = (settings[`update_message_${lang}`] ?? '').trim();
  const tr = (settings.update_message_tr ?? '').trim();
  const body = own || tr || t(`admin.uv.preview.defaultBody.${lang}`);
  const shownLang: Lang = own || !tr ? lang : 'tr';
  const linked = hasStoreLink(platform, store);
  const target = /^https:\/\/\S+$/i.test(store.storeUrl.trim())
    ? t('admin.uv.preview.target.custom')
    : platform === 'android'
      ? t('admin.uv.preview.target.play', { pkg: store.androidPackage.trim() || 'tr.com.bukampus.app' })
      : linked
        ? t('admin.uv.preview.target.apple', { id: store.appleAppId.trim() })
        : t('admin.uv.preview.target.none');
  const rtl = lang === 'ar';
  return (
    <Modal
      open
      onClose={onClose}
      size="sm"
      title={t('admin.uv.preview.title', { platform: t(`admin.uv.platform.${platform}`) })}
    >
      <div className={styles.langSwitch} role="group" aria-label={t('admin.uv.preview.lang')}>
        {LANGS.map((l) => (
          <button
            key={l}
            type="button"
            aria-pressed={lang === l}
            className={`${styles.langBtn} ${lang === l ? styles.langBtnOn : ''}`}
            onClick={() => setLang(l)}
          >
            {l.toUpperCase()}
          </button>
        ))}
      </div>
      <div className={styles.phone} lang={lang} dir={rtl ? 'rtl' : 'ltr'} data-testid="uv-phone">
        <div className={styles.phoneIcon} aria-hidden="true">
          <Icon name="download" size={32} />
        </div>
        <h3 className={styles.phoneTitle}>{t(`admin.uv.preview.screenTitle.${lang}`)}</h3>
        <p className={styles.phoneBody} lang={shownLang} data-testid="uv-phone-body">
          {body}
        </p>
        {linked ? (
          <span className={styles.phoneBtn}>{t(`admin.uv.preview.button.${lang}`)}</span>
        ) : (
          <span className={styles.phoneNoLink}>{t(`admin.uv.preview.noLink.${lang}`)}</span>
        )}
      </div>
      <p className={styles.previewTarget}>{t('admin.uv.preview.target', { target })}</p>
    </Modal>
  );
}
