import { act, fireEvent, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { useState } from 'react';
import { describe, expect, it, vi } from 'vitest';
import { renderWithProviders } from '../../test/utils';
import {
  Avatar,
  Badge,
  Button,
  Checkbox,
  ConfirmDialog,
  CopyButton,
  DateRangePicker,
  EmptyState,
  ErrorState,
  FormField,
  IconButton,
  Icon,
  Input,
  LoadMore,
  MarkdownText,
  Modal,
  PageHeader,
  Pagination,
  SearchInput,
  Select,
  StatCard,
  Switch,
  Table,
  Tabs,
  Textarea,
  Tooltip,
  useToast,
  type Column,
} from './index';

describe('Button / IconButton', () => {
  it('tıklanır, yüklenirken devre dışı ve aria-busy olur', async () => {
    const onClick = vi.fn();
    const user = userEvent.setup();
    const { rerender } = renderWithProviders(<Button onClick={onClick}>Kaydet</Button>);
    await user.click(screen.getByRole('button', { name: 'Kaydet' }));
    expect(onClick).toHaveBeenCalledTimes(1);
    rerender(
      <Button onClick={onClick} loading>
        Kaydet
      </Button>,
    );
    const b = screen.getByRole('button', { name: 'Kaydet' });
    expect(b).toBeDisabled();
    expect(b).toHaveAttribute('aria-busy', 'true');
  });

  it('IconButton erişilebilir ad ve title taşır', () => {
    renderWithProviders(
      <IconButton label="Kapat">
        <Icon name="x" />
      </IconButton>,
    );
    const b = screen.getByRole('button', { name: 'Kapat' });
    expect(b).toHaveAttribute('title', 'Kapat');
  });
});

describe('FormField / alanlar', () => {
  it('etiketi bağlar, hatayı aria-invalid ve aria-describedby ile bildirir', () => {
    renderWithProviders(
      <FormField label="E-posta" error="Zorunlu" hint="ipucu" required>
        <Input />
      </FormField>,
    );
    const input = screen.getByLabelText(/E-posta/);
    expect(input).toHaveAttribute('aria-invalid', 'true');
    expect(input).toBeRequired();
    expect(screen.getByRole('alert')).toHaveTextContent('Zorunlu');
    const desc = input.getAttribute('aria-describedby') ?? '';
    expect(desc.split(' ')).toHaveLength(2);
  });

  it('Select, Textarea ve Checkbox çalışır', async () => {
    const user = userEvent.setup();
    const onCheck = vi.fn();
    renderWithProviders(
      <>
        <FormField label="Durum">
          <Select defaultValue="a">
            <option value="a">A</option>
            <option value="b">B</option>
          </Select>
        </FormField>
        <FormField label="Not">
          <Textarea />
        </FormField>
        <Checkbox label="Onaylıyorum" onChange={(e) => onCheck(e.target.checked)} />
      </>,
    );
    await user.selectOptions(screen.getByLabelText('Durum'), 'b');
    expect(screen.getByLabelText('Durum')).toHaveValue('b');
    await user.type(screen.getByLabelText('Not'), 'merhaba');
    expect(screen.getByLabelText('Not')).toHaveValue('merhaba');
    await user.click(screen.getByLabelText('Onaylıyorum'));
    expect(onCheck).toHaveBeenCalledWith(true);
  });

  it('Switch role=switch, aria-checked ve klavye ile değişir', async () => {
    const user = userEvent.setup();
    function Host() {
      const [on, setOn] = useState(false);
      return <Switch checked={on} onChange={setOn} label="Bakım modu" />;
    }
    renderWithProviders(<Host />);
    const sw = screen.getByRole('switch', { name: 'Bakım modu' });
    expect(sw).toHaveAttribute('aria-checked', 'false');
    sw.focus();
    await user.keyboard(' ');
    expect(sw).toHaveAttribute('aria-checked', 'true');
  });
});

describe('Table', () => {
  interface Row {
    id: number;
    name: string;
  }
  const cols: Column<Row>[] = [
    { key: 'name', header: 'Ad', sortable: true },
    { key: 'id', header: 'No', align: 'end' },
  ];
  const rows: Row[] = [
    { id: 1, name: 'Ayşe' },
    { id: 2, name: 'Mehmet' },
  ];

  it('satırları çizer, sıralamayı bildirir ve satır tıklamasını/Enter tuşunu iletir', async () => {
    const user = userEvent.setup();
    const onSort = vi.fn();
    const onRow = vi.fn();
    renderWithProviders(
      <Table
        columns={cols}
        rows={rows}
        rowKey={(r) => r.id}
        sort={{ key: 'name', dir: 'asc' }}
        onSortChange={onSort}
        onRowClick={onRow}
        caption="Kullanıcılar"
      />,
    );
    expect(screen.getByRole('columnheader', { name: /Ad/ })).toHaveAttribute('aria-sort', 'ascending');
    await user.click(screen.getByRole('button', { name: /Ad/ }));
    expect(onSort).toHaveBeenCalledWith({ key: 'name', dir: 'desc' });
    await user.click(screen.getByText('Ayşe'));
    expect(onRow).toHaveBeenCalledWith(rows[0]);
    const row = screen.getByText('Mehmet').closest('tr')!;
    row.focus();
    await user.keyboard('{Enter}');
    expect(onRow).toHaveBeenCalledWith(rows[1]);
  });

  it('yükleniyor iskeleti ve boş durum gösterir', () => {
    const { rerender } = renderWithProviders(
      <Table columns={cols} rows={undefined} rowKey={(r) => r.id} loading skeletonRows={3} />,
    );
    expect(document.querySelectorAll('tbody tr')).toHaveLength(3);
    rerender(<Table columns={cols} rows={[]} rowKey={(r) => r.id} />);
    expect(screen.getByText('Sonuç bulunamadı')).toBeInTheDocument();
  });
});

describe('Pagination / LoadMore', () => {
  it('sayfa değiştirir ve sınırlarda düğmeleri kapatır', async () => {
    const user = userEvent.setup();
    const onChange = vi.fn();
    renderWithProviders(<Pagination page={0} totalPages={3} onPageChange={onChange} />);
    expect(screen.getByText('Sayfa 1 / 3')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Önceki sayfa' })).toBeDisabled();
    await user.click(screen.getByRole('button', { name: 'Sonraki sayfa' }));
    expect(onChange).toHaveBeenCalledWith(1);
  });

  it('LoadMore yalnızca devam varsa görünür', async () => {
    const user = userEvent.setup();
    const onMore = vi.fn();
    const { rerender } = renderWithProviders(<LoadMore hasMore onLoadMore={onMore} />);
    await user.click(screen.getByRole('button', { name: 'Daha fazla yükle' }));
    expect(onMore).toHaveBeenCalled();
    rerender(<LoadMore hasMore={false} onLoadMore={onMore} />);
    expect(screen.queryByRole('button')).toBeNull();
  });
});

describe('Modal / ConfirmDialog', () => {
  it('odağı tuzağa alır, ESC ile kapanır ve odağı geri verir', async () => {
    const user = userEvent.setup();
    function Host() {
      const [open, setOpen] = useState(false);
      return (
        <>
          <button onClick={() => setOpen(true)}>aç</button>
          <Modal open={open} onClose={() => setOpen(false)} title="Başlık" footer={<button>Tamam</button>}>
            <input aria-label="alan" />
          </Modal>
        </>
      );
    }
    renderWithProviders(<Host />);
    const opener = screen.getByText('aç');
    await user.click(opener);
    const dialog = screen.getByRole('dialog', { name: 'Başlık' });
    expect(dialog).toHaveAttribute('aria-modal', 'true');
    // Tab döngüsü: kapat → alan → Tamam → kapat
    const close = screen.getByRole('button', { name: 'Kapat' });
    expect(close).toHaveFocus();
    await user.tab();
    expect(screen.getByLabelText('alan')).toHaveFocus();
    await user.tab();
    expect(screen.getByText('Tamam')).toHaveFocus();
    await user.tab();
    expect(close).toHaveFocus();
    await user.keyboard('{Escape}');
    expect(screen.queryByRole('dialog')).toBeNull();
    expect(opener).toHaveFocus();
  });

  it('ConfirmDialog onay ve vazgeç düğmeleri çalışır', async () => {
    const user = userEvent.setup();
    const onConfirm = vi.fn();
    const onClose = vi.fn();
    renderWithProviders(
      <ConfirmDialog
        open
        onClose={onClose}
        onConfirm={onConfirm}
        title="Silinsin mi?"
        message="Geri alınamaz."
        confirmLabel="Sil"
        danger
      />,
    );
    expect(screen.getByRole('button', { name: 'Sil' })).toHaveFocus();
    await user.click(screen.getByRole('button', { name: 'Sil' }));
    expect(onConfirm).toHaveBeenCalled();
    await user.click(screen.getByRole('button', { name: 'Vazgeç' }));
    expect(onClose).toHaveBeenCalled();
  });
});

describe('Tabs', () => {
  it('ok tuşlarıyla gezer (RTL’de yön tersine döner)', async () => {
    const user = userEvent.setup();
    const tabs = [
      { id: 'a', label: 'Genel' },
      { id: 'b', label: 'Büyüme' },
      { id: 'c', label: 'Etkileşim' },
    ];
    function Host() {
      const [v, setV] = useState('a');
      return (
        <Tabs tabs={tabs} value={v} onChange={setV} label="Analitik">
          <p>panel {v}</p>
        </Tabs>
      );
    }
    renderWithProviders(<Host />);
    const first = screen.getByRole('tab', { name: 'Genel' });
    first.focus();
    await user.keyboard('{ArrowRight}');
    expect(screen.getByRole('tab', { name: 'Büyüme' })).toHaveAttribute('aria-selected', 'true');
    expect(screen.getByRole('tabpanel')).toHaveTextContent('panel b');
    await user.keyboard('{End}');
    expect(screen.getByRole('tab', { name: 'Etkileşim' })).toHaveAttribute('aria-selected', 'true');
  });

  it('RTL’de ArrowLeft ileri gider', async () => {
    const user = userEvent.setup();
    function Host() {
      const [v, setV] = useState('a');
      return (
        <Tabs
          tabs={[
            { id: 'a', label: 'ا' },
            { id: 'b', label: 'ب' },
          ]}
          value={v}
          onChange={setV}
          label="x"
        />
      );
    }
    renderWithProviders(<Host />, { lang: 'ar' });
    screen.getByRole('tab', { name: 'ا' }).focus();
    await user.keyboard('{ArrowLeft}');
    expect(screen.getByRole('tab', { name: 'ب' })).toHaveAttribute('aria-selected', 'true');
  });
});

describe('Toast', () => {
  it('bildirimi kuyruğa ekler, kapatılabilir', async () => {
    const user = userEvent.setup();
    function Host() {
      const toast = useToast();
      return (
        <>
          <button onClick={() => toast.success('Kaydedildi')}>x</button>
          <button onClick={() => toast.error('Hata oldu')}>y</button>
        </>
      );
    }
    renderWithProviders(<Host />);
    await user.click(screen.getByText('x'));
    await user.click(screen.getByText('y'));
    expect(screen.getByText('Kaydedildi')).toBeInTheDocument();
    expect(screen.getByRole('alert')).toHaveTextContent('Hata oldu');
    await user.click(screen.getAllByRole('button', { name: 'Bildirimi kapat' })[0]);
    expect(screen.queryByText('Kaydedildi')).toBeNull();
  });
});

describe('SearchInput', () => {
  it('yazmayı geciktirir (debounce) ve temizler', async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true });
    const onSearch = vi.fn();
    renderWithProviders(<SearchInput onSearch={onSearch} delay={300} />);
    const input = screen.getByRole('searchbox');
    fireEvent.change(input, { target: { value: 'ali' } });
    expect(onSearch).not.toHaveBeenCalled();
    await act(async () => {
      vi.advanceTimersByTime(350);
    });
    expect(onSearch).toHaveBeenCalledTimes(1);
    expect(onSearch).toHaveBeenCalledWith('ali');
    fireEvent.click(screen.getByRole('button', { name: 'Aramayı temizle' }));
    await act(async () => {
      vi.advanceTimersByTime(350);
    });
    expect(onSearch).toHaveBeenLastCalledWith('');
    vi.useRealTimers();
  });
});

