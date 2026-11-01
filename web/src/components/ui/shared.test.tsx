import { fireEvent, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { ApiError } from '../../api/client';
import { DismissibleBand, MaintenanceBand } from '../../layouts/ShellBands';
import { adminNav } from '../../layouts/adminNav';
import { renderWithProviders } from '../../test/utils';
import { BulkBar, ErrorState, FilterPanel, Input, ProgressBar, Table, Tabs, type Column } from './index';

/**
 * SHARED (ortak bileşen) denetim düzeltmeleri: AUD1 ORT-1..13, AUD2 X-1..13, AUD3 G1-G9, AUD4 G1-G12.
 * CSS sözleşmeleri dosya içeriğinden denetlenir (jsdom düzen/medya sorgusu hesaplamaz).
 */
const root = process.cwd();
const css = (p: string) => readFileSync(join(root, 'src', p), 'utf-8');
const ui = (n: string) => css(`components/ui/${n}`);

/** Belirli bir `@media` bloğunun gövdesi (iç içe süslü parantezli) ya da null. */
function mediaBlock(src: string, headMatch: RegExp): string | null {
  const m = headMatch.exec(src);
  if (!m) return null;
  let i = src.indexOf('{', m.index);
  const start = i + 1;
  let depth = 0;
  for (; i < src.length; i++) {
    if (src[i] === '{') depth++;
    else if (src[i] === '}') {
      depth--;
      if (depth === 0) return src.slice(start, i);
    }
  }
  return null;
}

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
afterEach(() => {
  mockMedia(false);
  window.sessionStorage.clear();
});

describe('renk anlamı (AUD1 ORT-8/9, AUD2 X-5/X-6, AUD3 G4, AUD4 G9)', () => {
  it('primary rozet marka kırmızısı değil bilgi tonudur; kırmızı yalnız danger', () => {
    const badge = ui('Badge.module.css');
    const primary = /\.primary\s*\{([^}]*)\}/.exec(badge)![1];
    expect(primary).toContain('--info');
    expect(primary).not.toMatch(/--primary|--danger/);
    expect(/\.danger\s*\{([^}]*)\}/.exec(badge)![1]).toContain('--danger');
  });

  it('seçili satır/kart nötr-mavi vurgu (kırmızı çerçeve yok)', () => {
    expect(ui('ResponsiveTable.module.css')).toMatch(/\.card\[data-selected\]\s*\{[^}]*--select-border/);
    expect(ui('ResponsiveTable.module.css')).not.toMatch(/\.card\[data-selected\]\s*\{[^}]*var\(--primary\)/);
    expect(ui('Table.module.css')).toMatch(/\[data-selected\] td\s*\{[^}]*--select-bg/);
  });

  it('tehlike düğmesi renge ek simge taşır; satır içi sürümü çerçeveli (outline)', () => {
    const b = ui('Button.module.css');
    expect(b).toMatch(/\.danger::before\s*\{[^}]*mask/);
    expect(b).toMatch(/\.dangerOutline\s*\{[^}]*background:\s*transparent/);
  });

  it('metin kutusu üzerine gelince kırmızıya dönmez', () => {
    expect(/\.control:hover:not\(:disabled\)\s*\{([^}]*)\}/.exec(ui('Fields.module.css'))![1]).not.toContain('--primary');
  });

  it('yönetim alanında bağlantı rengi bilgi mavisi', () => {
    expect(css('styles/tokens.css')).toMatch(/html:root\[data-area='admin'\]\s*\{\s*--link:\s*var\(--info\)/);
  });

  it('yönetim bağlantı kuralı koyu tema bloklarını özgüllükle yener (koyu temada kırmızı kalmaz)', () => {
    const src = css('styles/tokens.css').replace(/\/\*[\s\S]*?\*\//g, '');
    // (id, sınıf/öznitelik/sözde sınıf, öğe) özgüllüğü; :not(...) argümanı sayılır
    const specificity = (sel: string): [number, number, number] => {
      const flat = sel.replace(/:not\(([^)]*)\)/g, ' $1 ');
      const ids = (flat.match(/#[\w-]+/g) ?? []).length;
      const cls = (flat.match(/\.[\w-]+|\[[^\]]+\]|:(?!:)[\w-]+(?:\([^)]*\))?/g) ?? []).length;
      const els = (flat.match(/(?:^|[\s>+~])[a-z][\w-]*/gi) ?? []).length;
      return [ids, cls, els];
    };
    const cmp = (a: number[], b: number[]) => a[0] - b[0] || a[1] - b[1] || a[2] - b[2];
    // --link tanımlayan kurallar, kaynak sırasıyla (media içi dahil)
    const rules: { sel: string; at: number }[] = [];
    for (const m of src.matchAll(/([^{}]+)\{([^{}]*)\}/g)) {
      if (!/--link\s*:/.test(m[2])) continue;
      const sel = m[1].trim().split('@media')[0].replace(/^[^{]*\)\s*/, '').trim();
      rules.push({ sel: sel || m[1].trim(), at: m.index ?? 0 });
    }
    const admin = rules.find((r) => r.sel.includes("data-area='admin'"))!;
    expect(admin).toBeTruthy();
    const others = rules.filter((r) => r !== admin);
    expect(others.length).toBeGreaterThanOrEqual(2); // açık + iki koyu kural
    for (const o of others) {
      expect(cmp(specificity(admin.sel), specificity(o.sel)), `${admin.sel} > ${o.sel}`).toBeGreaterThan(0);
      expect(admin.at).toBeGreaterThan(o.at);
    }
  });

  it('grafik paleti iki temada aynı sırada: 1 mavi, 2 mercan', () => {
    const tokens = css('styles/tokens.css').toLowerCase();
    const c1 = [...tokens.matchAll(/--chart-1:\s*(#[0-9a-f]{6})/g)].map((m) => m[1]);
    const c2 = [...tokens.matchAll(/--chart-2:\s*(#[0-9a-f]{6})/g)].map((m) => m[1]);
    const blueish = (hex: string) => parseInt(hex.slice(5, 7), 16) > parseInt(hex.slice(1, 3), 16);
    const redish = (hex: string) => parseInt(hex.slice(1, 3), 16) > parseInt(hex.slice(5, 7), 16);
    expect(c1).toHaveLength(3);
    c1.forEach((h) => expect(blueish(h)).toBe(true));
    c2.forEach((h) => expect(redish(h)).toBe(true));
  });

  it('ProgressBar: bitince yeşil, sürerken mavi, kırmızı yalnız danger', () => {
    const { rerender } = renderWithProviders(<ProgressBar value={100} label="Gönderim" />);
    const bar = () => screen.getByRole('progressbar', { name: 'Gönderim' });
    expect(bar().firstElementChild!.className).toMatch(/barsuccess/);
    rerender(<ProgressBar value={40} label="Gönderim" />);
    expect(bar().firstElementChild!.className).toMatch(/barinfo/);
    expect(bar()).toHaveAttribute('aria-valuenow', '40');
    rerender(<ProgressBar value={40} label="Gönderim" tone="danger" />);
    expect(bar().firstElementChild!.className).toMatch(/bardanger/);
    rerender(<ProgressBar value={null} label="Gönderim" showLabel />);
    expect(screen.getByRole('progressbar')).not.toHaveAttribute('aria-valuenow');
  });
});

describe('dokunma hedefleri (AUD1 ORT-5, AUD2 X-2, AUD3 G2, AUD4 G3)', () => {
  const touch = /@media\s*\(hover:\s*none\),\s*\(pointer:\s*coarse\),\s*\(max-width:\s*639\.98px\)/;

  it('Button sm / IconButton sm dokunmatik ve telefonda 44 px', () => {
    const block = mediaBlock(ui('Button.module.css'), touch)!;
    expect(block).toMatch(/\.sm\s*\{\s*min-height:\s*44px/);
    expect(block).toMatch(/\.icon-sm\s*\{\s*width:\s*44px;\s*height:\s*44px/);
  });

  it('onay kutusu 24 px + etiket satırı 44 px; tablo seçim hücresi 44x44', () => {
    const f = mediaBlock(ui('Fields.module.css'), touch)!;
    expect(f).toMatch(/min-block-size:\s*44px/);
    expect(f).toMatch(/\.checkInput\s*\{[^}]*inline-size:\s*24px/);
    const t = mediaBlock(ui('Table.module.css'), touch)!;
    expect(t).toMatch(/\.pick\s*\{[^}]*min-inline-size:\s*44px[^}]*min-block-size:\s*44px/);
    expect(t).toMatch(/\.sortBtn\s*\{[^}]*min-height:\s*44px/);
    expect(t).toMatch(/\.table td,\s*\.table th\s*\{\s*height:\s*44px/);
  });

  it('yalın onay kutusu/radyo/tarih girdisi için genel dokunma kuralı (özgüllük 0)', () => {
    const g = mediaBlock(css('styles/global.css'), touch)!;
    expect(g).toMatch(/:where\(input\[type='checkbox'\], input\[type='radio'\]\)/);
    expect(g).toMatch(/input\[type='date'\]/);
    expect(g).toMatch(/min-block-size:\s*44px/);
  });

  it('Tabs dokunmatikte 44 px; AdminLayout üst çubuk/arama/hesap düğmesi 44 px', () => {
    expect(mediaBlock(ui('Tabs.module.css'), touch)).toMatch(/min-height:\s*44px/);
    const layout = css('layouts/AdminLayout.module.css');
    expect(layout).toMatch(/\.searchBtn\s*\{[^}]*min-height:\s*44px/);
    expect(css('layouts/UserMenu.module.css')).toMatch(/\.trigger\s*\{[^}]*min-height:\s*44px[^}]*min-width:\s*44px/);
  });

  it('Table satır seçim kutusu etiketle sarılı (geniş dokunma alanı), erişilebilir adı korur', () => {
    const cols: Column<{ id: number }>[] = [{ key: 'id', header: 'No' }];
    renderWithProviders(
      <Table
        columns={cols}
        rows={[{ id: 1 }]}
        rowKey={(r) => r.id}
        selectedKeys={new Set()}
        onSelectionChange={() => {}}
      />,
    );
    const box = screen.getByRole('checkbox', { name: 'Satırı seç' });
    expect(box.closest('label')).not.toBeNull();
  });
});

describe('Table telefonda (AUD1 ORT-1, AUD2 X-1, AUD3 G1)', () => {
  it('iç içe dikey kaydırma telefonda kalkar; başlık sarılır', () => {
    const t = mediaBlock(ui('Table.module.css'), /@media\s*\(max-width:\s*639\.98px\)\s*\{\s*\/\* telefonda/)!;
    expect(t).toMatch(/\.scroll\s*\{[^}]*max-height:\s*none/);
    expect(t).toMatch(/\.table th\s*\{[^}]*white-space:\s*normal/);
  });

  it('kenar gölgesi ve kaydırma ipucu iskeleti: data-start/data-end, taşma yokken ipucu yok', () => {
    const cols: Column<{ id: number }>[] = [{ key: 'id', header: 'No' }];
    const { container } = renderWithProviders(<Table columns={cols} rows={[{ id: 1 }]} rowKey={(r) => r.id} />);
    const frame = container.querySelector('[data-end]')!;
    expect(frame).toHaveAttribute('data-end', 'false');
    expect(frame).toHaveAttribute('data-start', 'false');
    expect(screen.queryByText('Daha fazlasını görmek için yana kaydırın')).toBeNull();
  });

  it('taşan tabloda ipucu görünür, kaydırınca kaybolur', () => {
    const cols: Column<{ id: number }>[] = [{ key: 'id', header: 'No' }];
    const { container } = renderWithProviders(<Table columns={cols} rows={[{ id: 1 }]} rowKey={(r) => r.id} />);
    const scroller = container.querySelector('[tabindex="0"]') as HTMLElement;
    Object.defineProperty(scroller, 'scrollWidth', { configurable: true, value: 900 });
    Object.defineProperty(scroller, 'clientWidth', { configurable: true, value: 300 });
    fireEvent.scroll(scroller);
    expect(container.querySelector('[data-end]')).toHaveAttribute('data-end', 'true');
    expect(screen.getByText('Daha fazlasını görmek için yana kaydırın')).toBeInTheDocument();
    scroller.scrollLeft = 120;
    fireEvent.scroll(scroller);
    expect(container.querySelector('[data-start]')).toHaveAttribute('data-start', 'true');
    expect(screen.queryByText('Daha fazlasını görmek için yana kaydırın')).toBeNull();
  });

  it('mobile="cards": dar ekranda kart yığını, geniş ekranda tablo', () => {
    const cols: Column<{ id: number; ad: string }>[] = [
      { key: 'ad', header: 'Ad', card: { priority: 1 } },
      { key: 'id', header: 'No' },
    ];
    const rows = [{ id: 7, ad: 'Ayşe' }];
    mockMedia(true);
    const { unmount } = renderWithProviders(
      <Table columns={cols} rows={rows} rowKey={(r) => r.id} mobile="cards" />,
    );
    expect(screen.queryByRole('table')).toBeNull();
    expect(screen.getByRole('list')).toBeInTheDocument();
    unmount();
    mockMedia(false);
    renderWithProviders(<Table columns={cols} rows={rows} rowKey={(r) => r.id} mobile="cards" />);
    expect(screen.getByRole('table')).toBeInTheDocument();
  });
});

describe('Tabs taşması (AUD1 ORT-2, AUD3 G3)', () => {
  it('çubuk kenar gölgesi taşır; seçili sekme görünür alana kaydırılır', () => {
    const tabs = Array.from({ length: 8 }, (_, i) => ({ id: `t${i}`, label: `Sekme ${i}` }));
    const { container, rerender } = renderWithProviders(
      <Tabs tabs={tabs} value="t0" onChange={() => {}} label="Bölümler" />,
    );
    const bar = container.querySelector('[data-end]')!;
    expect(bar).toHaveAttribute('data-end', 'false');
    const list = screen.getByRole('tablist');
    Object.defineProperty(list, 'scrollWidth', { configurable: true, value: 900 });
    Object.defineProperty(list, 'clientWidth', { configurable: true, value: 300 });
    list.getBoundingClientRect = () => ({ left: 0, right: 300 }) as DOMRect;
    const target = screen.getByRole('tab', { name: 'Sekme 7' });
    target.getBoundingClientRect = () => ({ left: 700, right: 800 }) as DOMRect;
    rerender(<Tabs tabs={tabs} value="t7" onChange={() => {}} label="Bölümler" />);
    expect(list.scrollLeft).toBeGreaterThan(0);
  });

  it('kaydırma gölgesi CSS: taşan kenarda görünür', () => {
    expect(ui('Tabs.module.css')).toMatch(/\.bar\[data-end='true'\] \.shadeEnd/);
  });
});

describe('Drawer/Modal telefonda (AUD2 X-10)', () => {
  it('telefonda tam genişlik; kapatma düğmesi küçülmez, uzun başlık kırılır', () => {
    const o = ui('Overlay.module.css');
    expect(o).toMatch(/\.head > button\s*\{\s*flex:\s*none/);
    expect(/\.title\s*\{([^}]*)\}/.exec(o)![1]).toMatch(/min-width:\s*0[\s\S]*overflow-wrap:\s*anywhere/);
    expect(/\.body\s*\{([^}]*)\}/.exec(o)![1]).toContain('overflow-wrap: anywhere');
    const phone = mediaBlock(o, /@media\s*\(max-width:\s*639\.98px\)/)!;
    expect(phone).toMatch(/\.drawer\s*\{[^}]*width:\s*100%/);
    expect(phone).toMatch(/\.modal\s*\{[^}]*max-width:\s*none/);
  });

  it('ortak taşma yardımcısı .wrap-any tanımlı', () => {
    expect(css('styles/global.css')).toMatch(/\.wrap-any\s*\{[^}]*overflow-wrap:\s*anywhere/);
  });
});

describe('kontrast (AUD1 ORT-7, AUD2 X-13/PL-4)', () => {
  it('"Seçimi temizle" koyu çubukta beyaz yazı; düğmeye sınıf bağlı', () => {
    const { container } = renderWithProviders(
      <BulkBar count={2} onClear={() => {}}>
        <button>Sil</button>
      </BulkBar>,
    );
    const clear = screen.getByRole('button', { name: 'Seçimi temizle' });
    expect(clear.className).toMatch(/clear/);
    expect(container).toBeTruthy();
    expect(ui('BulkBar.module.css')).toMatch(/\.bar \.clear\s*\{[^}]*color:\s*#fff/);
  });

  it('grafik açıklaması metni seri renginde değil okunur renkte', () => {
    expect(css('styles/global.css')).toMatch(/\.recharts-legend-item-text\s*\{[^}]*color:\s*var\(--text\)/);
    expect(css('components/charts/charts.module.css')).toMatch(/recharts-legend-item-text/);
  });
});

describe('hata durumu (AUD1 ORT-4, AUD2 G5/AUD3 G8)', () => {
  it('konu verilince başlık "X yüklenemedi" olur', () => {
    renderWithProviders(<ErrorState subject="Kulüp listesi" />);
    expect(screen.getByRole('heading', { name: 'Kulüp listesi yüklenemedi' })).toBeInTheDocument();
  });

  it('neden ayrımı: bağlantı yok / yetki yok (yeniden dene gizli) / sunucu', () => {
    const retry = vi.fn();
    const { rerender } = renderWithProviders(
      <ErrorState subject="Mail kuyruğu" error={new ApiError(0, 'NETWORK_ERROR', 'x')} onRetry={retry} />,
    );
    expect(screen.getByText(/İnternet bağlantınızı kontrol edin/)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Tekrar dene' })).toBeInTheDocument();
    rerender(<ErrorState subject="Mail kuyruğu" error={new ApiError(403, 'X', 'x')} onRetry={retry} />);
    expect(screen.getByText(/yetkiniz yok/)).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Tekrar dene' })).toBeNull();
    rerender(<ErrorState subject="Mail kuyruğu" error={new ApiError(500, 'X', 'x')} onRetry={retry} />);
    expect(screen.getByText(/Sunucu şu an yanıt vermiyor/)).toBeInTheDocument();
  });

  it('inline: tek satır, konu + neden + yeniden dene', async () => {
    const retry = vi.fn();
    renderWithProviders(<ErrorState inline subject="Özet kartları" error={new ApiError(500, 'X', 'x')} onRetry={retry} />);
    const box = screen.getByRole('alert');
    expect(box).toHaveTextContent('Özet kartları yüklenemedi');
    await userEvent.setup().click(screen.getByRole('button', { name: 'Tekrar dene' }));
    expect(retry).toHaveBeenCalledTimes(1);
  });

  it('geriye uyum: parametresiz ErrorState eski genel metni gösterir', () => {
    renderWithProviders(<ErrorState />);
    expect(screen.getByRole('heading', { name: 'Veriler yüklenemedi' })).toBeInTheDocument();
  });
});

describe('kabuk bantları (AUD4 G7/1.2)', () => {
  it('bakım bandı: ileti dokununca açılır/kapanır', async () => {
    const user = userEvent.setup();
    renderWithProviders(<MaintenanceBand message="Saat 03:00'e kadar" />);
    expect(screen.getByText('Bakım modu açık')).toBeInTheDocument();
    const msg = screen.getByRole('button', { name: /Saat 03:00/ });
    expect(msg).toHaveAttribute('aria-expanded', 'false');
    await user.click(msg);
    expect(msg).toHaveAttribute('aria-expanded', 'true');
  });

  it('depolama bandı: CRIT kapatılamaz, WARN oturum boyunca gizlenir', async () => {
    const user = userEvent.setup();
    window.sessionStorage.clear();
    const crit = renderWithProviders(
      <DismissibleBand>
        <div data-testid="storage-banner" data-status="CRIT">
          kritik
        </div>
      </DismissibleBand>,
    );
    await user.click(screen.getByRole('button', { name: 'Uyarıyı bu oturumda gizle' }));
    expect(crit.container.firstElementChild).not.toHaveAttribute('data-dismissed');
    crit.unmount();

    const { container } = renderWithProviders(
      <DismissibleBand>
        <div data-testid="storage-banner" data-status="WARN">
          uyarı
        </div>
      </DismissibleBand>,
    );
    const wrap = container.firstElementChild as HTMLElement;
    expect(wrap).not.toHaveAttribute('data-dismissed');
    await user.click(screen.getByRole('button', { name: 'Uyarıyı bu oturumda gizle' }));
    expect(wrap).toHaveAttribute('data-dismissed', 'WARN');
    expect(window.sessionStorage.getItem('bu.admin.storageband')).toBe('WARN');
  });

  it('telefonda bantlar tek satır: sınır CSS\'te', () => {
    const l = css('layouts/AdminLayout.module.css');
    const phone = mediaBlock(l, /@media \(max-width: 719px\)\s*\{\s*\.maintenance/)!;
    expect(phone).toMatch(/\.maintenance\s*\{[^}]*flex-wrap:\s*nowrap/);
    expect(phone).toMatch(/storage-banner'\]\s*\{[^}]*flex-wrap:\s*nowrap/);
    expect(l).toMatch(/\.dismissable\[data-dismissed='WARN'\] \[data-testid='storage-banner'\]/);
  });
});

describe('menü simgeleri (AUD1 ORT-6, AUD4 G10/1.3)', () => {
  it('aynı grupta iki sayfa aynı simgeyi kullanmaz; Sistem durumu Analitik ile aynı değil', () => {
    for (const g of adminNav) {
      const icons = g.items.map((i) => i.icon);
      expect(new Set(icons).size, g.id).toBe(icons.length);
    }
    const all = adminNav.flatMap((g) => g.items);
    expect(all.find((i) => i.id === 'system')!.icon).not.toBe(all.find((i) => i.id === 'analytics')!.icon);
    // tüm menüde en çok 2 tekrar (uzak gruplarda); rail'de ayırt edilebilirlik
    const counts = new Map<string, number>();
    all.forEach((i) => counts.set(i.icon, (counts.get(i.icon) ?? 0) + 1));
    expect(Math.max(...counts.values())).toBeLessThanOrEqual(2);
  });
});

describe('hata iskeleti süresi (AUD3 G8)', () => {
  it('react-query tek kısa yeniden deneme yapar', async () => {
    const { makeQueryClient } = await import('../../App');
    const q = makeQueryClient().getDefaultOptions().queries!;
    const retry = q.retry as (n: number, e: unknown) => boolean;
    expect(retry(0, new Error('5xx'))).toBe(true);
    expect(retry(1, new Error('5xx'))).toBe(false);
    expect(retry(0, new ApiError(404, 'X', 'x'))).toBe(false);
    expect(q.retryDelay).toBe(800);
  });
});

describe('FilterPanel (AUD2 X-3, AUD3 G5, AUD4 G2)', () => {
  it('geniş ekranda alanlar açık, katlama düğmesi yok', () => {
    renderWithProviders(
      <FilterPanel activeCount={2}>
        <Input aria-label="Ara" />
      </FilterPanel>,
    );
    expect(screen.queryByRole('button', { name: /Süzgeçler/ })).toBeNull();
    expect(screen.getByRole('textbox', { name: 'Ara' })).toBeVisible();
  });

  it('telefonda "Süzgeçler (2)" düğmesi: alanlar katlı, çipler görünür, açınca alanlar belirir', async () => {
    mockMedia(true);
    const onRemove = vi.fn();
    const onClear = vi.fn();
    const user = userEvent.setup();
    renderWithProviders(
      <FilterPanel
        activeCount={2}
        onClear={onClear}
        chips={[{ key: 'durum', label: 'Durum: Açık', onRemove }]}
      >
        <Input aria-label="Ara" />
      </FilterPanel>,
    );
    const toggle = screen.getByRole('button', { name: /Süzgeçler \(2\)/ });
    expect(toggle).toHaveAttribute('aria-expanded', 'false');
    expect(screen.queryByRole('textbox', { name: 'Ara' })).toBeNull(); // hidden: erişilebilirlik ağacında yok
    await user.click(screen.getByRole('button', { name: 'Durum: Açık süzgecini kaldır' }));
    expect(onRemove).toHaveBeenCalledTimes(1);
    await user.click(screen.getByRole('button', { name: 'Süzgeçleri temizle' }));
    expect(onClear).toHaveBeenCalledTimes(1);
    await user.click(toggle);
    expect(toggle).toHaveAttribute('aria-expanded', 'true');
    expect(screen.getByRole('textbox', { name: 'Ara' })).toBeVisible();
  });
});
