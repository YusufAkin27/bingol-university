import { fireEvent, renderHook, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { renderWithProviders } from '../../test/utils';
import { translate } from '../../i18n';
import {
  ActionBar,
  ChartLegend,
  DataCards,
  DeltaBadge,
  Insight,
  ProgressRing,
  RankedBars,
  ResponsiveTable,
  ScrollShadow,
  StatTile,
  StatusDot,
  compareSentence,
  formatCompact,
  formatPercent,
  percentChange,
  relativeTime,
  useIsNarrow,
  type Column,
  type FormatCtx,
} from './index';

const ctx: FormatCtx = {
  t: (k, p) => translate('tr', k, p),
  formatNumber: (n, o) => new Intl.NumberFormat('tr', o).format(n),
  formatDate: (v) => String(v),
};

function mockMedia(matches: boolean) {
  window.matchMedia = ((query: string) => ({
    matches,
    media: query,
    onchange: null,
    addEventListener: () => {},
    removeEventListener: () => {},
    addListener: () => {},
    removeListener: () => {},
    dispatchEvent: () => false,
  })) as unknown as typeof window.matchMedia;
}

afterEach(() => mockMedia(false));

describe('sayı biçimleri', () => {
  it('kısa sayı: B / Mn / Mr ve sınır yuvarlama', () => {
    expect(formatCompact(950, ctx)).toBe('950');
    expect(formatCompact(12400, ctx)).toBe('12,4 B');
    expect(formatCompact(1_200_000, ctx)).toBe('1,2 Mn');
    expect(formatCompact(3_000_000_000, ctx)).toBe('3 Mr');
    expect(formatCompact(999_999, ctx)).toBe('1 Mn');
    expect(formatCompact(-12400, ctx)).toBe('-12,4 B');
    expect(formatCompact(null, ctx)).toBe('–');
    expect(formatCompact(Number.NaN, ctx)).toBe('–');
  });

  it('yüzde ve yüzde değişim', () => {
    expect(formatPercent(12, ctx)).toBe('%12');
    expect(formatPercent(12.5, ctx, 1)).toBe('%12,5');
    expect(formatPercent(undefined, ctx)).toBe('–');
    expect(percentChange(120, 98)).toBeCloseTo(22.45, 1);
    expect(percentChange(5, 0)).toBeNull();
    expect(percentChange(5, undefined)).toBeNull();
    expect(percentChange(50, 100)).toBe(-50);
  });

  it('göreli süre', () => {
    const now = new Date('2026-11-01T12:00:00Z').getTime();
    const ago = (sec: number) => now - sec * 1000;
    expect(relativeTime(ago(10), ctx, now)).toBe('Az önce');
    expect(relativeTime(ago(180), ctx, now)).toBe('3 dk önce');
    expect(relativeTime(ago(2 * 3600 + 60), ctx, now)).toBe('2 sa önce');
    expect(relativeTime(ago(30 * 3600), ctx, now)).toBe('Dün');
    expect(relativeTime(ago(5 * 86400), ctx, now)).toBe('5 gün önce');
    expect(relativeTime(now + 5 * 60_000, ctx, now)).toBe('5 dk sonra');
    expect(relativeTime(now + 30_000, ctx, now)).toBe('Birazdan');
    expect(relativeTime(null, ctx, now)).toBe('–');
    expect(relativeTime('geçersiz', ctx, now)).toBe('–');
    expect(relativeTime(ago(90 * 86400), ctx, now)).toMatch(/^\d+$/); // formatDate yedeği
  });
});

describe('DeltaBadge', () => {
  it('artış iyi: yeşil ok ve cümle', () => {
    const { container } = renderWithProviders(<DeltaBadge change={22.4} compareLabel="dünden" />);
    expect(screen.getByText('dünden %22,4 fazla')).toBeInTheDocument();
    expect(container.firstElementChild).toHaveAttribute('data-dir', 'up');
    expect(container.firstElementChild).toHaveAttribute('data-good', 'true');
    expect(screen.getByText('Bu iyi bir gelişme.')).toBeInTheDocument();
  });

  it('goodWhen=down: artış kötü sayılır', () => {
    const { container } = renderWithProviders(
      <DeltaBadge change={10} goodWhen="down" compareLabel="geçen haftaya göre" />,
    );
    expect(screen.getByText('geçen haftaya göre %10 fazla')).toBeInTheDocument();
    expect(container.firstElementChild).toHaveAttribute('data-good', 'false');
    expect(screen.getByText('Dikkat edilmesi gerekiyor.')).toBeInTheDocument();
  });

  it('düşüş, eşitlik ve veri yok', () => {
    const { rerender, container } = renderWithProviders(<DeltaBadge change={-5} compareLabel="dünden" />);
    expect(screen.getByText('dünden %5 az')).toBeInTheDocument();
    rerender(<DeltaBadge change={0} compareLabel="dünden" />);
    expect(screen.getByText('dünden aynı')).toBeInTheDocument();
    rerender(<DeltaBadge change={null} />);
    expect(container).toBeEmptyDOMElement();
    rerender(<DeltaBadge change={null} showNone />);
    expect(screen.getByText('Karşılaştırılacak eski veri yok')).toBeInTheDocument();
  });

  it('goodWhen=neutral: iyi/kötü notu yazılmaz', () => {
    renderWithProviders(<DeltaBadge change={8} goodWhen="neutral" />);
    expect(screen.queryByText('Bu iyi bir gelişme.')).toBeNull();
    expect(screen.getByText('Öncekine göre %8 fazla')).toBeInTheDocument();
  });
});

describe('StatTile', () => {
  it('etiket, büyük sayı, birim, trend ve mini eğri özeti', () => {
    renderWithProviders(
      <StatTile
        label="Bugün giren kişi"
        value={1234}
        unit="kişi"
        change={22}
        compareLabel="dünden"
        spark={[3, 5, 9, 4]}
        caption="Son 24 saat"
      />,
    );
    const g = screen.getByRole('group', { name: 'Bugün giren kişi' });
    expect(within(g).getByText('1.234')).toBeInTheDocument();
    expect(within(g).getByText('kişi')).toBeInTheDocument();
    expect(within(g).getByText('dünden %22 fazla')).toBeInTheDocument();
    expect(within(g).getByText('Son 24 saat')).toBeInTheDocument();
    expect(within(g).getByText(/Son 4 ölçüm: ilk 3, son 4, en yüksek 9\./)).toBeInTheDocument();
  });

  it('compact sayı kısaltır', () => {
    renderWithProviders(<StatTile label="Mesaj" value={12400} compact />);
    expect(screen.getByText('12,4 B')).toBeInTheDocument(); // getByText boşlukları normalleştirir
  });

  it('yükleniyor: değer yok, aria-busy', () => {
    renderWithProviders(<StatTile label="Mesaj" value={5} loading />);
    expect(screen.getByRole('group', { name: 'Mesaj' })).toHaveAttribute('aria-busy', 'true');
    expect(screen.queryByText('5')).toBeNull();
  });

  it('boş: tire ve anlaşılır cümle', () => {
    renderWithProviders(<StatTile label="Mesaj" value={null} change={10} />);
    expect(screen.getByText('–')).toBeInTheDocument();
    expect(screen.getByText('Henüz veri yok.')).toBeInTheDocument();
    expect(screen.queryByText(/fazla/)).toBeNull();
  });

  it('hata: uyarı ve tekrar dene', async () => {
    const onRetry = vi.fn();
    renderWithProviders(<StatTile label="Mesaj" value={5} error onRetry={onRetry} />);
    expect(screen.getByRole('alert')).toHaveTextContent('Bu bilgi şu an yüklenemedi.');
    await userEvent.click(screen.getByRole('button', { name: 'Tekrar dene' }));
    expect(onRetry).toHaveBeenCalledTimes(1);
  });
});

describe('ProgressRing', () => {
  it('progressbar rolü, yüzde ve cümle', () => {
    renderWithProviders(<ProgressRing value={42} label="kişi e-postasını doğruladı" tone="success" />);
    const bar = screen.getByRole('progressbar', { name: 'kişi e-postasını doğruladı' });
    expect(bar).toHaveAttribute('aria-valuenow', '42');
    expect(bar).toHaveAttribute('aria-valuetext', 'kişi e-postasını doğruladı: yüzde 42');
    expect(screen.getByText('%42')).toBeInTheDocument();
  });

  it('max ile oranlar ve 0-100 aralığına sıkıştırır', () => {
    renderWithProviders(
      <>
        <ProgressRing value={30} max={60} label="yarım" />
        <ProgressRing value={500} label="taşan" />
      </>,
    );
    expect(screen.getByRole('progressbar', { name: 'yarım' })).toHaveAttribute('aria-valuenow', '50');
    expect(screen.getByRole('progressbar', { name: 'taşan' })).toHaveAttribute('aria-valuenow', '100');
  });

  it('değer yoksa tire, yüklenirken iskelet', () => {
    const { rerender, container } = renderWithProviders(<ProgressRing value={null} label="boş" />);
    expect(screen.getByText('–')).toBeInTheDocument();
    expect(screen.getByRole('progressbar')).not.toHaveAttribute('aria-valuenow');
    rerender(<ProgressRing value={1} label="x" loading />);
    expect(container.querySelector('[aria-busy="true"]')).not.toBeNull();
  });
});

describe('RankedBars', () => {
  const items = [
    { key: 'a', label: 'Bilgisayar Mühendisliği', value: 40 },
    { key: 'b', label: 'Hemşirelik', value: 90 },
    { key: 'c', label: 'Çok uzun bir bölüm adı ki kırpılması gerekir elbette', value: 10 },
    { key: 'd', label: 'Hukuk', value: 5 },
  ];

  it('çoktan aza sıralar, sıra ve değer yazar', () => {
    renderWithProviders(<RankedBars items={items} ariaLabel="En çok kayıt olan bölümler" />);
    const rows = within(screen.getByRole('list', { name: 'En çok kayıt olan bölümler' })).getAllByRole('listitem');
    expect(rows[0]).toHaveTextContent('1Hemşirelik90');
    expect(rows[1]).toHaveTextContent('2Bilgisayar Mühendisliği40');
  });

  it('en az olan üstte (asc)', () => {
    renderWithProviders(<RankedBars items={items} ariaLabel="En az" order="asc" />);
    expect(within(screen.getByRole('list')).getAllByRole('listitem')[0]).toHaveTextContent('Hukuk');
  });

  it('limit: tümünü göster / daha az göster', async () => {
    renderWithProviders(<RankedBars items={items} ariaLabel="Liste" limit={2} />);
    expect(screen.getAllByRole('listitem')).toHaveLength(2);
    const more = screen.getByRole('button', { name: 'Tümünü göster (4)' });
    expect(more).toHaveAttribute('aria-expanded', 'false');
    await userEvent.click(more);
    expect(screen.getAllByRole('listitem')).toHaveLength(4);
    await userEvent.click(screen.getByRole('button', { name: 'Daha az göster' }));
    expect(screen.getAllByRole('listitem')).toHaveLength(2);
  });

  it('uzun etiket için ipucu (tooltip) verir, kısa için vermez', () => {
    renderWithProviders(<RankedBars items={items} ariaLabel="Liste" limit={0} />);
    expect(screen.getAllByRole('tooltip')).toHaveLength(1);
    expect(screen.getByRole('tooltip')).toHaveTextContent('Çok uzun bir bölüm adı ki kırpılması gerekir elbette');
  });

  it('pay yüzdesi ve özel biçimleyici', () => {
    renderWithProviders(
      <RankedBars
        items={[
          { key: 'a', label: 'A', value: 75 },
          { key: 'b', label: 'B', value: 25 },
        ]}
        ariaLabel="Liste"
        showShare
        formatValue={(n) => `${n} kişi`}
      />,
    );
    expect(screen.getByText('75 kişi')).toBeInTheDocument();
    expect(screen.getByText('toplamın %75')).toBeInTheDocument();
  });

  it('boş, yükleniyor ve hata hâlleri', async () => {
    const onRetry = vi.fn();
    const { rerender } = renderWithProviders(<RankedBars items={[]} ariaLabel="Liste" />);
    expect(screen.getByText('Henüz veri yok.')).toBeInTheDocument();
    rerender(<RankedBars items={undefined} ariaLabel="Liste" loading />);
    expect(screen.getByLabelText('Yükleniyor…')).toHaveAttribute('aria-busy', 'true');
    rerender(<RankedBars items={items} ariaLabel="Liste" error onRetry={onRetry} />);
    expect(screen.getByRole('alert')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: 'Tekrar dene' }));
    expect(onRetry).toHaveBeenCalled();
  });
});

