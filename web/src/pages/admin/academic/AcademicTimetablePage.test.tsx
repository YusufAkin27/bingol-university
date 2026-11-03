import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../../test/fetchMock';
import { renderWithProviders } from '../../../test/utils';
import AcademicTimetablePage from './AcademicTimetablePage';

afterEach(() => vi.unstubAllGlobals());

interface Call {
  url: string;
  init: RequestInit;
}

function program(i: number) {
  return {
    unit: `Birim ${i % 12}`,
    program: `Program ${i}`,
    department: `Program ${i}`,
    faculty: i % 11 === 0 ? null : 'Meslek Yüksekokulu',
    catalogMatched: i % 11 !== 0,
    grades: ['1', '2'],
    sessions: 20,
    published: true,
  };
}

function preview(dryRun: boolean, errors: { row: number; message: string }[] = []) {
  const items = Array.from({ length: 114 }, (_, i) => program(i));
  return {
    dryRun,
    term: '2026-2027 Güz',
    rows: 3396,
    programs: 114,
    inserted: dryRun ? 0 : 3396,
    replacedPrograms: 0,
    batchId: dryRun ? null : 1,
    items,
    errors,
    warnings: [{ row: 22, message: 'Program katalogda bulunamadı' }],
  };
}

function setup(errors: { row: number; message: string }[] = [], listSize = 5) {
  const calls: Call[] = [];
  mockFetch((url, init) => {
    calls.push({ url, init });
    if (url.includes('/admin/academic/timetable/import')) {
      const form = init.body as FormData;
      const dry = form.get('dryRun') === 'true';
      return jsonResponse(200, preview(dry, errors));
    }
    if (url.includes('/admin/academic/timetable/programs')) {
      return jsonResponse(200, {
        terms: [{ term: '2026-2027 Güz', sessions: 3396, programs: 114 }],
        term: '2026-2027 Güz',
        items: Array.from({ length: listSize }, (_, i) => program(i)),
      });
    }
    return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
  });
  return calls;
}

const xlsx = () =>
  new File([new Uint8Array([0x50, 0x4b, 3, 4])], 'ders-programi.xlsx', {
    type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  });

describe('Resmî ders programı sayfası', () => {
  it('dosya seçilince önizleme açılır; onaylayınca yazma isteği gider ve modal kapanır', async () => {
    const calls = setup();
    const user = userEvent.setup();
    const { container } = renderWithProviders(<AcademicTimetablePage />);
    await screen.findByText('Program 1');
    const input = container.querySelector('input[type="file"]') as HTMLInputElement;
    await user.upload(input, xlsx());

    const dialog = await screen.findByRole('dialog');
    expect(within(dialog).getByText(/3\.?396/)).toBeInTheDocument();
    const confirm = within(dialog).getByRole('button', { name: /Onayla ve yükle/ });
    expect(confirm).toBeEnabled();
    await user.click(confirm);

    await waitFor(() => {
      const writes = calls.filter((c) => c.url.includes('/timetable/import'));
      expect(writes).toHaveLength(2);
      expect((writes[1].init.body as FormData).get('dryRun')).toBe('false');
    });
    await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument());
  });

  it('önizlemede hata varsa onay düğmesi kapalıdır, İptal modalı kapatır', async () => {
    setup([{ row: 5, message: 'Sınıf geçersiz' }]);
    const user = userEvent.setup();
    const { container } = renderWithProviders(<AcademicTimetablePage />);
    await screen.findByText('Program 1');
    await user.upload(container.querySelector('input[type="file"]') as HTMLInputElement, xlsx());
    const dialog = await screen.findByRole('dialog');
    expect(within(dialog).getByRole('button', { name: /Onayla ve yükle/ })).toBeDisabled();
    await user.click(within(dialog).getByRole('button', { name: /İptal|Vazgeç/ }));
    await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument());
  });

  it('program listesi yirmişerli sayfalanır; sonraki sayfa ve birim süzgeci çalışır', async () => {
    setup([], 45);
    const user = userEvent.setup();
    renderWithProviders(<AcademicTimetablePage />);
    await screen.findByText('Program 0');
    expect(screen.getAllByRole('listitem').filter((li) => li.textContent?.includes('Program ')).length).toBe(20);
    expect(screen.queryByText('Program 20')).not.toBeInTheDocument();
    expect(screen.getByText(/Sayfa 1 \/ 3/)).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: /Sonraki/i }));
    expect(await screen.findByText('Program 20')).toBeInTheDocument();
    expect(screen.queryByText('Program 0')).not.toBeInTheDocument();
    expect(screen.getByText(/Sayfa 2 \/ 3/)).toBeInTheDocument();

    // birim süzgeci: ilk sayfaya döner, yalnız o birimin programları kalır (45 program, 12 birim)
    await user.selectOptions(screen.getByLabelText('Birim'), 'Birim 3');
    await waitFor(() => expect(screen.getByText(/Sayfa 1 \/ 1/)).toBeInTheDocument());
    expect(screen.queryByText('Program 20')).not.toBeInTheDocument();
    expect(screen.getByText('Program 3')).toBeInTheDocument();
  });

  it('önizleme penceresinde programlar onar onar sayfalanır', async () => {
    setup();
    const user = userEvent.setup();
    const { container } = renderWithProviders(<AcademicTimetablePage />);
    await screen.findByText('Program 1');
    await user.upload(container.querySelector('input[type="file"]') as HTMLInputElement, xlsx());
    const dialog = await screen.findByRole('dialog');
    expect(within(dialog).getByText('Program 9')).toBeInTheDocument();
    expect(within(dialog).queryByText('Program 10')).not.toBeInTheDocument();
    expect(within(dialog).getByText(/Sayfa 1 \/ 12/)).toBeInTheDocument();
    await user.click(within(dialog).getByRole('button', { name: /Sonraki/i }));
    expect(await within(dialog).findByText('Program 10')).toBeInTheDocument();
  });
});
