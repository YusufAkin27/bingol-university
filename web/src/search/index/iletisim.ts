import { paths } from '../../paths';
import type { SearchEntry } from '../types';

/**
 * Arama girdileri: Bildirimler grubunun görsel özet bölümleri (kampanyalar, e-posta, kuyruk sağlığı, engel listesi,
 * şablonlar, bildirim altyapısı). `notifications.ts` bunu birleştirir. Menü sayfalarının kendisi otomatik üretilir.
 */
export const entries: SearchEntry[] = [
  // ---- Kampanyalar (bildirim) ----
  {
    id: 'campaigns.summary',
    kind: 'section',
    page: 'campaigns',
    title: 'Bildirim kampanyaları özeti',
    anchor: 'campaigns-summary',
    keywords: [
      'kaç kişiye ulaştık',
      'ulaşılan kişi',
      'gönderim durumu',
      'sırada bekleyen bildirim',
      'bildirim başarısı',
      'kampanya sonucu',
    ],
    description: 'Son kampanyaların kaç kişiye ulaştığını ve şu an sırada olanları tek bakışta gösterir.',
  },
  {
    id: 'campaigns.status-dist',
    kind: 'section',
    page: 'campaigns',
    title: 'Kampanyaların durumu',
    anchor: 'campaigns-status-dist',
    keywords: ['zamanlanmış bildirim', 'başarısız kampanya', 'gönderiliyor', 'iptal edilen', 'durum grafiği'],
    description:
      'Kampanyaları gönderildi, sırada, hatalı gibi gruplar halinde gösterir; dokununca listeyi süzer.',
  },
  {
    id: 'campaigns.audience-chart',
    kind: 'section',
    page: 'campaigns',
    title: 'Hedef kitle ve ulaşılan kişi',
    anchor: 'campaigns-audience-chart',
    keywords: [
      'kitle büyüklüğü',
      'kaç kişi aldı',
      'bildirimi kapatanlar',
      'ulaşma oranı',
      'hedef kitle grafiği',
    ],
    description:
      'Her kampanyada kitlenin büyüklüğünü ve gerçekten bildirim alan kişi sayısını karşılaştırır.',
  },
  {
    id: 'campaigns.compose-audience-share',
    kind: 'section',
    page: 'campaigns',
    path: paths.admin.campaignNew,
    title: 'Kitle, tüm kullanıcıların kaçı?',
    anchor: 'compose-audience-share',
    keywords: ['kaç kişiye gidecek', 'hedef kitle oranı', 'kitle büyüklüğü', 'herkese mi gidiyor'],
    description:
      'Seçtiğiniz kitlenin tüm kullanıcılara oranını gösterir; yanlışlıkla herkese göndermeyin diye.',
    perm: 'comms.write',
  },
  {
    id: 'campaigns.compose-preview',
    kind: 'section',
    page: 'campaigns',
    path: paths.admin.campaignNew,
    title: 'Alıcı önizleme: kaç kişi alacak, kaç kişi atlanacak',
    anchor: 'compose-preview-split',
    keywords: [
      'bildirim alacak',
      'tercihi nedeniyle atlanacak',
      'alıcıları önizle',
      'kimler alacak',
      'gönderim öncesi kontrol',
    ],
    description:
      'Göndermeden önce bildirimi alacak ve bildirimleri kapattığı için atlanacak kişileri ayırır.',
    perm: 'comms.write',
  },

  // ---- E-posta kampanyaları ----
  {
    id: 'mailCampaigns.summary',
    kind: 'section',
    page: 'mailCampaigns',
    title: 'E-posta kampanyaları özeti',
    anchor: 'mc-summary',
    keywords: ['toplu mail durumu', 'kaç mail gitti', 'mail başarısı', 'bülten sonucu', 'gönderim özeti'],
    description:
      'Son e-posta kampanyalarının durumunu ve alıcıların kaçının gönderim sırasına alındığını gösterir.',
  },
  {
    id: 'mailCampaigns.status-dist',
    kind: 'section',
    page: 'mailCampaigns',
    title: 'Kampanyaların durumu (e-posta)',
    anchor: 'mc-status-dist',
    keywords: ['taslak kampanya', 'duraklatılan mail', 'başarısız mail kampanyası', 'zamanlanan mail'],
    description:
      'E-posta kampanyalarını taslak, gönderiliyor, bitti gibi gruplara ayırır; dokununca listeyi süzer.',
  },
  {
    id: 'mailCampaigns.ring',
    kind: 'section',
    page: 'mailCampaigns',
    title: 'Alıcı gönderim sırasına alındı oranı',
    anchor: 'mc-queued-ring',
    keywords: ['teslim oranı', 'mail ulaştı mı', 'gönderilen alıcı yüzdesi', 'açılma oranı'],
    description: 'Hedeflenen alıcıların yüzde kaçı gönderim sırasına alındı. Açılma ve tıklama izlenmez.',
  },

  // ---- Mail kuyruğu ----
  {
    id: 'mailQueue.health',
    kind: 'section',
    page: 'mailQueue',
    title: 'Mail kuyruğu sağlığı',
    anchor: 'queue-health',
    keywords: [
      'gitmeyen mailler',
      'ölü kayıt',
      'bekleyen mail sayısı',
      'başarısız mail',
      'kuyruk temiz mi',
      'mail takıldı',
    ],
    description:
      'Bekleyen, başarısız ve ölü e-postaları tek şeritte gösterir; dokununca listeyi o duruma süzer.',
  },

  // ---- Mail engel listesi ----
  {
    id: 'mailSuppressions.summary',
    kind: 'section',
    page: 'mailSuppressions',
    title: 'E-posta engel listesi özeti',
    anchor: 'supp-summary',
    keywords: [
      'kaç adres engelli',
      'abonelikten çıkanlar',
      'spam diyenler',
      'geri dönen adresler',
      'şikayet eden',
      'engel nedenleri',
    ],
    description: 'Engelli adreslerin neden engellendiğini (abonelikten çıkış, geri dönme, şikâyet) gösterir.',
  },

  // ---- Mail şablonları ----
  {
    id: 'mailTemplates.summary',
    kind: 'section',
    page: 'mailTemplates',
    title: 'E-posta şablonları özeti',
    anchor: 'tpl-summary',
    keywords: [
      'eksik dil',
      'çevirisi olmayan şablon',
      'yayındaki şablonlar',
      'taslak şablon',
      'ingilizce arapça eksik',
    ],
    description: 'Şablonların durumunu ve yayındaki şablonlarda eksik dil olup olmadığını gösterir.',
  },

  // ---- Bildirim altyapısı (push) ----
  {
    id: 'pushOps.queue-health',
    kind: 'section',
    page: 'pushOps',
    title: 'Bildirim kuyruğunun sağlığı',
    anchor: 'push-queue-health',
    keywords: [
      'bildirim gitmiyor',
      'bekleyen bildirim',
      'ölü bildirim',
      'başarısız push',
      'kuyruk durumu',
      'son 24 saatte gönderilen',
    ],
    description:
      'Bekleyen, gönderilen, başarısız ve ölü bildirimleri tek şeritte gösterir; dokununca listeyi süzer.',
  },
  {
    id: 'pushOps.stats-tiles',
    kind: 'section',
    page: 'pushOps',
    title: 'Bildirimler okunuyor mu?',
    anchor: 'push-stats-tiles',
    keywords: [
      'okunma oranı',
      'kaç bildirim okundu',
      'bildirim ilgisi',
      'bildirim istatistiği',
      'okunmamış bildirim',
    ],
    description: 'Gönderilen bildirimlerin yüzde kaçının açılıp okunduğunu gösterir.',
  },
  {
    id: 'pushOps.devices-tiles',
    kind: 'section',
    page: 'pushOps',
    title: 'Kayıtlı cihazlar ve aktif oranı',
    anchor: 'push-devices-tiles',
    keywords: ['kaç telefon kayıtlı', 'aktif cihaz', 'eski cihazlar', 'cihaz sayısı', 'uygulamayı silenler'],
    description: 'Bildirim alabilen cihazların kaçının son günlerde kullanıldığını gösterir.',
  },
];