describe('ChartLegend ve StatusDot', () => {
  it('legend: renk + desen + metin', () => {
    renderWithProviders(
      <ChartLegend
        items={[
          { key: 'a', label: 'Kayıt', value: '12' },
          { key: 'b', label: 'Giriş' },
          { key: 'c', label: 'Çıkış', pattern: 'hollow' },
        ]}
      />,
    );
    const list = screen.getByRole('list', { name: 'Renk açıklaması' });
    const li = within(list).getAllByRole('listitem');
    expect(li.map((x) => x.getAttribute('data-pattern'))).toEqual(['solid', 'stripe', 'hollow']);
    expect(li[0]).toHaveTextContent('Kayıt12');
  });

  it('legend boşsa hiçbir şey çizmez', () => {
    const { container } = renderWithProviders(<ChartLegend items={[]} />);
    expect(container).toBeEmptyDOMElement();
  });

  it('durum noktası: ton adı ekran okuyucuya, simge ve metin görünür', () => {
    const { container } = renderWithProviders(
      <>
        <StatusDot tone="success">Sunucu çalışıyor</StatusDot>
        <StatusDot tone="danger">Kuyruk durdu</StatusDot>
        <StatusDot>Bilinmiyor</StatusDot>
      </>,
    );
    expect(screen.getByText('Sorun yok:')).toHaveClass('sr-only');
    expect(screen.getByText('Sunucu çalışıyor')).toBeInTheDocument();
    expect(screen.getByText('Sorun var:')).toBeInTheDocument();
    // renk dışında farklı simge: onay ve çarpı (svg) ile nötr nokta (svg yok)
    const icons = container.querySelectorAll('svg');
    expect(icons).toHaveLength(2);
  });
});

