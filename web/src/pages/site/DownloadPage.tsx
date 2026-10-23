// SAYFA: Uygulamayı indir (/download)
// API: GET /api/app/version?platform=ANDROID|IOS&version=0.0.0 → storeUrl (useStoreLinks), GET /api/app/info.
import { PlaceholderPage } from '../../components/PlaceholderPage';

export default function DownloadPage() {
  return <PlaceholderPage layout="site" titleKey="site.download.title" />;
}