describe('DateRangePicker', () => {
  it('hızlı seçim aralığı bugünden geriye hesaplar', async () => {
    const user = userEvent.setup();
    const onChange = vi.fn();
    renderWithProviders(<DateRangePicker value={{ from: '', to: '' }} onChange={onChange} />);
    await user.click(screen.getByRole('button', { name: 'Son 7 gün' }));
    const arg = onChange.mock.calls[0][0] as { from: string; to: string };
    expect(arg.from).toMatch(/^\d{4}-\d{2}-\d{2}$/);
    const days = (new Date(arg.to).getTime() - new Date(arg.from).getTime()) / 86_400_000;
    expect(Math.round(days)).toBe(6);
  });
});

describe('MarkdownText', () => {
  it('başlık, liste, kalın ve güvenli bağlantı üretir', () => {
    renderWithProviders(
      <MarkdownText
        text={'# Başlık\n\nMerhaba **dünya** [site](https://bingol.edu.tr)\n\n- bir\n- iki\n\n1. x\n2. y'}
      />,
    );
    expect(screen.getByRole('heading', { level: 3, name: 'Başlık' })).toBeInTheDocument();
    expect(screen.getByText('dünya').tagName).toBe('STRONG');
    const a = screen.getByRole('link', { name: 'site' });
    expect(a).toHaveAttribute('href', 'https://bingol.edu.tr');
    expect(a).toHaveAttribute('rel', 'noopener noreferrer');
    expect(screen.getAllByRole('listitem')).toHaveLength(4);
  });

  it('HTML ve javascript: bağlantıları enjekte etmez', () => {
    const { container } = renderWithProviders(
      <MarkdownText
        text={'<script>alert(1)</script> <img src=x onerror=alert(1)> [x](javascript:alert(1))'}
      />,
    );
    expect(container.querySelector('script')).toBeNull();
    expect(container.querySelector('img')).toBeNull();
    expect(container.querySelector('a')).toBeNull();
    expect(container.textContent).toContain('<script>');
  });
});

