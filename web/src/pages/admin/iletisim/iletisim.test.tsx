// İletişim grubu görsel özetleri: dağılım çubuğu, talep özeti (grafik + cümle + hata/boş durumları), kuyruk sağlığı, engel özeti.
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import { StackedShare } from '../../../components/kit/StackedShareIletisim';
import { jsonResponse, mockFetch } from '../../../test/fetchMock';
import { renderWithProviders } from '../../../test/utils';
import dict from './dict';
import { FeedbackOverview } from './FeedbackOverview';
import { QueueHealth } from './QueueHealth';
import { SuppressionOverview } from './SuppressionOverview';
import { TicketsOverview } from './TicketsOverview';

const now = Date.now();
const ago = (ms: number) => new Date(now - ms).toISOString();
const D = 24 * 3_600_000;

describe('StackedShare', () => {
  const segs = [
    { key: 'a', label: 'Bekleyen', value: 3, tone: 'warning' as const },
    { key: 'b', label: 'Biten', value: 1, tone: 'success' as const },
  ];
  it('şerit ve açıklama aynı sayıları ve yüzdeleri metinle verir', () => {
    renderWithProviders(<StackedShare segments={segs} ariaLabel="Dağılım" />);
    expect(screen.getByRole('img')).toHaveAttribute(
      'aria-label',
      expect.stringContaining('Bekleyen: 3 (%75)'),
    );
    expect(screen.getByText('%25')).toBeInTheDocument();
  });
  it('satıra basınca onSelect çağrılır ve seçili satır işaretlenir', async () => {
    const onSelect = vi.fn();
    renderWithProviders(
      <StackedShare segments={segs} ariaLabel="Dağılım" onSelect={onSelect} selectedKey="b" />,
    );
    const rows = screen.getAllByRole('button');
    expect(rows).toHaveLength(2);
    expect(rows[1]).toHaveAttribute('aria-pressed', 'true');
    await userEvent.setup().click(rows[0]);
    expect(onSelect).toHaveBeenCalledWith('a');
  });
  it('hepsi sıfırsa boş şerit ve yüzde yerine tire yazar, çökmez', () => {
    renderWithProviders(
      <StackedShare segments={segs.map((s) => ({ ...s, value: 0 }))} ariaLabel="Dağılım" />,
    );
    expect(screen.getAllByText('–').length).toBeGreaterThan(0);
  });
  it('negatif ve geçersiz değerler 0 sayılır', () => {
    renderWithProviders(
      <StackedShare
        segments={[
          { key: 'a', label: 'A', value: -4, tone: 'info' },
          { key: 'b', label: 'B', value: Number.NaN, tone: 'info' },
          { key: 'c', label: 'C', value: 2, tone: 'info' },
        ]}
        ariaLabel="Dağılım"
      />,
    );
    expect(screen.getByRole('img')).toHaveAttribute('aria-label', expect.stringContaining('C: 2 (%100)'));
  });
});

