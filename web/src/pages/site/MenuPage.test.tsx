import { fireEvent, screen } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { AuthProvider } from '../../auth/AuthProvider';
import { isoDate } from '../../lib/date';
import { AppRoutes } from '../../routes';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import { safeMenuImageUrl } from './components/newsUtils';

afterEach(() => vi.unstubAllGlobals());

function renderMenu(imageUrl: string | null | undefined, lang: 'tr' | 'en' | 'ar' = 'tr') {
  mockFetch((url) => {
    if (url.includes('/status')) return jsonResponse(200, {});
    if (url.includes('/menu')) {
      const day: Record<string, unknown> = { date: isoDate(new Date()), items: ['Mercimek çorbası', 'Pilav'] };
      if (imageUrl !== undefined) day.imageUrl = imageUrl;
      return jsonResponse(200, [day]);
    }
    return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
  });
  return renderWithProviders(
    <AuthProvider>
      <AppRoutes />
    </AuthProvider>,
    { route: `/${lang}/menu`, lang },
  );
}

describe('yemek listesi: menü fotoğrafı', () => {
  it('imageUrl varsa günlük kartın üstünde özgün 3:2 oranlı fotoğraf çizer (öncelikli yükleme, anlamlı alt metin)', async () => {
    renderMenu('/files/menu/abc-123.webp');
    await screen.findByText('Mercimek çorbası', {}, { timeout: 10_000 });
    const img = screen.getByRole('img', { name: /yemek listesi fotoğrafı/ });
    expect(img).toHaveAttribute('src', '/files/menu/abc-123.webp');
    // ana içerik: tembel yükleme yok, boyut öznitelikleri (CLS) ve yükleme önceliği var
    expect(img).not.toHaveAttribute('loading', 'lazy');
    expect(img).toHaveAttribute('width', '1536');
    expect(img).toHaveAttribute('height', '1024');
    expect(img).toHaveAttribute('fetchpriority', 'high');
    const card = img.closest('article') as HTMLElement;
    expect(card).toBeTruthy();
    // fotoğraf kartın ilk çocuğudur (başlıktan önce)
    expect(card.firstElementChild?.contains(img)).toBe(true);
  }, 20_000);

  it('alt metin İngilizce ve Arapça dillerinde çevrilir', async () => {
    const { unmount } = renderMenu('/files/menu/a.webp', 'en');
    await screen.findByText('Mercimek çorbası', {}, { timeout: 10_000 });
    expect(screen.getByRole('img', { name: /^Photo of the menu for / })).toBeInTheDocument();
    unmount();
    renderMenu('/files/menu/a.webp', 'ar');
    await screen.findByText('Mercimek çorbası', {}, { timeout: 10_000 });
    expect(screen.getByRole('img', { name: /^صورة قائمة الطعام ليوم / })).toBeInTheDocument();
  }, 20_000);

  it.each([null, undefined])('fotoğraf yoksa (%s) hiçbir görsel çizilmez, menü aynen görünür', async (value) => {
    renderMenu(value);
    expect(await screen.findByText('Mercimek çorbası', {}, { timeout: 10_000 })).toBeInTheDocument();
    expect(screen.getByText('Pilav')).toBeInTheDocument();
    expect(screen.queryByRole('img', { name: /fotoğraf/ })).toBeNull();
    expect(document.querySelector('main article img')).toBeNull();
  }, 20_000);

  it('fotoğraf yüklenemezse hiçbir şey çizilmez (yer tutucu yok)', async () => {
    renderMenu('/files/menu/yok.webp');
    await screen.findByText('Mercimek çorbası', {}, { timeout: 10_000 });
    fireEvent.error(screen.getByRole('img', { name: /yemek listesi fotoğrafı/ }));
    expect(document.querySelector('main article img')).toBeNull();
    expect(screen.getByText('Pilav')).toBeInTheDocument();
  }, 20_000);

  it('güvensiz adresler reddedilir, /files ve bingol.edu.tr kabul edilir', () => {
    expect(safeMenuImageUrl('/files/menu/x.webp')).toBe('/files/menu/x.webp');
    expect(safeMenuImageUrl('https://sks.bingol.edu.tr/a.jpg')).toBe('https://sks.bingol.edu.tr/a.jpg');
    expect(safeMenuImageUrl('//evil.example/x.jpg')).toBeNull();
    expect(safeMenuImageUrl('/files/../etc/passwd')).toBeNull();
    expect(safeMenuImageUrl('https://evil.example/x.jpg')).toBeNull();
    expect(safeMenuImageUrl('javascript:alert(1)')).toBeNull();
    expect(safeMenuImageUrl(null)).toBeNull();
    expect(safeMenuImageUrl('')).toBeNull();
  });
});
