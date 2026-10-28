import { useMutation } from '@tanstack/react-query';
import { useEffect } from 'react';
import { previewAudience } from '../../../api/campaigns';
import type { CampaignAudience, NotificationType } from '../../../api/types';
import { Button, Icon, Spinner } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminErrorMessage, Callout } from './shared';
import styles from './campaigns.module.css';

/** "Alıcıları önizle": sayı, tercihle atlananlar, dil kırılımı, ilk 10 kişi ve bulunamayan girdiler. */
export function AudiencePreviewPanel({
  audience,
  type,
}: {
  audience: CampaignAudience | undefined;
  type: NotificationType;
}) {
  const i18n = useI18n();
  const { t, td, formatNumber } = i18n;
  const m = useMutation({ mutationFn: () => previewAudience(audience!, type) });
  const key = audience ? `${audience.type}|${audience.value ?? ''}|${type}` : '';
  const { reset } = m;
  // kitle/tür değişince eski önizleme geçersizdir
  useEffect(() => reset(), [key, reset]);

  const d = m.data;
  return (
    <div className={styles.stack}>
      <div>
        <Button
          variant="secondary"
          size="sm"
          loading={m.isPending}
          disabled={!audience}
          leftIcon={<Icon name="search" size={16} />}
          onClick={() => m.mutate()}
          data-testid="preview-button"
        >
          {t('admin.campaigns.preview.recipients')}
        </Button>
      </div>
      {m.isPending && <Spinner size="sm" />}
      {m.isError && (
        <Callout tone="danger" role="alert">
          {adminErrorMessage(i18n, m.error)}
        </Callout>
      )}
      {d && (
        <div className={styles.previewBox} data-testid="preview-result">
          <div className={styles.previewStats}>
            <div className={styles.previewStat}>
              <strong>{formatNumber(d.count)}</strong>
              <span className={styles.muted}>{t('admin.campaigns.preview.count')}</span>
            </div>
            <div className={styles.previewStat}>
              <strong>{formatNumber(d.willReceive)}</strong>
              <span className={styles.muted}>{t('admin.campaigns.preview.willReceive')}</span>
            </div>
            <div className={styles.previewStat}>
              <strong>{formatNumber(d.optedOut)}</strong>
              <span className={styles.muted}>{t('admin.campaigns.preview.optedOut')}</span>
            </div>
          </div>
          {Object.keys(d.byLanguage).length > 0 && (
            <p className={styles.muted}>
              {t('admin.campaigns.preview.byLanguage')}:{' '}
              {Object.entries(d.byLanguage)
                .map(([l, n]) => `${td(`admin.campaigns.lang.${l}`, l.toUpperCase())} ${formatNumber(n)}`)
                .join(' · ')}
            </p>
          )}
          {d.sample.length > 0 && (
            <div>
              <p className={styles.fieldLabel}>{t('admin.campaigns.preview.sample', { n: formatNumber(d.sample.length) })}</p>
              <ul className={styles.previewList}>
                {d.sample.map((p) => (
                  <li key={p.id}>
                    {p.displayName || '—'} <span className="ltr">({p.email})</span>
                    {p.language ? ` · ${p.language.toUpperCase()}` : ''}
                  </li>
                ))}
              </ul>
            </div>
          )}
          {d.notFound.length > 0 && (
            <Callout tone="warning" title={t('admin.campaigns.preview.notFound', { n: formatNumber(d.notFound.length) })}>
              <span className="ltr">{d.notFound.join(', ')}</span>
            </Callout>
          )}
        </div>
      )}
    </div>
  );
}