describe('Insight', () => {
  it('parçalardan tek cümle; aria-live değil', () => {
    renderWithProviders(
      <Insight id="yorum" tone="good" parts={['Bugün ', { text: '120 kişi' }, ' girdi.']} />,
    );
    const p = document.getElementById('yorum') as HTMLElement;
    expect(p).toHaveTextContent('Bugün 120 kişi girdi.');
    expect(p).not.toHaveAttribute('aria-live');
    expect(p).not.toHaveAttribute('role', 'status');
  });

  it('karşılaştırma cümlesi: dün ile', () => {
    const r = compareSentence(ctx, {
      nowLabel: 'Bugün',
      current: 120,
      thenLabel: 'dün',
      previous: 98,
      unit: 'kişi',
      verb: 'girdi',
    });
    const text = r.parts.map((p) => (typeof p === 'string' ? p : p.text)).join('');
    expect(text).toBe('Bugün 120 kişi girdi, dün 98 idi: %22 fazla');
    expect(r.tone).toBe('good');
  });

  it('karşılaştırma: düşüş kötü, goodWhen=down ise iyi; önceki 0 ya da yok', () => {
    const base = { nowLabel: 'Bugün', thenLabel: 'dün', unit: 'rapor', verb: 'geldi' };
    const join = (parts: ReturnType<typeof compareSentence>['parts']) =>
      parts.map((p) => (typeof p === 'string' ? p : p.text)).join('');
    const down = compareSentence(ctx, { ...base, current: 5, previous: 10 });
    expect(join(down.parts)).toBe('Bugün 5 rapor geldi, dün 10 idi: %50 az');
    expect(down.tone).toBe('bad');
    expect(compareSentence(ctx, { ...base, current: 5, previous: 10, goodWhen: 'down' }).tone).toBe('good');
    expect(join(compareSentence(ctx, { ...base, current: 5, previous: 0 }).parts)).toBe(
      'Bugün 5 rapor geldi, dün hiç yoktu',
    );
    expect(join(compareSentence(ctx, { ...base, current: 5, previous: null }).parts)).toBe('Bugün 5 rapor geldi');
    expect(join(compareSentence(ctx, { ...base, current: 10, previous: 10 }).parts)).toBe(
      'Bugün 10 rapor geldi, dün 10 idi: aynı',
    );
  });
});

