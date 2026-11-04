import { fireEvent, screen } from '@testing-library/react';
import { afterEach, describe, expect, it } from 'vitest';
import { hasAcknowledgedCookies, isPrefStorageAllowed, resetCookieChoice, setPrefStorageAllowed } from '../lib/cookieConsent';
import { readStorage } from '../lib/storage';
import { renderWithProviders } from '../test/utils';
import { CookieBanner } from './CookieBanner';

afterEach(() => {
  setPrefStorageAllowed(true);
  resetCookieChoice();
});

describe('çerez bandı ve tercih penceresi', () => {
  it('Tercihler penceresi açılır; dil/tema hatırlamayı kapatıp kaydedince bilgilendirme onaylanır ve kayıtlar silinir', async () => {
    renderWithProviders(<CookieBanner />);
    fireEvent.click(screen.getByRole('button', { name: 'Tercihler' }));
    const dialog = await screen.findByRole('dialog', { name: 'Depolama tercihleri' });
    expect(dialog).toBeInTheDocument();
    const sw = screen.getByRole('switch', { name: 'Dil ve tema tercihi' });
    expect(sw).toBeChecked();
    fireEvent.click(sw);
    fireEvent.click(screen.getByRole('button', { name: 'Kaydet' }));
    expect(isPrefStorageAllowed()).toBe(false);
    expect(hasAcknowledgedCookies()).toBe(true);
    expect(readStorage('local', 'bu.theme')).toBeNull();
    expect(screen.queryByRole('dialog')).toBeNull();
  });

  it('"Anladım" bandı kapatır; tercih saklama açık kalır', () => {
    renderWithProviders(<CookieBanner />);
    fireEvent.click(screen.getByRole('button', { name: 'Anladım' }));
    expect(hasAcknowledgedCookies()).toBe(true);
    expect(isPrefStorageAllowed()).toBe(true);
  });
});
