# Forum mobil C: konu oluşturma, düzenleme, anket

Kapsam: `mobile/lib/features/forum/` altında `create_topic_page.dart`, `edit_topic_page.dart`, `poll_builder.dart`,
`poll_view.dart`, `compose_widgets.dart`, `compose_image_strip.dart`, `data/forum_compose_rules.dart`,
`data/forum_compose_errors.dart`, `data/forum_draft_store.dart`. Metinler ARB önekleri `forumCompose*` / `forumPoll*`.

## Davranış notları

- Yayınla: başlık (<=150), açıklama (<=10.000), kategori zorunlu; yalnız boşluk/görünmez karakter "boş" sayılır;
  görseller tek tek yüklenir, hepsi yüklenmeden (ya da biri hatalıyken) Yayınla pasiftir.
- Çift gönderim: `_publishing` bayrağı ilk dokunuşta kurulur; her gönderim niyeti bir `Idempotency-Key` taşır.
  Hatadan sonra içerik DEĞİŞMEDEN yeniden denenirse AYNI anahtar gider (ağ kopsa da sunucu çift konu açmaz);
  içerik değişirse yeni anahtar üretilir.
- Taslak: cihazın güvenli deposunda (`FlutterSecureStorage`, yeni paket yok) kullanıcıya özel tek kayıt
  (`forum_draft_v1_<userId>`). Yalnız yüklenmiş görsellerin kimliği + önizleme adresi yazılır. Anket bitişi taslakta
  "gün sayısı" olarak tutulur (yayınlama anında hesaplanır; günler sonra geri yüklense de geçmişe düşmez).
- Anket bitişi: süresiz ya da 1/3/7/30 gün ya da tarih seçici (en çok 30 gün). 30 günde sunucu saat farkı için bitiş
  1 saat kısılır.
- Başarıda `openCreateTopic` çağırana oluşan `TopicSummary`yi döndürür (ekran yığından çıkar) ve ardından
  `openTopicDetail(..., initial: topic)` açılır.
- `PollView` oy: iyimser güncelleme + hatada geri alma; `FORUM_POLL_CLOSED` gelirse anket yerelde kapalı olur.
  `allowChangeVote=false` iken oy verilmişse seçenekler dokunulduğunda yalnız kısa bilgi verir (istek atılmaz).

## Sözleşmeden sapmalar / eksikler

- Görseller için sürükle-sırala YOK (isteğe bağlıydı); galeriden tek tek seçim (çoklu seçim `ImageService`te yok).
- Forum görselleri için kırpma ekranı açılmaz (oran serbest; yalnız boyut/tür doğrulaması ve yeniden kodlama).
- Taslak yalnız yeni konu için vardır (düzenlemede yok).