interface Row {
  id: number;
  name: string;
  email: string;
  role: string;
  joined: string;
}
const rows: Row[] = [
  { id: 1, name: 'Ayşe', email: 'ayse@bingol.edu.tr', role: 'Öğrenci', joined: '2026-01-01' },
  { id: 2, name: 'Mehmet', email: 'mehmet@bingol.edu.tr', role: 'Personel', joined: '2026-02-01' },
];
const cols: Column<Row>[] = [
  { key: 'name', header: 'Ad', card: { priority: 1 }, sortable: true },
  { key: 'email', header: 'E-posta', card: { priority: 2 } },
  { key: 'role', header: 'Rol', card: { priority: 3 } },
  { key: 'joined', header: 'Katılma' },
  {
    key: 'act',
    header: '',
    card: { actions: true },
    render: (r) => <button type="button">{`Sil ${r.name}`}</button>,
  },
];

describe('ResponsiveTable', () => {
  it('geniş ekranda gerçek tablo çizer', () => {
    mockMedia(false);
    renderWithProviders(<ResponsiveTable columns={cols} rows={rows} rowKey={(r) => r.id} caption="Kullanıcılar" />);
    expect(screen.getByRole('table')).toBeInTheDocument();
    expect(screen.queryByRole('list', { name: 'Kullanıcılar' })).toBeNull();
  });

  it('dar ekranda kart yığını: başlık, öncelikli alanlar, diğer bilgiler, eylemler', async () => {
    mockMedia(true);
    renderWithProviders(<ResponsiveTable columns={cols} rows={rows} rowKey={(r) => r.id} caption="Kullanıcılar" />);
    expect(screen.queryByRole('table')).toBeNull();
    const list = screen.getByRole('list', { name: 'Kullanıcılar' });
    const cards = within(list).getAllByRole('listitem');
    expect(cards).toHaveLength(2);
    expect(within(cards[0]).getByText('Ayşe')).toBeInTheDocument();
    expect(within(cards[0]).getByText('E-posta')).toBeInTheDocument();
    expect(within(cards[0]).getByText('ayse@bingol.edu.tr')).toBeInTheDocument();
    expect(within(cards[0]).getByText('Diğer bilgiler (1)')).toBeInTheDocument();
    expect(within(cards[0]).getByRole('button', { name: 'Sil Ayşe' })).toBeInTheDocument();
  });

  it('öncelik verilmezse ilk üç sütun üstte, kalanı ayrıntıda', () => {
    renderWithProviders(
      <DataCards
        columns={[
          { key: 'name', header: 'Ad' },
          { key: 'email', header: 'E-posta' },
          { key: 'role', header: 'Rol' },
          { key: 'joined', header: 'Katılma' },
        ]}
        rows={rows}
        rowKey={(r) => r.id}
      />,
    );
    expect(screen.getAllByText('Diğer bilgiler (1)')).toHaveLength(2);
  });

  it('kart tıklama, klavye ve eylem düğmesi olay yayılımı', async () => {
    mockMedia(true);
    const onRowClick = vi.fn();
    const onDelete = vi.fn();
    renderWithProviders(
      <ResponsiveTable
        columns={[
          cols[0],
          { key: 'act', header: '', card: { actions: true }, render: () => <button onClick={onDelete}>Sil</button> },
        ]}
        rows={rows}
        rowKey={(r) => r.id}
        onRowClick={onRowClick}
      />,
    );
    const cards = screen.getAllByRole('listitem');
    await userEvent.click(within(cards[0]).getByText('Ayşe'));
    expect(onRowClick).toHaveBeenCalledWith(rows[0]);
    await userEvent.click(within(cards[0]).getByRole('button', { name: 'Sil' }));
    expect(onDelete).toHaveBeenCalledTimes(1);
    expect(onRowClick).toHaveBeenCalledTimes(1);
    cards[1].focus();
    fireEvent.keyDown(cards[1], { key: 'Enter' });
    expect(onRowClick).toHaveBeenCalledWith(rows[1]);
  });

  it('seçim ve sıralama', async () => {
    mockMedia(true);
    const onSelectionChange = vi.fn();
    const onSortChange = vi.fn();
    renderWithProviders(
      <ResponsiveTable
        columns={cols}
        rows={rows}
        rowKey={(r) => r.id}
        selectedKeys={new Set([1])}
        onSelectionChange={onSelectionChange}
        sort={{ key: 'name', dir: 'asc' }}
        onSortChange={onSortChange}
      />,
    );
    const boxes = screen.getAllByRole('checkbox', { name: 'Satırı seç' });
    expect(boxes[0]).toBeChecked();
    expect(boxes[1]).not.toBeChecked();
    await userEvent.click(boxes[1]);
    expect(Array.from(onSelectionChange.mock.calls[0][0])).toEqual([1, 2]);
    await userEvent.click(screen.getByRole('button', { name: 'Küçükten büyüğe' }));
    expect(onSortChange).toHaveBeenCalledWith({ key: 'name', dir: 'desc' });
  });

  it('yükleniyor, boş ve hata', async () => {
    mockMedia(true);
    const onRetry = vi.fn();
    const { rerender } = renderWithProviders(
      <ResponsiveTable columns={cols} rows={undefined} rowKey={(r) => r.id} loading />,
    );
    expect(screen.getByRole('list')).toHaveAttribute('aria-busy', 'true');
    rerender(<ResponsiveTable columns={cols} rows={[]} rowKey={(r) => r.id} />);
    expect(screen.getByText('Sonuç bulunamadı')).toBeInTheDocument();
    rerender(<ResponsiveTable columns={cols} rows={rows} rowKey={(r) => r.id} error onRetry={onRetry} />);
    await userEvent.click(screen.getByRole('button', { name: 'Tekrar dene' }));
    expect(onRetry).toHaveBeenCalled();
  });

  it('cards="always" geniş ekranda da kart çizer', () => {
    mockMedia(false);
    renderWithProviders(<ResponsiveTable columns={cols} rows={rows} rowKey={(r) => r.id} cards="always" />);
    expect(screen.queryByRole('table')).toBeNull();
  });
});

