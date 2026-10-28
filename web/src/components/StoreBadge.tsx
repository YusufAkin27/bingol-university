import { StoreButton } from '../pages/site/components/StoreButton';

interface Props {
  store: 'android' | 'ios';
  /** Mağaza bağlantısı; yoksa "Yakında" olarak pasif görünür. */
  href: string | null | undefined;
}

/** Alt bilgi (koyu zemin) için `StoreButton` ön ayarı. Tek mağaza düğmesi `StoreButton`'dır; ayrı bir görünüm yoktur. */
export function StoreBadge({ store, href }: Props) {
  return <StoreButton store={store} href={href} onDark note={false} />;
}
