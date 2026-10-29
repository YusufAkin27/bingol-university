import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import MenuAdminPage from './MenuAdminPage';
import {
  dishesOf,
  normalizeDate,
  parseCalorieText,
  parseKcal,
  monthRange,
  sumKcal,
  validateMenuImage,
} from './menu/menuLogic';

describe('menuLogic', () => {
  it('ay araligini hesaplar', () => {
    expect(monthRange('2026-02')).toEqual({ from: '2026-02-01', to: '2026-02-28' });
    expect(monthRange('2028-02').to).toBe('2028-02-29');
    expect(() => monthRange('2026-13')).toThrow();
  });
  it('dosyayi dogrular', () => {
    expect(validateMenuImage({ type: 'image/gif', size: 10 })).toBe('type');
    expect(validateMenuImage({ type: 'image/png', size: 6 * 1024 * 1024 })).toBe('size');
    expect(validateMenuImage({ type: 'image/webp', size: 0 })).toBe('empty');
    expect(validateMenuImage({ type: 'image/jpeg', size: 1000 })).toBeNull();
  });
});

describe('kalori mantigi', () => {
  it('kaloriyi dogrular', () => {
    expect(parseKcal('')).toEqual({ ok: true, value: null });
    expect(parseKcal(' 320 kcal ')).toEqual({ ok: true, value: 320 });
    expect(parseKcal('0')).toEqual({ ok: true, value: 0 });
    expect(parseKcal('5001')).toEqual({ ok: false });
    expect(parseKcal('-5')).toEqual({ ok: false });
    expect(parseKcal('3.5')).toEqual({ ok: false });
  });
  it('toplami hesaplar', () => {
    expect(sumKcal([null, null])).toEqual({ total: null, known: 0, complete: false });
    expect(sumKcal([100, null])).toEqual({ total: 100, known: 1, complete: false });
    expect(sumKcal([100, 0, 50])).toEqual({ total: 150, known: 3, complete: true });
  });
  it('tarihi normallestirir', () => {
    expect(normalizeDate('5.10.2026')).toBe('2026-10-05');
    expect(normalizeDate('2026-10-05')).toBe('2026-10-05');
    expect(normalizeDate('31.02.2026')).toBeNull();
    expect(normalizeDate('abc')).toBeNull();
  });
  it('eski yanitta dishes yoksa kalorisiz uretir', () => {
    expect(dishesOf({ items: ['A', 'B'] })).toEqual([
      { name: 'A', kcal: null },
      { name: 'B', kcal: null },
    ]);
  });
  it('yapistirilan metni ayristirir', () => {
    const r = parseCalorieText(
      [
        'tarih;yemek;kcal',
        '2026-10-05;MERCİMEK ÇORBASI;180',
        '05.10.2026\tPILAV; PIRINC\t300',
        '',
        'bozuk',
        '2026-13-01;X;5',
        '2026-10-06;Y;9999',
        '2026-10-06;Z;',
      ].join('\n'),
    );
    expect(r.days).toHaveLength(2);
    expect(r.days[0].items).toEqual([
      { name: 'MERCİMEK ÇORBASI', kcal: 180 },
      { name: 'PILAV; PIRINC', kcal: 300 },
    ]);
    expect(r.days[1].items).toEqual([{ name: 'Z', kcal: null }]);
    expect(r.count).toBe(3);
    expect(r.errors).toEqual([
      { line: 5, reason: 'format' },
      { line: 6, reason: 'date' },
      { line: 7, reason: 'kcal' },
    ]);
  });
});

const days = [
  { date: '2026-02-03', items: ['Corba', 'Pilav'], imageUrl: null },
  { date: '2026-02-04', items: ['Makarna'], imageUrl: '/files/menu/a.jpg' },
];