describe('TicketsOverview', () => {
  function setup(opts: { fail?: boolean; open?: number; items?: { id: number; updatedAt: string }[] } = {}) {
    mockFetch((url) => {
      if (url.includes('/admin/analytics/support')) {
        if (opts.fail) return jsonResponse(500, { code: 'X', message: 'hata' });
        return jsonResponse(200, {
          tickets: { open: opts.open ?? 4, answered: 6, closed: 10 },
          avgFirstResponseMinutes: 150,
          feedbackByCategory: [],
          feedbackByStatus: [],
        });
      }
      if (url.includes('/admin/support/tickets'))
        return jsonResponse(200, {
          items: (
            opts.items ?? [
              { id: 1, updatedAt: ago(2 * 3_600_000) },
              { id: 2, updatedAt: ago(5 * D) },
            ]
          ).map((x) => ({
            ...x,
            userId: 1,
            userEmail: 'a@bingol.edu.tr',
            publicTicket: false,
            category: 'OTHER',
            subject: 's',
            status: 'OPEN',
            createdAt: x.updatedAt,
          })),
          nextCursor: null,
        });
      return jsonResponse(404, { code: 'NF', message: 'yok' });
    });
  }

  it('toplam sayıları, ilk yanıt süresini ve 3 günü aşan talep uyarısını gösterir', async () => {
    setup();
    const onStatus = vi.fn();
    renderWithProviders(<TicketsOverview status="" onStatus={onStatus} />);
    expect(await screen.findByText('4 talep yanıtınızı bekliyor.')).toBeInTheDocument();
    expect(screen.getByText(/3 günden uzun bekleyen 1 talep var/)).toBeInTheDocument();
    expect(screen.getByText('2,5')).toBeInTheDocument(); // 150 dk = 2,5 sa
    expect(screen.getByText(/İyi: bir günün altında/)).toBeInTheDocument();
    // yaş grafiği yorumu
    expect(await screen.findByText(/2 bekleyen talebin 1 tanesi 3 günden uzun/)).toBeInTheDocument();
    // yığılmış çubuk: yüzdeler (4/20, 6/20, 10/20)
    const list = screen.getByRole('list', { name: /Tüm talepler \(20\)/ });
    expect(within(list).getByText('%50')).toBeInTheDocument();
    await userEvent.setup().click(within(list).getByRole('button', { name: /Yanıt bekliyor/ }));
    expect(onStatus).toHaveBeenCalledWith('OPEN');
  });

  it('seçili duruma yeniden basınca süzgeci kaldırır', async () => {
    setup();
    const onStatus = vi.fn();
    renderWithProviders(<TicketsOverview status="CLOSED" onStatus={onStatus} />);
    const list = await screen.findByRole('list', { name: /Tüm talepler/ });
    await userEvent.setup().click(within(list).getByRole('button', { name: /Kapandı/ }));
    expect(onStatus).toHaveBeenCalledWith('');
  });

  it('bekleyen talep yoksa olumlu cümle ve boş grafik durumu gösterir', async () => {
    setup({ open: 0, items: [] });
    renderWithProviders(<TicketsOverview status="" onStatus={() => {}} />);
    expect(await screen.findByText('Yanıt bekleyen talep yok, hepsiyle ilgilenilmiş.')).toBeInTheDocument();
    expect(await screen.findByText('Bekleyen talep yok, gösterilecek bir şey kalmadı.')).toBeInTheDocument();
  });

  it('toplu sayılar yüklenemezse hata gösterir ve yeniden dene sunar', async () => {
    setup({ fail: true });
    renderWithProviders(<TicketsOverview status="" onStatus={() => {}} />);
    expect((await screen.findAllByRole('alert')).length).toBeGreaterThan(0);
    expect(screen.getAllByRole('button', { name: /Tekrar dene|Yeniden dene/i }).length).toBeGreaterThan(0);
  });
});

describe('FeedbackOverview', () => {
  it('tüm geri bildirimlerin durum dağılımını sunucu toplamından kurar ve süzgece bağlar', async () => {
    mockFetch(() =>
      jsonResponse(200, {
        tickets: { open: 0, answered: 0, closed: 0 },
        avgFirstResponseMinutes: null,
        feedbackByCategory: [
          { key: 'BUG', count: 7 },
          { key: 'PRAISE', count: 1 },
        ],
        feedbackByStatus: [
          { key: 'NEW', count: 6 },
          { key: 'DONE', count: 2 },
        ],
      }),
    );
    const onStatus = vi.fn();
    renderWithProviders(<FeedbackOverview status="" onStatus={onStatus} />);
    expect(await screen.findByText(/8 geri bildirimin 6 tanesi hâlâ yeni/)).toBeInTheDocument();
    const list = screen.getByRole('list', { name: 'Geri bildirimlerin durumu' });
    expect(within(list).getByText('%75')).toBeInTheDocument();
    await userEvent.setup().click(within(list).getByRole('button', { name: /Planlandı/ }));
    expect(onStatus).toHaveBeenCalledWith('PLANNED');
    // türler: sayısı 0 olanlar çubuk listesine girmez
    const cats = screen.getByRole('list', { name: 'Ne hakkında yazıyorlar?' });
    expect(within(cats).getAllByRole('listitem')).toHaveLength(2);
  });
});

