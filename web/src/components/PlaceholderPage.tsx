import type { ReactNode } from 'react';
import { useI18n } from '../i18n/I18nProvider';
import type { TranslationKey } from '../i18n';
import { usePageTitle } from '../lib/hooks';
import { EmptyState, PageHeader } from './ui';

interface Props {
  titleKey: TranslationKey;
  /** Başlığı dinamik olarak ezmek için (örn. /legal/:type) */
  title?: string;
  descriptionKey?: TranslationKey;
  /** 'site': kapsayıcı + dikey boşluk (tanıtım sitesi); 'admin': AdminLayout zaten dolgu verir */
  layout?: 'site' | 'admin';
  /** Başlığın altında ek içerik (örn. sekme çubuğu) */
  children?: ReactNode;
}

/**
 * Yapım aşamasındaki sayfalar için tek yer tutucu. Sayfayı doldururken bu bileşeni kaldırıp
 * <PageHeader> + gerçek içerikle değiştirin.
 */
export function PlaceholderPage({ titleKey, title, descriptionKey, layout = 'admin', children }: Props) {
  const { t } = useI18n();
  const heading = title ?? t(titleKey);
  usePageTitle(heading);
  const body = (
    <div data-testid="placeholder-page">
      <PageHeader title={heading} description={descriptionKey ? t(descriptionKey) : undefined} />
      {children}
      <EmptyState
        icon="settings"
        title={t('common.underConstruction.title')}
        description={t('common.underConstruction.hint')}
      />
    </div>
  );
  return layout === 'site' ? (
    <div className="container" style={{ paddingBlock: 'var(--space-7)' }}>
      {body}
    </div>
  ) : (
    body
  );
}
