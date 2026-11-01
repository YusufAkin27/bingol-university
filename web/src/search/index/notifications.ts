import { paths } from '../../paths';
import type { SearchEntry } from '../types';
import { notifications } from './notifsysPages';

/**
 * Arama girdileri: Bildirimler grubu (campaigns, mailTemplates, mailCampaigns, mailQueue, mailSuppressions, pushOps).
 * Sayfa ajanı bu dosyaya KENDİ sayfalarının ayar/alan/eylem/bölüm girdilerini ekler (kılavuz: ../README.md).
 * Menü sayfalarının kendisi (`page`) otomatik üretilir; burada tekrar yazmayın.
 */
export const entries: SearchEntry[] = [
  ...notifications,
  // Menüde olmayan alt sayfa: `path` ile açıkça verilir
  {
    id: 'campaigns.new',
    kind: 'page',
    title: 'Yeni kampanya oluştur',
    page: 'campaigns',
    path: paths.admin.campaignNew,
    keywords: ['bildirim yaz', 'push gönder', 'duyuru yaz', 'yeni bildirim', 'toplu bildirim hazırla', 'zamanlı bildirim'],
    description: 'Telefonlara gidecek yeni bir bildirim hazırla; hemen ya da zamanlı gönder.',
    perm: 'comms.write',
  },
];
