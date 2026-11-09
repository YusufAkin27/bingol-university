import { screen, within } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { renderWithProviders } from '../../../../test/utils';
import { userDetailFixture } from './fixtures';
import UserInsightsSection from './UserInsightsSection';

describe('Kullanıcı kullanım ayrıntıları', () => {
  it('tüm sayfaları, günlük kullanımı ve 24 saatlik dağılımı gösterir', () => {
    renderWithProviders(<UserInsightsSection data={userDetailFixture.insights!} />);
    const table = screen.getByRole('table', { name: 'Bu kullanıcı hangi sayfalarda vakit geçiriyor?' });
    expect(within(table).getByText('Haber Detayı')).toBeInTheDocument();
    expect(within(table).getByText('%75')).toBeInTheDocument();
    const hours = screen.getByRole('list', { name: 'Hangi saatlerde kullanıyor?' });
    expect(within(hours).getAllByRole('listitem')).toHaveLength(24);
    expect(within(hours).getByText('11:00')).toBeInTheDocument();
    expect(screen.getByRole('list', { name: 'Günlük kullanım' }).children).toHaveLength(3);
    expect(screen.getByText('Beğeni')).toBeInTheDocument();
  });

  it('kısmi kaydı açıklar ve ölçülmemiş ziyaretin ortalamasını sıfır göstermez', () => {
    renderWithProviders(
      <UserInsightsSection
        data={{
          ...userDetailFixture.insights!,
          partial: true,
          screens: [
            { screen: '/menu', views: 1, measuredVisits: 0, totalMs: 0, avgMs: 0, maxMs: 0, share: 0 },
          ],
          actions: [],
        }}
      />,
    );
    expect(screen.getByRole('note')).toHaveTextContent('en yeni 20 olay');
    expect(screen.getByText('Bu aralıkta işlem kaydı yok')).toBeInTheDocument();
    const table = screen.getByRole('table', { name: 'Bu kullanıcı hangi sayfalarda vakit geçiriyor?' });
    expect(within(table).getAllByText('—')).toHaveLength(2);
  });
});
