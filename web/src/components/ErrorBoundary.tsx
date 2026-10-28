import { Component, type ErrorInfo, type ReactNode } from 'react';
import { translate } from '../i18n';
import { getCurrentLang } from '../i18n/lang';
import { ErrorScreen, type ErrorKind } from './ErrorScreen';

interface Props {
  children: ReactNode;
  /** Değişince hata durumu sıfırlanır (örn. rota değişimi). */
  resetKey?: string;
}

const KEYS: Record<ErrorKind, { title: string; text: string }> = {
  error: { title: 'pg.err.title', text: 'pg.err.text' },
  network: { title: 'pg.err.network.title', text: 'pg.err.network.text' },
  maintenance: { title: 'pg.err.maint.title', text: 'pg.err.maint.text' },
};

/** Sözlük parçası yüklenemediyse (ağ koptu) anahtar metni yerine gösterilen sabit yedek (tr + en). */
const FALLBACK: Record<string, string> = {
  'pg.err.title': 'Bir sorun oluştu / Something went wrong',
  'pg.err.text': 'Sayfa yüklenemedi. Lütfen tekrar deneyin. / The page could not be loaded. Please try again.',
  'pg.err.network.title': 'Bağlantı sorunu / Connection problem',
  'pg.err.network.text': 'Ağ bağlantınızı kontrol edip tekrar deneyin. / Check your connection and try again.',
  'pg.err.maint.title': 'Bakımdayız / Under maintenance',
  'pg.err.maint.text': 'Kısa süre sonra tekrar deneyin. / Please try again shortly.',
  'common.retry': 'Tekrar dene / Retry',
  'pg.err.home': 'Ana sayfa / Home',
};

/** Ağ/parça yükleme hatası mı (lazy import başarısız, fetch düştü) yoksa kod hatası mı. */
export function classifyError(error: unknown): ErrorKind {
  const msg = error instanceof Error ? `${error.name} ${error.message}` : String(error);
  if (/MAINTENANCE|Service Unavailable/i.test(msg)) return 'maintenance';
  if (/ChunkLoadError|dynamically imported module|Failed to fetch|NetworkError|Load failed/i.test(msg))
    return 'network';
  return 'error';
}

/**
 * Beklenmeyen render hatalarında boş ekran yerine ortak hata sayfasını ("Tekrar dene" ile) gösterir.
 * Sınıf bileşeni olduğundan i18n bağlamı yerine geçerli dili doğrudan okur.
 */
export class ErrorBoundary extends Component<Props, { error: unknown; failed: boolean }> {
  state = { error: null as unknown, failed: false };

  static getDerivedStateFromError(error: unknown) {
    return { error, failed: true };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error('Render hatası', error, info.componentStack);
  }

  componentDidUpdate(prev: Props) {
    if (this.state.failed && prev.resetKey !== this.props.resetKey)
      this.setState({ failed: false, error: null });
  }

  render() {
    if (!this.state.failed) return this.props.children;
    const lang = getCurrentLang();
    const tr = (key: string) => {
      const v = translate(lang, key);
      return v === key ? (FALLBACK[key] ?? key) : v;
    };
    const kind = classifyError(this.state.error);
    return (
      <ErrorScreen
        kind={kind}
        title={tr(KEYS[kind].title)}
        text={tr(KEYS[kind].text)}
        retryLabel={tr('common.retry')}
        homeLabel={tr('pg.err.home')}
        onRetry={() => {
          // Parça yükleme hatalarında yeniden yüklemek gerekir; diğerlerinde önce yeniden çizmeyi dene
          if (kind === 'network') window.location.reload();
          else this.setState({ failed: false, error: null });
        }}
      />
    );
  }
}
