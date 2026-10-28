import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { groupOf, levelOf, toUnit, unitOf } from '../../api/system';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import SystemStatusPage from './SystemStatusPage';

afterEach(() => vi.unstubAllGlobals());

interface Call {
  url: string;
  init: RequestInit;
}

function setup(overall: 'OK' | 'CRIT' = 'CRIT') {
  const calls: Call[] = [];
  mockFetch((url, init) => {
    calls.push({ url, init });
    const method = init.method ?? 'GET';
    if (url.includes('/admin/system/overview'))
      return jsonResponse(200, {
        generatedAt: '2026-10-28T10:00:00Z',
        overall,
        indicators: {
          'mail.dead': {
            status: overall === 'CRIT' ? 'CRIT' : 'OK',
            value: 25,
            threshold: { warn: 1, crit: 20 },
            message: '25 kayıt ölü',
          },
          'mail.oldestPendingAge': { status: 'WARN', value: 900, threshold: { warn: 600, crit: 1800 }, message: null },
          'backup.age': { status: 'UNKNOWN', value: null, threshold: { warn: 3, crit: 6 }, message: 'Yedek yok' },
          'disk.storage': { status: 'OK', value: 41.5, threshold: { warn: 80, crit: 90 }, message: null },
          'jobs.mail-queue': { status: 'OK', value: 12, threshold: { warn: 120, crit: 360 }, message: null },
        },
      });
    if (url.includes('/admin/system/dead-letters/mail/retry') && method === 'POST')
      return jsonResponse(200, { requeued: 1 });
    if (url.includes('/admin/system/dead-letters/mail/delete') && method === 'POST')
      return jsonResponse(200, { deleted: 1 });
    if (url.includes('/admin/system/dead-letters/mail'))
      return jsonResponse(200, [
        { id: 7, template: 'VERIFY', to: 'a***@bingol.edu.tr', attempts: 8, lastError: 'SMTP 550', createdAt: '2026-10-27T10:00:00Z' },
        { id: 8, template: 'RESET', to: 'b***@bingol.edu.tr', attempts: 8, lastError: null, createdAt: null },
      ]);
    if (url.includes('/admin/system/dead-letters/push')) return jsonResponse(200, []);
    return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
  });
  return calls;
}

describe('Sistem durumu sayfası', () => {
  it('göstergeleri simge + metinle gösterir, kritik uyarısı çıkarır', async () => {
    setup('CRIT');
    renderWithProviders(<SystemStatusPage />);
    const card = await screen.findByTestId('ind-mail.dead');
    expect(within(card).getByText('Kritik')).toBeInTheDocument();
    expect(within(card).getByText('25')).toBeInTheDocument();
    expect(within(card).getByText('Uyarı: 1 · Kritik: 20')).toBeInTheDocument();
    expect(screen.getByTestId('ind-mail.oldestPendingAge')).toHaveTextContent('15 dk');
    expect(screen.getByTestId('ind-mail.oldestPendingAge')).toHaveTextContent('Uyarı');
    expect(screen.getByTestId('ind-backup.age')).toHaveTextContent('Bilinmiyor');
    expect(screen.getByTestId('ind-disk.storage')).toHaveTextContent('%41,5');
    expect(screen.getByTestId('ind-jobs.mail-queue')).toHaveTextContent('0 dk önce');
    expect(screen.getByRole('alert')).toHaveTextContent('1 gösterge');
  });

  it('her şey normalse kritik uyarısı göstermez', async () => {
    setup('OK');
    renderWithProviders(<SystemStatusPage />);
    await screen.findByTestId('ind-mail.dead');
    expect(screen.queryByRole('alert')).not.toBeInTheDocument();
  });

  it('ölü mail kayıtlarını listeler ve seçilenleri yeniden dener', async () => {
    const calls = setup();
    renderWithProviders(<SystemStatusPage />);
    expect(await screen.findByText('VERIFY')).toBeInTheDocument();
    await userEvent.click(screen.getByLabelText('Kaydı seç: 7'));
    await userEvent.click(screen.getByRole('button', { name: 'Seçilenleri yeniden dene' }));
    await waitFor(() =>
      expect(
        calls.some(
          (c) =>
            c.url.endsWith('/admin/system/dead-letters/mail/retry') &&
            c.init.method === 'POST' &&
            String(c.init.body).includes('[7]'),
        ),
      ).toBe(true),
    );
  });

  it('silmeden önce onay ister', async () => {
    const calls = setup();
    renderWithProviders(<SystemStatusPage />);
    await userEvent.click(await screen.findByLabelText('Kaydı seç: 8'));
    await userEvent.click(screen.getByRole('button', { name: 'Seçilenleri sil' }));
    expect(calls.some((c) => c.url.endsWith('/mail/delete'))).toBe(false);
    const dialog = await screen.findByRole('dialog');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Seçilenleri sil' }));
    await waitFor(() => expect(calls.some((c) => c.url.endsWith('/mail/delete'))).toBe(true));
  });
});

describe('system yardımcıları', () => {
  it('durum, grup ve birim eşlemesi', () => {
    expect(levelOf('CRIT')).toBe('CRIT');
    expect(levelOf('garip')).toBe('UNKNOWN');
    expect(groupOf('jobs.news-sync')).toBe('jobs');
    expect(groupOf('mail.dead')).toBe('queues');
    expect(groupOf('db')).toBe('infra');
    expect(unitOf('push.oldestPendingAge')).toBe('minutes');
    expect(unitOf('backup.age')).toBe('hours');
    expect(toUnit('minutes', 900)).toBe(15);
    expect(toUnit('hours', 3)).toBe(3);
  });
});
