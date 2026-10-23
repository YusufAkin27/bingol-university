import { Component, type ErrorInfo, type ReactNode } from 'react';

/** Beklenmeyen render hatalarında boş ekran yerine yeniden yükleme seçeneği gösterir. (Sınıf bileşeni: i18n bağlamı dışında kalır.) */
export class ErrorBoundary extends Component<{ children: ReactNode }, { failed: boolean }> {
  state = { failed: false };

  static getDerivedStateFromError() {
    return { failed: true };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error('Render hatası', error, info.componentStack);
  }

  render() {
    if (!this.state.failed) return this.props.children;
    return (
      <div
        role="alert"
        style={{
          minHeight: '60vh',
          display: 'grid',
          placeItems: 'center',
          padding: '2rem',
          textAlign: 'center',
        }}
      >
        <div>
          <h1 style={{ fontSize: '1.5rem' }}>Bir şeyler ters gitti · Something went wrong · حدث خطأ ما</h1>
          <p style={{ margin: '1rem 0', color: 'var(--text-muted)' }}>
            <button
              type="button"
              onClick={() => window.location.reload()}
              style={{
                minHeight: 42,
                padding: '0 1.25rem',
                borderRadius: 6,
                border: 0,
                background: 'var(--primary)',
                color: 'var(--primary-contrast)',
                fontWeight: 600,
                cursor: 'pointer',
              }}
            >
              Reload
            </button>
          </p>
        </div>
      </div>
    );
  }
}
