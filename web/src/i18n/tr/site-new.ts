// Tanıtım sitesi: yeni özellikler (etkinlik başvurusu, kulüp yetkileri, görsel paylaşımı, gizlilik, şifreleme) ve yönetici erişim bildirimi (T17).
const m = {
  'site.feat.admission.title': 'Etkinlik başvurusu ve kabul',
  'site.feat.admission.text':
    'Etkinliği düzenleyen kişi başvuru isteyebilir; başvurular kabul, ret veya bekleme listesi ile yanıtlanır. Kontenjan dolunca sıradaki kişiye bildirim gider.',
  'site.feat.clubroles.title': 'Kulüp yetkileri',
  'site.feat.clubroles.text':
    'Kulüp sahibi, yönetim ekibine ayrıntılı yetkiler verir; sahiplik devri ve davet kodu ile kulüp yönetimi düzenli kalır. Önemli işlemler kayıt altına alınır.',
  'site.feat.media.title': 'Sohbette görsel paylaşımı',
  'site.feat.media.text':
    'Sohbetlerde görsel gönderin. Uygunsuz görselleri bildirebilir, kullanıcıyı engelleyebilirsiniz; yasaklı görseller yüklenirken otomatik reddedilir.',
  'site.feat.privacysettings.title': 'Gizlilik ayarları',
  'site.feat.privacysettings.text':
    'Profilinizde nelerin kimlere görüneceğini siz seçersiniz. E-posta adresiniz ve diğer bilgileriniz için görünürlüğü istediğiniz zaman değiştirebilirsiniz.',
  'site.feat.secure.title': 'Şifreli iletim ve saklama',
  'site.feat.secure.text':
    'Mesajlarınız iletim sırasında şifrelenir ve sunucuda şifreli olarak saklanır. Yönetici erişimi yalnızca yazılı gerekçeyle yapılır ve her erişim denetim kaydına yazılır.',
  'site.home.privacy4': 'Mesajlar şifreli iletilir ve şifreli saklanır; yönetici erişimi gerekçeli ve denetimlidir.',

  'site.faq.new.title': 'Yeni özellikler hakkında',
  'site.faq.new.apply.q': 'Etkinliğe nasıl başvururum?',
  'site.faq.new.apply.a':
    'Başvuru gerektiren bir etkinliğin sayfasında “Başvur” düğmesine dokunun. Düzenleyen kişi başvurunuzu kabul eder, reddeder veya bekleme listesine alır; sonuç bildirim olarak gelir. Kontenjan doluysa bekleme listesindeki sıranızı görürsünüz.',
  'site.faq.new.clubRoles.q': 'Kulüp yetkileri nasıl çalışır?',
  'site.faq.new.clubRoles.a':
    'Kulüp sahibi, üyelere tek tek yetki verebilir (örneğin üye onaylama veya duyuru yayımlama). Sahiplik, karşı tarafın onayıyla devredilebilir. Yetki değişiklikleri ve üye kararları kulüp denetim kaydında tutulur.',
  'site.faq.new.images.q': 'Sohbette görsel gönderebilir miyim?',
  'site.faq.new.images.a':
    'Evet. Görseller yüklenirken tür ve boyut denetimi yapılır. Uygunsuz bir görseli bildirebilir ve göndereni engelleyebilirsiniz. Bildirilen içerikler moderatörlerce incelenir.',
  'site.faq.new.privacy.q': 'Bilgilerimin kimlere görüneceğini seçebilir miyim?',
  'site.faq.new.privacy.a':
    'Evet. Profil ve gizlilik ayarlarından e-posta adresiniz gibi bilgilerin görünürlüğünü değiştirebilirsiniz. Ayar değişikliği hemen geçerli olur.',
  'site.faq.new.encryption.q': 'Mesajlarım nasıl korunuyor?',
  'site.faq.new.encryption.a':
    'Mesajlar iletim sırasında şifrelenir ve sunucuda şifreli olarak saklanır. Anahtarlar mesaj içeriğinden ayrı yönetilir.',
  'site.faq.new.adminAccess.q': 'Yöneticiler mesajlarımı okuyabilir mi?',
  'site.faq.new.adminAccess.a':
    'Mesajlar yöneticilere varsayılan olarak gösterilmez. Şikâyet, güvenlik olayı veya yasal yükümlülük gibi somut bir durumda erişim yalnızca yazılı gerekçeyle yapılabilir ve her erişim değiştirilemez bir denetim kaydına yazılır.',

  'legal.adminAccess.title': 'Yönetici gerekçeli ve denetimli erişimi',
  'legal.adminAccess.body1':
    'Mesajlar iletim sırasında şifrelenir ve şifreli saklanır. Yöneticiler mesaj içeriğine varsayılan olarak erişemez.',
  'legal.adminAccess.body2':
    'Şikâyet, güvenlik olayı veya yasal yükümlülük gibi somut bir durumda yetkili bir yönetici, yalnızca ilgili konuşma ve mesaj aralığı için, yazılı bir gerekçe vererek erişim talep edebilir. Her erişim, kim tarafından, ne zaman ve hangi gerekçeyle yapıldığıyla birlikte değiştirilemez bir denetim kaydına yazılır.',
  'legal.adminAccess.draft': 'Bu metin taslaktır; yayımlanmadan önce hukuki inceleme gerekir.',
} as const;
export default m;