describe('QueueHealth', () => {
  const labels = { pending: 'Bekliyor', failed: 'Başarısız', dead: 'Ölü' };
  it('ölü kayıt varsa "Müdahale gerekli" der ve süzgece bağlanır', async () => {
    const onSelect = vi.fn();
    renderWithProviders(
      <QueueHealth
        title="Kuyruk"
        ariaLabel="Kuyruk"
        counts={{ pending: 4, failed: 1, dead: 3 }}
        labels={labels}
        onSelect={onSelect}
        sentLast24h={120}
      />,
    );
    expect(screen.getByText('Müdahale gerekli')).toBeInTheDocument();
    expect(screen.getByText(/3 kayıt gönderilemedi/)).toBeInTheDocument();
    expect(screen.getByText(/Son 24 saatte 120 gönderildi/)).toBeInTheDocument();
    await userEvent.setup().click(screen.getByRole('button', { name: /Ölü/ }));
    expect(onSelect).toHaveBeenCalledWith('dead');
  });
  it('sorun yoksa "Sorunsuz" der ve süzgeç ipucu göstermez', () => {
    renderWithProviders(
      <QueueHealth
        title="Kuyruk"
        ariaLabel="Kuyruk"
        counts={{ pending: 2, failed: 0, dead: 0 }}
        labels={labels}
        onSelect={() => {}}
      />,
    );
    expect(screen.getByText('Sorunsuz')).toBeInTheDocument();
    expect(screen.getByText('Kuyruk temiz, takılan kayıt yok.')).toBeInTheDocument();
    expect(screen.queryByText(/dokunursanız/)).toBeNull();
  });
  it('yalnız başarısız varsa "Dikkat" der', () => {
    renderWithProviders(
      <QueueHealth
        title="Kuyruk"
        ariaLabel="Kuyruk"
        counts={{ pending: 0, failed: 2, dead: 0 }}
        labels={labels}
      />,
    );
    expect(screen.getByText('Dikkat')).toBeInTheDocument();
    expect(screen.getByText(/2 kayıt geçici hata aldı/)).toBeInTheDocument();
  });
});

describe('SuppressionOverview', () => {
  it('her neden için toplam ister, dağılımı gösterir; şikâyet varsa uyarır', async () => {
    const totals: Record<string, number> = { UNSUBSCRIBED: 5, BOUNCED: 2, COMPLAINT: 1, MANUAL: 0 };
    const fn = mockFetch((url) => {
      const reason = new URL(url, 'http://x').searchParams.get('reason') ?? '';
      return jsonResponse(200, { items: [], page: 0, size: 1, total: totals[reason] ?? 0, totalPages: 0 });
    });
    const onReason = vi.fn();
    renderWithProviders(<SuppressionOverview reason="" onReason={onReason} />);
    expect(await screen.findByText(/1 kişi e-postayı spam olarak işaretledi/)).toBeInTheDocument();
    expect(fn).toHaveBeenCalledTimes(4);
    await userEvent.setup().click(screen.getByRole('button', { name: /Şikâyet|Şikayet/i }));
    expect(onReason).toHaveBeenCalledWith('COMPLAINT');
  });
  it('hiç engelli adres yoksa hiçbir şey çizmez', async () => {
    mockFetch(() => jsonResponse(200, { items: [], page: 0, size: 1, total: 0, totalPages: 0 }));
    const { container } = renderWithProviders(<SuppressionOverview reason="" onReason={() => {}} />);
    await waitFor(() => expect(container.querySelector('[aria-busy="true"]')).toBeNull());
    expect(container.querySelector('section')).toBeNull();
  });
});

// ---- sözlük bütünlüğü: kaynakta kullanılan her admin.il.* anahtarı sözlükte var ----
function walk(dir: string, out: string[] = []): string[] {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) walk(p, out);
    else if (/\.(tsx|ts)$/.test(name) && !/\.test\.tsx?$/.test(name) && name !== 'dict.ts') out.push(p);
  }
  return out;
}

describe('iletisim sözlüğü', () => {
  const src = join(process.cwd(), 'src');
  const text = [...walk(join(src, 'pages')), ...walk(join(src, 'components'))]
    .map((f) => readFileSync(f, 'utf-8'))
    .join('\n');
  const used = new Set<string>();
  for (const m of text.matchAll(/['"`](admin\.il\.[A-Za-z0-9_.]+)(\$\{[^}]*\})?['"`]/g)) {
    if (m[2]) used.add(`${m[1]}*`);
    else used.add(m[1]);
  }

  it('sabit anahtarların hepsi tanımlı', () => {
    const missing = [...used].filter((k) => !k.endsWith('*') && !(k in dict));
    expect(missing).toEqual([]);
  });
  it('şablonlu anahtarların her öneki en az bir karşılığa sahip', () => {
    const missing = [...used]
      .filter((k) => k.endsWith('*'))
      .filter((k) => !Object.keys(dict).some((d) => d.startsWith(k.slice(0, -1))));
    expect(missing).toEqual([]);
  });
  it('boş değer ve apostrof kaynaklı yer tutucu bozulması yok', () => {
    for (const [k, v] of Object.entries(dict)) {
      expect(v.trim(), k).not.toBe('');
      for (const ph of v.match(/\{\w+\}/g) ?? []) expect(ph, k).toMatch(/^\{[a-zA-Z]+\}$/);
    }
  });
});
