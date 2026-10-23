import { useI18n } from '../i18n/I18nProvider';
import { useTheme } from '../lib/theme';
import { IconButton } from './ui/Button';
import { Icon } from './ui/Icon';

export function ThemeToggle() {
  const { t } = useI18n();
  const { resolved, toggle } = useTheme();
  const dark = resolved === 'dark';
  return (
    <IconButton
      label={dark ? t('common.theme.light') : t('common.theme.dark')}
      aria-pressed={dark}
      onClick={toggle}
    >
      <Icon name={dark ? 'sun' : 'moon'} />
    </IconButton>
  );
}