describe('MenuAdminPage', () => {
  it('listeler, gecersiz dosyayi istemcide reddeder, gecerliyi multipart yukler, kaldirmada onay ister', async () => {
    const fetchFn = mockFetch((url, init) => {
      if (url.includes('/image') && init.method === 'PUT')
        return jsonResponse(200, { date: '2026-02-03', imageUrl: '/files/menu/b.jpg' });
      if (url.includes('/image') && init.method === 'DELETE') return jsonResponse(204);
      if (url.includes('/admin/menu')) return jsonResponse(200, days);
      return jsonResponse(404, { code: 'X', message: 'x' });
    });
    renderWithProviders(<MenuAdminPage />);
    const rows = await screen.findAllByTestId('menu-row');
    expect(rows).toHaveLength(2);
    expect(fetchFn.mock.calls.some(([u]) => String(u).includes('/admin/menu?from='))).toBe(true);
    expect(within(rows[1]).getByRole('img')).toHaveAttribute('src', '/files/menu/a.jpg');

    const input = within(rows[0]).getByTestId('menu-file') as HTMLInputElement;
    await userEvent.upload(input, new File(['x'], 'a.gif', { type: 'image/gif' }), { applyAccept: false });
    expect(await within(rows[0]).findByRole('alert')).toHaveTextContent('JPEG');
    expect(fetchFn.mock.calls.some(([, i]) => (i as RequestInit).method === 'PUT')).toBe(false);

    await userEvent.upload(input, new File(['x'], 'a.png', { type: 'image/png' }));
    await waitFor(() => {
      const put = fetchFn.mock.calls.find(([, i]) => (i as RequestInit).method === 'PUT');
      expect(put).toBeTruthy();
      expect((put![1] as RequestInit).body).toBeInstanceOf(FormData);
      expect(((put![1] as RequestInit).headers as Record<string, string>)['Content-Type']).toBeUndefined();
    });

    await userEvent.click(within(rows[1]).getByRole('button', { name: /Kaldır/ }));
    const dialog = await screen.findByRole('dialog');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Kaldır' }));
    await waitFor(() =>
      expect(fetchFn.mock.calls.some(([u, i]) => String(u).includes('/2026-02-04/image') && (i as RequestInit).method === 'DELETE')).toBe(true),
    );
  });

  it('kaloriyi satir icinde duzenler, yalniz degisen yemegi kaydeder, toplami gosterir', async () => {
    const withKcal = [
      {
        date: '2026-02-03',
        items: ['Corba', 'Pilav'],
        imageUrl: null,
        dishes: [
          { name: 'Corba', kcal: 150 },
          { name: 'Pilav', kcal: null },
        ],
        totalKcal: 150,
        kcalComplete: false,
      },
    ];
    const fetchFn = mockFetch((url, init) => {
      if (url.includes('/calories') && init.method === 'PUT') return jsonResponse(200, withKcal[0]);
      if (url.includes('/admin/menu')) return jsonResponse(200, withKcal);
      return jsonResponse(404, { code: 'X', message: 'x' });
    });
    renderWithProviders(<MenuAdminPage />);
    const row = await screen.findByTestId('menu-row');
    expect(within(row).getByTestId('kcal-total')).toHaveTextContent('en az 150 kcal');
    const inputs = within(row).getAllByTestId('kcal-input') as HTMLInputElement[];
    expect(inputs[0].value).toBe('150');
    const save = within(row).getByRole('button', { name: /Kalorileri kaydet/ });
    expect(save).toBeDisabled();

    await userEvent.type(inputs[1], '99999');
    expect(await within(row).findByRole('alert')).toHaveTextContent('0 ile 5000');
    expect(save).toBeDisabled();
    await userEvent.clear(inputs[1]);
    await userEvent.type(inputs[1], '250');
    expect(within(row).getByTestId('kcal-total')).toHaveTextContent('Toplam: 400 kcal');
    await userEvent.click(save);
    await waitFor(() => {
      const put = fetchFn.mock.calls.find(([u, i]) => String(u).includes('/2026-02-03/calories') && (i as RequestInit).method === 'PUT');
      expect(put).toBeTruthy();
      expect(JSON.parse(String((put![1] as RequestInit).body))).toEqual({ items: [{ name: 'Pilav', kcal: 250 }] });
    });
  });

  it('toplu yapistirmada gecerli satirlari toplu uca gonderir ve atlananlari raporlar', async () => {
    const fetchFn = mockFetch((url, init) => {
      if (url.endsWith('/admin/menu/calories') && init.method === 'PUT')
        return jsonResponse(200, {
          updated: 1,
          cleared: 0,
          unchanged: 0,
          skipped: [{ date: '2026-02-09', name: 'X', reason: 'DAY_NOT_FOUND' }],
        });
      if (url.includes('/admin/menu')) return jsonResponse(200, days);
      return jsonResponse(404, { code: 'X', message: 'x' });
    });
    renderWithProviders(<MenuAdminPage />);
    await screen.findAllByTestId('menu-row');
    await userEvent.click(screen.getByText('Toplu kalori yapıştır'));
    await userEvent.type(screen.getByTestId('kcal-bulk-text'), '2026-02-03;Corba;150{enter}2026-02-09;X;10');
    expect(screen.getByTestId('kcal-bulk-summary')).toHaveTextContent('2 yemek okundu');
    await userEvent.click(screen.getByRole('button', { name: 'Kalorileri uygula' }));
    const dialog = await screen.findByRole('dialog');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Kalorileri uygula' }));
    expect(await screen.findByTestId('kcal-bulk-result')).toHaveTextContent('1 güncellendi');
    expect(screen.getByTestId('kcal-bulk-result')).toHaveTextContent('o güne ait menü yok');
    const put = fetchFn.mock.calls.find(([u, i]) => String(u).endsWith('/admin/menu/calories') && (i as RequestInit).method === 'PUT');
    expect(JSON.parse(String((put![1] as RequestInit).body)).days).toHaveLength(2);
  });

  it('bos ayda bos durum gosterir', async () => {
    mockFetch(() => jsonResponse(200, []));
    renderWithProviders(<MenuAdminPage />);
    expect(await screen.findByText('Bu ay için menü yok')).toBeInTheDocument();
  });

  it('sunucu hatasini gosterir', async () => {
    mockFetch(() => jsonResponse(500, { code: 'SERVER_ERROR', message: 'x' }));
    renderWithProviders(<MenuAdminPage />);
    expect(await screen.findByRole('alert')).toBeInTheDocument();
  });
});
