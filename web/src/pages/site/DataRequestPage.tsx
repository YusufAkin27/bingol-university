// SAYFA: KVKK kişisel veri talebi (/data-request)
// API: GET /api/legal/KVKK (bilgilendirme metni), GET /api/app/info (supportEmail — talep e-posta ile iletilir).
//      Giriş yapmış kullanıcılar için veri dışa aktarma mobil uygulamadadır (GET /api/users/me/export).
import { PlaceholderPage } from '../../components/PlaceholderPage';

export default function DataRequestPage() {
  return <PlaceholderPage layout="site" titleKey="site.dataRequest.title" />;
}
