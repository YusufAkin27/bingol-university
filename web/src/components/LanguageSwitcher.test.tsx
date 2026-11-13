import { screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import { renderWithProviders } from '../test/utils';
import { LanguageSwitcher } from './LanguageSwitcher';

describe('LanguageSwitcher', () => {
  it('doğal adlı seçenekleri gösterir, seçiliyi işaretler, seçince kapanır', async () => {
    const user = userEvent.setup();
    renderWithProviders(<LanguageSwitcher />, { route: '/tr', lang: 'tr' });
    const btn = screen.getByRole('button', { name: /Türkçe/ });
    expect(btn).toHaveAttribute('aria-expanded', 'false');
    await user.click(btn);
    const opts = screen.getAllByRole('option');
    expect(opts.map((o) => o.textContent)).toEqual(['Türkçe', 'English', 'العربية']);
    expect(opts[0]).toHaveAttribute('aria-selected', 'true');
    expect(opts[0]).toHaveFocus();
    await user.keyboard('{ArrowDown}{Enter}');
    expect(screen.queryByRole('listbox')).toBeNull();
    expect(btn).toHaveFocus();
  });

  it('Esc listeyi kapatır ve odağı düğmeye verir', async () => {
    const user = userEvent.setup();
    renderWithProviders(<LanguageSwitcher compact />, { route: '/tr', lang: 'tr' });
    const btn = screen.getByRole('button');
    await user.click(btn);
    expect(screen.getByRole('listbox')).toBeInTheDocument();
    await user.keyboard('{Escape}');
    expect(screen.queryByRole('listbox')).toBeNull();
    expect(btn).toHaveFocus();
  });
});
