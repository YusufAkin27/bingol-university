import { Component, type ErrorInfo, type ReactNode } from 'react';
import { ErrorState } from '../components/ui';
import { useI18n } from '../i18n/I18nProvider';
import { classifyError } from '../components/ErrorBoundary';

function Crash({ error, onRetry }: { error: unknown; onRetry: () => void }) {
  const { t } = useI18n();
  const network = classifyError(error) === 'network';
  return (
    <ErrorState
      title={t('admin.route.crashTitle')}
      description={network ? undefined : t('admin.route.crashText')}
      error={network ? new TypeError('network') : undefined}
      // parça yükleme hatasında yeniden çizmek yetmez: sayfa yeniden yüklenir
      onRetry={network ? () => window.location.reload() : onRetry}
    />
  );
}

/**
 * Sayfa düzeyi hata sınırı: bir yönetim sayfası render sırasında çökerse kabuk (yan menü, üst çubuk, arama) ayakta kalır,
 * yalnız içerik alanında "Tekrar dene" gösterilir. Rota değişince (`resetKey`) hata temizlenir.
 */
export class RouteBoundary extends Component<{ children: ReactNode; resetKey: string }, { error: unknown; failed: boolean }> {
  state = { error: null as unknown, failed: false };

  static getDerivedStateFromError(error: unknown) {
    return { error, failed: true };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error('Sayfa render hatası', error, info.componentStack);
  }

  componentDidUpdate(prev: { resetKey: string }) {
    if (this.state.failed && prev.resetKey !== this.props.resetKey) this.setState({ failed: false, error: null });
  }

  render() {
    if (!this.state.failed) return this.props.children;
    return <Crash error={this.state.error} onRetry={() => this.setState({ failed: false, error: null })} />;
  }
}
