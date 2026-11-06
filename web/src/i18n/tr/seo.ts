// Arama motoru / sosyal önizleme meta metinleri ve JavaScript'siz (noscript) yedek metin.
// Kaynak: seo/routeMeta.ts; derleme zamanında önrender betiği de bu sözlüğü okur.
const seo = {
  'seo.legal.TERMS.desc':
    'BÜ Kampüs uygulamasının ve web sitesinin kullanım koşulları: hesap, kullanıcı yükümlülükleri ve hizmetin kapsamı.',
  'seo.legal.PRIVACY.desc':
    'BÜ Kampüs gizlilik politikası: hangi kişisel verilerin hangi amaçla işlendiği, saklama süreleri ve haklarınız.',
  'seo.legal.KVKK.desc':
    'BÜ Kampüs KVKK aydınlatma metni: veri sorumlusu, kişisel verilerin işlenme amaçları ve ilgili kişinin hakları.',
  'seo.legal.COMMUNITY_RULES.title': 'Topluluk kuralları sözleşmesi',
  'seo.legal.COMMUNITY_RULES.desc':
    'BÜ Kampüs topluluk kuralları sözleşme metni: paylaşımlarda uyulacak kurallar ve ihlal halinde uygulanacak yaptırımlar.',
  'seo.legal.EXPLICIT_CONSENT.desc':
    'BÜ Kampüs uygulamasında kişisel verilerin işlenmesine ilişkin açık rıza metni.',
  'seo.legal.CONTENT_REMOVAL.desc':
    'BÜ Kampüs’te uygunsuz içeriğin nasıl bildirileceği, kaldırma taleplerinin nasıl değerlendirildiği ve itiraz yolları.',
  'seo.legal.RETENTION.desc':
    'BÜ Kampüs veri saklama ve imha politikası: veri türlerine göre saklama süreleri ve verilerin nasıl imha edildiği.',
  'seo.legal.note':
    'Belgenin tam metni uygulama sunucusundan yüklenir. Metni görmek için tarayıcınızda JavaScript’i etkinleştirin ya da iletişim sayfasından bize yazın.',
  'seo.privacy.h': 'Kısaca gizlilik',
  'seo.privacy.l1':
    'Uygulamaya geçerli bir e-posta adresiyle kayıt olunur; e-posta doğrulaması zorunludur.',
  'seo.privacy.l2':
    'İşlenen veriler: profil bilgileri, bildirim tercihleri ve cihaz bildirim anahtarı, uygulama kullanım olayları, cihaz özeti ve IP kayıtları, mesajlar ve topluluk gönderileri.',
  'seo.privacy.l3': 'Mesaj içerikleri sunucuda şifrelenerek saklanır.',
  'seo.privacy.l4':
    'Hesabınızı uygulamadan silebilirsiniz; hesap anonimleştirilir ve kullanım kayıtları silinir. Ayrıntılar hesap silme sayfasındadır.',
  'seo.privacy.l5': 'KVKK kapsamındaki haklarınız için veri talebi sayfasından bize başvurabilirsiniz.',
  'seo.noscript.js': 'Bu sayfanın etkileşimli sürümü için tarayıcınızda JavaScript’i etkinleştirin.',
  'seo.noscript.langs': 'Diğer diller',
  'seo.noscript.related': 'İlgili sayfalar',
  'seo.og.imageAlt': 'BÜ Kampüs: Bingöl Üniversitesi kampüs uygulaması',

  // Arama sonucu başlığı (<title>, og:title; markasız, "| BÜ Kampüs" eki kodda eklenir) ve açıklaması (120-158 karakter).
  // Sayfa içi h1 ve breadcrumb adı bunlardan bağımsızdır (routeMeta.titleKey). Tek kaynak: seo/routeMeta.ts.
  'seo.t.home': 'Bingöl Üniversitesi Kampüs Uygulaması',
  'seo.d.home':
    'BÜ Kampüs, Bingöl Üniversitesi öğrencileri için bağımsız (resmî olmayan) uygulama: duyurular, haberler, yemek listesi ve kulüp etkinlikleri tek yerde.',
  'seo.t.features': 'Özellikler: Yemek Listesi, Duyuru, Sohbet',
  'seo.d.features':
    'Haber ve duyurular, günlük yemek listesi, mesajlaşma, kulüpler, QR yoklamalı etkinlikler ve bildirimler: BÜ Kampüs uygulamasının özellikleri.',
  'seo.t.about': 'Hakkımızda: Bingöl Üniversitesi Uygulaması',
  'seo.d.about':
    'BÜ Kampüs’ün amacı ve işleyişi. Bingöl Üniversitesi öğrencileri için bağımsız, resmî olmayan bir uygulamadır; kayıt bingol.edu.tr e-postasıyla yapılır.',
  'seo.t.download': 'Uygulamayı İndir: Android ve iOS',
  'seo.d.download':
    'BÜ Kampüs’ü Android ve iPhone için indirin: Bingöl Üniversitesi öğrencileri için bağımsız, resmî olmayan uygulama; duyuru, yemek listesi, etkinlik. Ücretsiz.',
  'seo.t.news': 'Bingöl Üniversitesi Haber ve Duyuruları',
  'seo.d.news':
    'Bingöl Üniversitesi’nin haber, duyuru ve etkinliklerini bağımsız BÜ Kampüs uygulamasında okuyun; her haberde resmî kaynak sayfa bağlantısı yer alır.',
  'seo.t.menu': 'Bingöl Üniversitesi Yemek Listesi: Bugün, Bu Ay',
  'seo.d.menu':
    'Bingöl Üniversitesi yemekhanesinin bugünkü ve aylık yemek listesi. Bağımsız BÜ Kampüs uygulaması; resmî kaynak SKS’dir, değişiklikte resmî liste esastır.',
  'seo.t.help': 'Yardım Merkezi: Hesap, Gizlilik, Destek',
  'seo.d.help':
    'BÜ Kampüs yardım merkezi: hesap açma, giriş, gizlilik, topluluk kuralları ve destek konularında sık sorulan soruların yanıtları ve yönlendirmeler.',
  'seo.t.faq': 'Sıkça Sorulan Sorular (SSS)',
  'seo.d.faq':
    'BÜ Kampüs hakkında sıkça sorulan sorular ve yanıtları: kayıt, giriş, gizlilik, bildirimler, etkinlikler ve hesap işlemleri tek sayfada.',
  'seo.t.contact': 'İletişim ve Destek Talebi',
  'seo.d.contact':
    'BÜ Kampüs ekibine ulaşın: destek talebi oluşturun veya iletişim bilgilerimizden bize yazın. Hesabınız olmadan da başvuru yapabilirsiniz.',
  'seo.t.brand': 'Marka Kiti: Logo, Renk ve Tipografi',
  'seo.d.brand':
    'BÜ Kampüs basın kiti: logo varyantları (PNG/SVG), Kampüs Kırmızısı renk paleti, koruma alanı, tipografi ve basın için kullanım kuralları.',
  'seo.t.changelog': 'Sürüm Notları: Yenilikler ve Düzeltmeler',
  'seo.d.changelog':
    'BÜ Kampüs sürüm notları: her sürümde eklenen yeni özellikleri, iyileştirmeleri, hata düzeltmelerini ve güvenlik değişikliklerini buradan izleyin.',
  'seo.t.deleteAccount': 'Hesap Silme: Verileriniz Nasıl Kaldırılır',
  'seo.d.deleteAccount':
    'BÜ Kampüs hesabınızı uygulama içinden nasıl silersiniz, hangi veriler silinir veya anonimleştirilir ve ne kadar süre saklanır: adım adım rehber.',
  'seo.t.dataRequest': 'KVKK Kapsamında Veri Talebi Başvurusu',
  'seo.d.dataRequest':
    'KVKK kapsamındaki haklarınız: verilerinizi indirme, düzeltme veya silme talepleri ve başvuru yolları. BÜ Kampüs veri talebi sayfası.',
  'seo.t.privacy': 'Gizlilik Politikası ve Kişisel Veriler',
  'seo.d.privacy':
    'BÜ Kampüs gizlilik politikası: hangi kişisel verilerin hangi amaçla işlendiği, mesajların nasıl korunduğu, saklama süreleri ve KVKK haklarınız.',
  'seo.t.terms': 'Kullanım Koşulları ve Üyelik Şartları',
  'seo.d.terms':
    'BÜ Kampüs uygulaması ve web sitesinin kullanım koşulları: üyelik şartları, kullanıcı yükümlülükleri, yasak davranışlar ve hizmetin kapsamı.',
  'seo.t.legal': 'Yasal Belgeler: Gizlilik, KVKK, Sözleşmeler',
  'seo.d.legal':
    'BÜ Kampüs yasal belgeleri: kullanım koşulları, gizlilik politikası, KVKK aydınlatma metni, açık rıza, topluluk kuralları ve veri saklama politikası.',
  'seo.t.legalKvkk': 'KVKK Aydınlatma Metni',
  'seo.d.legalKvkk':
    'BÜ Kampüs KVKK aydınlatma metni: veri sorumlusu, kişisel verilerin işlenme amaçları, aktarım, saklama süreleri ve ilgili kişinin hakları.',
  'seo.t.legalCommunityRules': 'Topluluk Kuralları Sözleşmesi',
  'seo.d.legalCommunityRules':
    'BÜ Kampüs topluluk kuralları sözleşmesi: paylaşımlarda uyulacak kurallar, yasak içerikler ve ihlal halinde uygulanacak yaptırımlar.',
  'seo.t.legalExplicitConsent': 'Açık Rıza Metni',
  'seo.d.legalExplicitConsent':
    'BÜ Kampüs uygulamasında kişisel verilerin işlenmesine ilişkin açık rıza metni: hangi verilerin hangi amaçla işlendiği ve rızaya ilişkin haklarınız.',
  'seo.t.legalContentRemoval': 'İçerik Bildirimi ve Kaldırma Politikası',
  'seo.d.legalContentRemoval':
    'BÜ Kampüs’te uygunsuz içeriğin nasıl bildirileceği, kaldırma taleplerinin nasıl değerlendirildiği ve karara itiraz yolları hakkında bilgi.',
  'seo.t.legalRetention': 'Veri Saklama ve İmha Politikası',
  'seo.d.legalRetention':
    'BÜ Kampüs veri saklama ve imha politikası: veri türlerine göre saklama süreleri ve süre sonunda verilerin nasıl silindiği veya anonimleştirildiği.',
  'seo.t.cookies': 'Çerez Politikası',
  'seo.d.cookies':
    'BÜ Kampüs web sitesinin çerez ve tarayıcı depolama kullanımı: yalnızca site için zorunlu kayıtlar saklanır; ayrıntılar ve tercihlerinizi yönetme yolu.',
  'seo.t.guidelines': 'Topluluk Kuralları ve Moderasyon',
  'seo.d.guidelines':
    'BÜ Kampüs topluluk kuralları: paylaşımlarda beklentiler, içerik bildirme, moderasyon kararları ve karara itiraz süreci. Saygılı bir kampüs için.',
  'seo.t.childSafety': 'Çocuk Güvenliği Standartları (CSAE)',
  'seo.d.childSafety':
    'BÜ Kampüs çocuk güvenliği standartları: çocuğun cinsel istismarı ve sömürüsüne (CSAE, CSAM) karşı önleme, bildirim ve müdahale süreçleri.',
  'seo.t.accessibility': 'Erişilebilirlik Beyanı',
  'seo.d.accessibility':
    'BÜ Kampüs web sitesinin erişilebilirlik hedefleri, yapılan iyileştirmeler, bilinen sınırlamalar ve erişilebilirlik sorunlarını bildirme yolları.',
  'seo.t.security': 'Güvenlik Yaklaşımı ve Açık Bildirimi',
  'seo.d.security':
    'BÜ Kampüs’ün güvenlik yaklaşımı ve sorumlu güvenlik açığı bildirimi yönergesi: bir açık bulursanız bize nasıl ve hangi kanaldan ulaşabilirsiniz.',
  'seo.t.sitemap': 'Site Haritası: Tüm Sayfalar',
  'seo.d.sitemap':
    'BÜ Kampüs web sitesindeki tüm sayfaların listesi: özellikler, haberler, yemek listesi, yardım, iletişim ve yasal belgeler tek yerde.',
} as const;

export default seo;
