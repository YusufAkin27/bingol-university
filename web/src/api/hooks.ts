import { useQuery } from '@tanstack/react-query';
import { checkVersion, getAppInfo } from './appInfo';
import { qk } from './queryKeys';
import { useI18n } from '../i18n/I18nProvider';

/** `GET /app/info` — dile göre değişen alanlar (banner, bakım mesajı) için dil anahtara dahildir. */
export function useAppInfo() {
  const { lang } = useI18n();
  return useQuery({ queryKey: [...qk.appInfo, lang], queryFn: getAppInfo, staleTime: 5 * 60_000 });
}

/** Mağaza bağlantıları: `info.stores` varsa onu, yoksa `GET /app/version` içindeki `storeUrl`'ü kullanır. */
export function useStoreLinks() {
  const info = useAppInfo();
  const fromInfo = info.data?.stores;
  const enabled = info.isSuccess && !fromInfo;
  const android = useQuery({
    queryKey: qk.storeLink('ANDROID'),
    queryFn: () => checkVersion('ANDROID'),
    enabled,
    staleTime: 10 * 60_000,
    retry: false,
  });
  const ios = useQuery({
    queryKey: qk.storeLink('IOS'),
    queryFn: () => checkVersion('IOS'),
    enabled,
    staleTime: 10 * 60_000,
    retry: false,
  });
  return {
    android: fromInfo?.android ?? android.data?.storeUrl ?? null,
    ios: fromInfo?.ios ?? ios.data?.storeUrl ?? null,
    isLoading: info.isLoading || android.isLoading || ios.isLoading,
  };
}
