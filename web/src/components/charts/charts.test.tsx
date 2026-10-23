import { screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { renderWithProviders } from '../../test/utils';
import { BarChart, CohortTable, DonutChart, FunnelChart, LineAreaChart } from './index';

describe('grafikler', () => {
  it('boş veride erişilebilir boş durum gösterir', () => {
    renderWithProviders(
      <>
        <LineAreaChart
          data={[]}
          xKey="date"
          series={[{ key: 'count', label: 'Kayıt' }]}
          ariaLabel="Kayıt grafiği"
        />
        <BarChart data={[]} xKey="name" series={[{ key: 'v', label: 'V' }]} ariaLabel="Çubuk grafiği" />
        <DonutChart data={[]} ariaLabel="Halka grafiği" />
      </>,
    );
    expect(screen.getByRole('img', { name: /Kayıt grafiği/ })).toHaveTextContent('Sonuç bulunamadı');
    expect(screen.getByRole('img', { name: /Çubuk grafiği/ })).toBeInTheDocument();
    expect(screen.getByRole('img', { name: /Halka grafiği/ })).toBeInTheDocument();
  });

  it('dolu veride aria-label ile çerçevelenir', () => {
    renderWithProviders(
      <LineAreaChart
        data={[{ date: '2026-01-01', count: 3 }]}
        xKey="date"
        series={[{ key: 'count', label: 'Kayıt' }]}
        ariaLabel="Günlük kayıtlar"
      />,
    );
    expect(screen.getByRole('img', { name: 'Günlük kayıtlar' })).toBeInTheDocument();
  });

  it('huni adımları oranlarıyla listelenir', () => {
    renderWithProviders(
      <FunnelChart
        ariaLabel="Dönüşüm"
        steps={[
          { label: 'Kayıt', value: 200 },
          { label: 'Doğrulama', value: 100 },
        ]}
      />,
    );
    expect(screen.getByRole('list', { name: 'Dönüşüm' })).toBeInTheDocument();
    expect(screen.getByText('%50')).toBeInTheDocument();
  });

  it('huni boşsa boş durum gösterir', () => {
    renderWithProviders(<FunnelChart ariaLabel="Dönüşüm" steps={[]} />);
    expect(screen.getByRole('img', { name: /Dönüşüm/ })).toBeInTheDocument();
  });

  it('kohort tablosu yüzdeleri ve boş hücreleri yazar', () => {
    renderWithProviders(
      <CohortTable
        ariaLabel="Tutundurma"
        sizeLabel="Boyut"
        columns={['D1', 'D7', 'D30']}
        rows={[{ label: '2026-09-01', size: 40, values: [80, 42.4, null] }]}
      />,
    );
    const table = screen.getByRole('table', { name: 'Tutundurma' });
    expect(table).toHaveTextContent('%80');
    expect(table).toHaveTextContent('%42');
    expect(table).toHaveTextContent('–');
  });
});
