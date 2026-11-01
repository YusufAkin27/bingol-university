import { screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import { renderWithProviders } from '../../test/utils';
import { BarChart, ChartPanel, FunnelChart, LineAreaChart } from './index';

const data = [
  { day: '2026-10-30', n: 98 },
  { day: '2026-10-31', n: 120 },
];

function chart() {
  return <LineAreaChart data={data} xKey="day" series={[{ key: 'n', label: 'Giren kişi' }]} ariaLabel="Günlük giren kişi" />;
}

describe('ChartPanel', () => {
  it('başlık, yorum cümlesi ve grafik; grafik yorumu aria-describedby ile gösterir', () => {
    renderWithProviders(
      <ChartPanel title="Günlük giren kişi" insight={['Bugün ', { text: '120 kişi' }, ' girdi, dün 98 idi: %22 fazla']}>
        {chart()}
      </ChartPanel>,
    );
    expect(screen.getByRole('heading', { name: 'Günlük giren kişi', level: 2 })).toBeInTheDocument();
    const img = screen.getByRole('img', { name: 'Günlük giren kişi' });
    const id = img.getAttribute('aria-describedby');
    expect(id).toBeTruthy();
    const insight = document.getElementById(id as string) as HTMLElement;
    expect(insight).toHaveTextContent('Bugün 120 kişi girdi, dün 98 idi: %22 fazla');
    expect(insight).not.toHaveAttribute('aria-live');
  });

  it('yorum yoksa aria-describedby yazılmaz', () => {
    renderWithProviders(<ChartPanel title="Başlık">{chart()}</ChartPanel>);
    expect(screen.getByRole('img', { name: 'Günlük giren kişi' })).not.toHaveAttribute('aria-describedby');
  });

  it('huni grafiği de yorumu gösterir', () => {
    renderWithProviders(
      <ChartPanel title="Dönüşüm" insight="Kayıt olanların yarısı doğruladı.">
        <FunnelChart ariaLabel="Dönüşüm" steps={[{ label: 'Kayıt', value: 10 }, { label: 'Doğrulama', value: 5 }]} />
      </ChartPanel>,
    );
    expect(screen.getByRole('list', { name: 'Dönüşüm' })).toHaveAttribute('aria-describedby');
  });

  it('"veriyi tablo olarak göster" erişilebilir tabloyu açıp kapatır', async () => {
    renderWithProviders(
      <ChartPanel
        title="Günlük giren kişi"
        table={{
          columns: [
            { key: 'day', header: 'Gün' },
            { key: 'n', header: 'Kişi', align: 'end' },
          ],
          rows: data.map((d) => ({ day: d.day, n: d.n })),
        }}
      >
        {chart()}
      </ChartPanel>,
    );
    const btn = screen.getByRole('button', { name: 'Veriyi tablo olarak göster' });
    expect(btn).toHaveAttribute('aria-expanded', 'false');
    expect(screen.queryByRole('table')).toBeNull();
    await userEvent.click(btn);
    const table = screen.getByRole('table', { name: 'Günlük giren kişi (tablo olarak)' });
    expect(within(table).getByRole('columnheader', { name: 'Kişi' })).toBeInTheDocument();
    expect(within(table).getAllByRole('row')).toHaveLength(3);
    expect(within(table).getByText('120')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Tabloyu gizle' })).toHaveAttribute('aria-expanded', 'true');
    await userEvent.click(screen.getByRole('button', { name: 'Tabloyu gizle' }));
    expect(screen.queryByRole('table')).toBeNull();
  });

  it('renk açıklaması ve alt not', () => {
    renderWithProviders(
      <ChartPanel
        title="İki seri"
        legend={[
          { key: 'a', label: 'Kayıt' },
          { key: 'b', label: 'Giriş' },
        ]}
        footnote="Veriler her gece yenilenir"
      >
        <BarChart data={data} xKey="day" series={[{ key: 'n', label: 'Kişi' }]} ariaLabel="Çubuk" />
      </ChartPanel>,
    );
    expect(screen.getByRole('list', { name: 'Renk açıklaması' })).toBeInTheDocument();
    expect(screen.getByText('Veriler her gece yenilenir')).toBeInTheDocument();
  });

  it('yükleniyor: grafik ve tablo düğmesi yok', () => {
    renderWithProviders(
      <ChartPanel title="X" loading insight="gizli" table={{ columns: [], rows: [] }}>
        {chart()}
      </ChartPanel>,
    );
    expect(screen.getByRole('status', { name: 'Grafik yükleniyor…' })).toBeInTheDocument();
    expect(screen.queryByRole('img')).toBeNull();
    expect(screen.queryByRole('button')).toBeNull();
    expect(screen.queryByText('gizli')).toBeNull();
  });

  it('boş: anlaşılır cümle', () => {
    renderWithProviders(
      <ChartPanel title="X" empty>
        {chart()}
      </ChartPanel>,
    );
    expect(screen.getByText('Bu aralıkta gösterilecek veri yok.')).toBeInTheDocument();
    expect(screen.queryByRole('img')).toBeNull();
  });

  it('hata: uyarı ve tekrar dene', async () => {
    const onRetry = vi.fn();
    renderWithProviders(
      <ChartPanel title="X" error onRetry={onRetry}>
        {chart()}
      </ChartPanel>,
    );
    expect(screen.getByRole('alert')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: 'Tekrar dene' }));
    expect(onRetry).toHaveBeenCalled();
  });
});
