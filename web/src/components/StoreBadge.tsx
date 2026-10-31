import { StoreButton } from '../pages/site/components/StoreButton';

interface Props {
  store: 'android' | 'ios';
  /** Mağaza bağlantısı; yoksa "Yakında" olarak pasif görünür (uydurma adres yazmayın). */
  href: string | null | undefined;
}

/** Alt bilgi için `StoreButton` ön ayarı (kompakt, açıklama metni yalnız ekran okuyucuya). Tek mağaza düğmesi `StoreButton`'dır. */
export function StoreBadge({ store, href }: Props) {
  return <StoreButton store={store} href={href} note={false} />;
}
