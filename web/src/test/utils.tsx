import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { render, type RenderOptions } from '@testing-library/react';
import type { ReactElement, ReactNode } from 'react';
import { MemoryRouter } from 'react-router-dom';
import { ToastProvider } from '../components/ui/Toast';
import { I18nProvider } from '../i18n/I18nProvider';
import type { Lang } from '../i18n/lang';
import { ThemeProvider } from '../lib/theme';

interface Opts extends Omit<RenderOptions, 'wrapper'> {
  route?: string;
  lang?: Lang;
}

/** i18n + tema + toast + react-query + MemoryRouter ile render eder. */
export function renderWithProviders(ui: ReactElement, { route = '/', lang = 'tr', ...rest }: Opts = {}) {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  function Wrapper({ children }: { children: ReactNode }) {
    return (
      <QueryClientProvider client={client}>
        <I18nProvider initialLang={lang}>
          <ThemeProvider>
            <ToastProvider>
              <MemoryRouter initialEntries={[route]}>{children}</MemoryRouter>
            </ToastProvider>
          </ThemeProvider>
        </I18nProvider>
      </QueryClientProvider>
    );
  }
  return { client, ...render(ui, { wrapper: Wrapper, ...rest }) };
}
