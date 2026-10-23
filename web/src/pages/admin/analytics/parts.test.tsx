import { screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import { jsonResponse, mockFetch } from '../../../test/fetchMock';
import { renderWithProviders } from '../../../test/utils';
import AnalyticsPage from '../AnalyticsPage';
import { BarList, ChartCard, CohortHeat } from './parts';

describe('CohortHeat', () => {
  const today = new Date(2026, 9, 23);
  it('olgun hücrelere yüzde, olgunlaşmamışlara tire yazar', () => {
    renderWithProviders(
      <CohortHeat
        today={today}
        cohorts={[
          { weekStart: '2026-09-07', size: 20, d1: 30, d7: 40, d30: 10 },
          { weekStart: '2026-10-19', size: 41, d1: 60, d7: 0, d30: 0 },
        ]}
      />,
    );
    const rows = screen.getAllByRole('row');
    const old = within(rows[1]).getAllByRole('cell');
    expect(old.map((c) => c.textContent)).toEqual(['20', '%30', '%40', '%10']);
    const fresh = within(rows[2]).getAllByRole('cell');
    expect(fresh.map((c) => c.textContent)).toEqual(['41', '%60', '–', '–']);
  });
});

describe('BarList', () => {
  it('bilinmiyor satırı ayrı biçimlenir ve sayı metin olarak yazılır', () => {
    renderWithProviders(
      <BarList
        ariaLabel="Fakülte"
        items={[
          { key: 'unknown', label: 'Bilinmiyor', value: 5, percent: 50, muted: true },
          { key: 'a', label: 'Ornek A', value: 5, percent: 50 },
        ]}
      />,
    );
    const list = screen.getByRole('list', { name: 'Fakülte' });
    expect(within(list).getAllByRole('listitem')).toHaveLength(2);
    expect(within(list).getByText('Bilinmiyor')).toBeInTheDocument();
  });
});

describe('ChartCard', () => {
  it('"tablo olarak göster" erişilebilir veri tablosunu açar', async () => {
    renderWithProviders(
      <ChartCard
        title="Kayıtlar"
        rows={[{ id: 1, n: 5 }]}
        rowKey={(r) => r.id}
        columns={[{ key: 'n', header: 'Sayı' }]}
      >
        <div>grafik</div>
      </ChartCard>,
    );
    const user = userEvent.setup();
    expect(screen.queryByRole('table')).not.toBeInTheDocument();
    const btn = screen.getByRole('button', { name: 'Tablo olarak göster' });
    expect(btn).toHaveAttribute('aria-expanded', 'false');
    await user.click(btn);
    expect(screen.getByRole('table', { name: 'Kayıtlar' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Tabloyu gizle' })).toHaveAttribute('aria-expanded', 'true');
  });
});

describe('AnalyticsPage', () => {
  it('?tab= ile açılır; veri boşken ve hatada durumlar gösterilir', async () => {
    mockFetch((url) => (url.includes('/retention') ? jsonResponse(200, { cohorts: [] }) : jsonResponse(500, { code: 'X', message: 'x' })));
    renderWithProviders(<AnalyticsPage />, { route: '/admin/analytics?tab=retention' });
    expect(screen.getByRole('tab', { name: 'Tutundurma' })).toHaveAttribute('aria-selected', 'true');
    expect(await screen.findByText('Henüz kohort verisi yok.')).toBeInTheDocument();
    expect(screen.getByText(/KVKK/)).toBeInTheDocument();
  });

  it('hata durumunda tekrar dene düğmesi vardır', async () => {
    mockFetch(() => jsonResponse(500, { code: 'X', message: 'x' }));
    renderWithProviders(<AnalyticsPage />, { route: '/admin/analytics?tab=demographics' });
    expect(await screen.findByRole('button', { name: 'Tekrar dene' })).toBeInTheDocument();
  });
});