describe('mobil yardımcılar', () => {
  it('useIsNarrow: matchMedia sonucunu verir, yoksa false', () => {
    mockMedia(true);
    expect(renderHook(() => useIsNarrow()).result.current).toBe(true);
    mockMedia(false);
    expect(renderHook(() => useIsNarrow(500)).result.current).toBe(false);
    const saved = window.matchMedia;
    // @ts-expect-error matchMedia olmayan ortam (SSR/eski tarayıcı)
    window.matchMedia = undefined;
    expect(renderHook(() => useIsNarrow()).result.current).toBe(false);
    window.matchMedia = saved;
  });

  it('ScrollShadow: bölge adı, odaklanabilir, taşma yokken gölge/ipucu yok', () => {
    const { container } = renderWithProviders(
      <ScrollShadow ariaLabel="Kullanıcı tablosu">
        <div>geniş içerik</div>
      </ScrollShadow>,
    );
    const region = screen.getByRole('region', { name: 'Kullanıcı tablosu' });
    expect(region).toHaveAttribute('tabindex', '0');
    expect(container.firstElementChild).toHaveAttribute('data-end', 'false');
    expect(screen.queryByText('Daha fazlasını görmek için yana kaydırın')).toBeNull();
  });

  it('ScrollShadow: taşan içerikte uç gölgesi ve ipucu, kaydırınca ipucu kaybolur', () => {
    const { container } = renderWithProviders(
      <ScrollShadow>
        <div>geniş içerik</div>
      </ScrollShadow>,
    );
    const region = screen.getByRole('region', { name: 'Yana kaydırılabilir alan' });
    Object.defineProperty(region, 'scrollWidth', { configurable: true, value: 800 });
    Object.defineProperty(region, 'clientWidth', { configurable: true, value: 300 });
    fireEvent.scroll(region);
    expect(container.firstElementChild).toHaveAttribute('data-end', 'true');
    expect(container.firstElementChild).toHaveAttribute('data-start', 'false');
    expect(screen.getByText('Daha fazlasını görmek için yana kaydırın')).toBeInTheDocument();
    region.scrollLeft = 120;
    fireEvent.scroll(region);
    expect(container.firstElementChild).toHaveAttribute('data-start', 'true');
    expect(screen.queryByText('Daha fazlasını görmek için yana kaydırın')).toBeNull();
    // RTL: negatif scrollLeft mutlak değerle okunur
    region.scrollLeft = -500;
    fireEvent.scroll(region);
    expect(container.firstElementChild).toHaveAttribute('data-end', 'false');
  });

  it('ActionBar çocukları sarar', () => {
    renderWithProviders(
      <ActionBar align="end" data-testid="bar">
        <button>Dışa aktar</button>
        <button>Yenile</button>
      </ActionBar>,
    );
    expect(screen.getByTestId('bar').children).toHaveLength(2);
  });
});