describe('diğer bileşenler', () => {
  it('StatCard değişim okunu ve tonu gösterir', () => {
    renderWithProviders(
      <StatCard
        title="Kullanıcı"
        value="1.204"
        change={12}
        changeLabel="son 7 gün"
        sparkline={[1, 3, 2, 5]}
      />,
    );
    expect(screen.getByText('1.204')).toBeInTheDocument();
    expect(screen.getByText('+12%')).toBeInTheDocument();
    expect(document.querySelector('svg[class*="spark"]')).not.toBeNull();
  });

  it('EmptyState ve ErrorState (tekrar dene) çalışır', async () => {
    const user = userEvent.setup();
    const retry = vi.fn();
    renderWithProviders(
      <>
        <EmptyState />
        <ErrorState onRetry={retry} />
      </>,
    );
    expect(screen.getByText('Burada henüz bir şey yok')).toBeInTheDocument();
    expect(screen.getByRole('alert')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Tekrar dene' }));
    expect(retry).toHaveBeenCalled();
  });

  it('Badge, PageHeader, Avatar ve Tooltip', async () => {
    const user = userEvent.setup();
    renderWithProviders(
      <>
        <PageHeader
          title="Kullanıcılar"
          description="Açıklama"
          breadcrumbs={[{ label: 'Yönetim', to: '/admin' }, { label: 'Kullanıcılar' }]}
        />
        <Badge tone="success">Aktif</Badge>
        <Avatar name="Ayşe Yılmaz" />
        <Tooltip text="İpucu">
          <button>hover</button>
        </Tooltip>
      </>,
    );
    expect(screen.getByRole('heading', { level: 1, name: 'Kullanıcılar' })).toBeInTheDocument();
    expect(screen.getByText('Aktif')).toBeInTheDocument();
    expect(screen.getByRole('img', { name: 'Ayşe Yılmaz' })).toHaveTextContent('AY');
    await user.tab();
    expect(screen.getByRole('button', { name: 'hover' })).toHaveAccessibleDescription('İpucu');
  });

  it('CopyButton panoya yazar', async () => {
    const user = userEvent.setup();
    renderWithProviders(<CopyButton value="abc-123" />);
    await user.click(screen.getByRole('button', { name: 'Kopyala' }));
    await waitFor(() => expect(screen.getByRole('button', { name: 'Kopyalandı' })).toBeInTheDocument());
  });
});
