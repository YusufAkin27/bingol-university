import { Component, type ErrorInfo, type ReactNode } from 'react';
import { translate } from '../i18n';
import { getCurrentLang } from '../i18n/lang';
import { ADMIN_BASE } from '../adminBase';
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

const EYEBROW: Record<ErrorKind, string> = {
  error: 'site.rd10.err.eyebrow.error',
  network: 'site.rd10.err.eyebrow.network',
  maintenance: 'site.rd10.err.eyebrow.maintenance',
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
  'site.rd10.err.eyebrow.error': 'Beklenmeyen hata / Unexpected error',
  'site.rd10.err.eyebrow.network': 'Bağlantı sorunu / Connection problem',
  'site.rd10.err.eyebrow.maintenance': 'Planlı bakım / Planned maintenance',
  'site.rd10.err.linksTitle': 'Yardımcı bağlantılar / Helpful links',
  'site.rd10.err.linksText': 'Bu sırada sitede gezinebilirsiniz. / Meanwhile you can browse the site.',
  'pg.help.title': 'Yardım merkezi / Help center',
  'pg.nav.menu': 'Yemek listesi / Menu',
  'pg.nav.news': 'Haberler / News',
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
    // Yönetim panelinde site bağlantıları gösterilmez
    const inAdmin = typeof window !== 'undefined' && window.location.pathname.startsWith(ADMIN_BASE);
    const links = inAdmin
      ? undefined
      : [
          { href: `/${lang}/help`, label: tr('pg.help.title'), icon: 'help' as const },
          { href: `/${lang}/menu`, label: tr('pg.nav.menu'), icon: 'cup' as const },
          { href: `/${lang}/news`, label: tr('pg.nav.news'), icon: 'news' as const },
        ];
    return (
      <ErrorScreen
        kind={kind}
        title={tr(KEYS[kind].title)}
        text={tr(KEYS[kind].text)}
        retryLabel={tr('common.retry')}
        homeLabel={tr('pg.err.home')}
        eyebrow={tr(EYEBROW[kind])}
        links={links}
        linksTitle={tr('site.rd10.err.linksTitle')}
        linksText={tr('site.rd10.err.linksText')}
        onRetry={() => {
          // Parça yükleme hatalarında yeniden yüklemek gerekir; diğerlerinde önce yeniden çizmeyi dene
          if (kind === 'network') window.location.reload();
          else this.setState({ failed: false, error: null });
        }}
      />
    );
  }
}
