import { screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { useState } from 'react';
import { describe, expect, it, vi } from 'vitest';
import { renderWithProviders } from '../../test/utils';
import { BulkBar } from './BulkBar';
import { Table, type Column } from './Table';

interface Row {
  id: number;
  name: string;
}
const cols: Column<Row>[] = [{ key: 'name', header: 'Ad' }];
const rows: Row[] = [
  { id: 1, name: 'Ayşe' },
  { id: 2, name: 'Mehmet' },
  { id: 3, name: 'Zeynep' },
];

function Host() {
  const [sel, setSel] = useState<Set<string | number>>(new Set());
  return (
    <>
      <Table columns={cols} rows={rows} rowKey={(r) => r.id} selectedKeys={sel} onSelectionChange={setSel} />
      <BulkBar count={sel.size} onClear={() => setSel(new Set())}>
        <button>Gizle</button>
      </BulkBar>
    </>
  );
}

describe('Table: satır seçimi ve toplu işlem çubuğu', () => {
  it('satır seçilince çubuk açılır, tümünü seç kısmi durumu gösterir, temizle kapatır', async () => {
    const user = userEvent.setup();
    renderWithProviders(<Host />);
    expect(screen.queryByRole('region', { name: 'Toplu işlemler' })).toBeNull();

    const boxes = screen.getAllByRole('checkbox', { name: 'Satırı seç' });
    await user.click(boxes[0]);
    expect(screen.getByText('1 satır seçili')).toBeInTheDocument();
    const all = screen.getByRole('checkbox', { name: 'Görünen tüm satırları seç' }) as HTMLInputElement;
    expect(all.indeterminate).toBe(true);

    await user.click(all);
    expect(screen.getByText('3 satır seçili')).toBeInTheDocument();
    expect(all.checked).toBe(true);

    await user.click(screen.getByRole('button', { name: 'Seçimi temizle' }));
    expect(screen.queryByRole('region', { name: 'Toplu işlemler' })).toBeNull();
  });

  it('onay kutusu satır tıklamasını tetiklemez', async () => {
    const user = userEvent.setup();
    const onRow = vi.fn();
    renderWithProviders(
      <Table
        columns={cols}
        rows={rows}
        rowKey={(r) => r.id}
        onRowClick={onRow}
        selectedKeys={new Set()}
        onSelectionChange={() => {}}
      />,
    );
    await user.click(screen.getAllByRole('checkbox', { name: 'Satırı seç' })[1]);
    expect(onRow).not.toHaveBeenCalled();
  });

  it('hata durumunda tablo yerine hata ve "Tekrar dene" çizilir', async () => {
    const user = userEvent.setup();
    const retry = vi.fn();
    renderWithProviders(<Table columns={cols} rows={undefined} rowKey={(r) => r.id} error onRetry={retry} />);
    expect(screen.getByRole('alert')).toBeInTheDocument();
    expect(screen.queryByRole('table')).toBeNull();
    await user.click(screen.getByRole('button', { name: 'Tekrar dene' }));
    expect(retry).toHaveBeenCalled();
  });
});
