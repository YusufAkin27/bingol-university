import { screen } from '@testing-library/react';
import { useState } from 'react';
import userEvent from '@testing-library/user-event';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { renderWithProviders } from '../test/utils';
import { adminNav } from './adminNav';
import { MAX_FAV, MAX_RECENT, readFavoritePages, readRecentPages, recordPageVisit, resetPageMemory, toggleFavoritePage } from './pageMemory';
import { PAGE_LOADERS, prefetchPage } from './prefetch';
import { RouteBoundary } from './RouteBoundary';
import { GO_SHORTCUTS, isTypingTarget } from './shortcuts';

beforeEach(() => {
  window.localStorage.clear();
  resetPageMemory();
});

describe('son ziyaret ve sık kullanılan sayfalar (pageMemory)', () => {
  it('ziyareti başa alır, tekrarı kaldırır, sınırı uygular ve depoya yazar', () => {
    recordPageVisit('users');
    recordPageVisit('settings');
    recordPageVisit('users');
    recordPageVisit('users'); // üst üste aynı sayfa: değişmez
    expect(readRecentPages()).toEqual(['users', 'settings']);
    for (let i = 0; i < 20; i++) recordPageVisit(`p${i}`);
    expect(readRecentPages()).toHaveLength(MAX_RECENT);
    expect(JSON.parse(window.localStorage.getItem('bu.admin.pages.recent') ?? '[]')).toHaveLength(MAX_RECENT);
  });
  it('yıldız aç/kapat; sınır aşılınca en eski düşer', () => {
    expect(toggleFavoritePage('users')).toBe(true);
    expect(toggleFavoritePage('users')).toBe(false);
    expect(readFavoritePages()).toEqual([]);
    for (let i = 0; i < MAX_FAV + 3; i++) toggleFavoritePage(`p${i}`);
    expect(readFavoritePages()).toHaveLength(MAX_FAV);
    expect(readFavoritePages()[0]).toBe(`p${MAX_FAV + 2}`);
  });
  it('bozuk depo içeriğinde çökmez', () => {
    window.localStorage.setItem('bu.admin.pages.fav', '{bozuk');
    window.localStorage.setItem('bu.admin.pages.recent', '[1,"a",null]');
    resetPageMemory(false);
    expect(readFavoritePages()).toEqual([]);
    expect(readRecentPages()).toEqual(['a']);
  });
  it('localStorage yazma hatası verse bile bellekte çalışır', () => {
    const spy = vi.spyOn(Storage.prototype, 'setItem').mockImplementation(() => {
      throw new Error('kota');
    });
    expect(toggleFavoritePage('users')).toBe(true);
    expect(readFavoritePages()).toEqual(['users']);
    spy.mockRestore();
  });
});

describe('rota önyükleme (prefetch)', () => {
  const navIds = adminNav.flatMap((g) => g.items.map((i) => i.id));
  it('her menü sayfasının yükleyicisi var, fazlası yok', () => {
    expect(Object.keys(PAGE_LOADERS).sort()).toEqual([...navIds].sort());
  });
  it('bilinmeyen kimlik sessizce yok sayılır', () => {
    expect(() => prefetchPage('yok-boyle-sayfa')).not.toThrow();
  });
});

describe('klavye kısayolu tablosu', () => {
  it('g kısayolları benzersiz tek harf ve hepsi var olan menü sayfasına gider', () => {
    const navIds = new Set(adminNav.flatMap((g) => g.items.map((i) => i.id)));
    const keys = GO_SHORTCUTS.map((s) => s.key);
    expect(new Set(keys).size).toBe(keys.length);
    for (const s of GO_SHORTCUTS) {
      expect(s.key).toMatch(/^[a-z]$/);
      expect(navIds.has(s.page), s.page).toBe(true);
    }
  });
  it('yazı alanları tanınır; düğme/onay kutusu tanınmaz', () => {
    const input = document.createElement('input');
    const area = document.createElement('textarea');
    const cb = document.createElement('input');
    cb.type = 'checkbox';
    const btn = document.createElement('button');
    const div = document.createElement('div');
    expect(isTypingTarget(input)).toBe(true);
    expect(isTypingTarget(area)).toBe(true);
    expect(isTypingTarget(cb)).toBe(false);
    expect(isTypingTarget(btn)).toBe(false);
    expect(isTypingTarget(div)).toBe(false);
    expect(isTypingTarget(null)).toBe(false);
  });
});

function Bomb({ boom }: { boom: boolean }) {
  if (boom) throw new Error('kaboom');
  return <p>sağlam sayfa</p>;
}

describe('RouteBoundary (sayfa hata sınırı)', () => {
  it('render hatasında içerik alanında "Tekrar dene" gösterir, düzeltilince geri gelir', async () => {
    const err = vi.spyOn(console, 'error').mockImplementation(() => {});
    let boom = true;
    const Inner = () => <Bomb boom={boom} />;
    const user = userEvent.setup();
    renderWithProviders(
      <RouteBoundary resetKey="/a">
        <Inner />
      </RouteBoundary>,
      { route: '/admin' },
    );
    expect(await screen.findByRole('alert')).toHaveTextContent('Bu sayfa açılamadı');
    boom = false;
    await user.click(screen.getByRole('button', { name: 'Tekrar dene' }));
    expect(await screen.findByText('sağlam sayfa')).toBeInTheDocument();
    err.mockRestore();
  });

  it('rota değişince (resetKey) hata temizlenir', async () => {
    const err = vi.spyOn(console, 'error').mockImplementation(() => {});
    const user = userEvent.setup();
    function Harness() {
      const [key, setKey] = useState('/a');
      return (
        <>
          <button onClick={() => setKey('/b')}>başka sayfa</button>
          <RouteBoundary resetKey={key}>
            <Bomb boom={key === '/a'} />
          </RouteBoundary>
        </>
      );
    }
    renderWithProviders(<Harness />, { route: '/admin' });
    expect(await screen.findByRole('alert')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'başka sayfa' }));
    expect(await screen.findByText('sağlam sayfa')).toBeInTheDocument();
    err.mockRestore();
  });
});
