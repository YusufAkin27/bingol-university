-- V481: Sozlesme yer tutucularinin yayinci/veri sorumlusu bilgileri (V480 yer tutucularini doldurur).
-- * V480 bos birakilan legal.controller.relation / jurisdiction dahil, kayit varsa ezilir, yoksa eklenir (UPSERT).
-- * legal.controller.kep ve legal.controller.verbis BILEREK bu dosyada YOK (bilinmiyor; bos kalir, ilgili satirlar metinden cikar).
-- * Degerler yonetici panelinden sonradan degistirilebilir; bu dosya yalniz ilk degerleri verir.
-- * Gercek kisi olarak veri sorumlusu: bkz. docs/LEGAL_NOTES.md (adresin herkese acik gorunmesi uyarisi).

INSERT INTO app_setting (setting_key, setting_value, updated_at) VALUES
 ('legal.controller.name', $v$Yusuf Akın$v$, now()),
 ('legal.controller.address', $v$Belkız Mahallesi, 08004 Sokak, Saltan Apt. E Blok No: 5 Daire: 02, Şehitkamil / Gaziantep, Türkiye$v$, now()),
 ('legal.controller.email', $v$ysufakin23@gmail.com$v$, now()),
 ('support_email', $v$ysufakin23@gmail.com$v$, now()),
 ('legal.hosting.location', $v$Türkiye$v$, now()),
 ('legal.controller.jurisdiction', $v$Gaziantep$v$, now()),
 ('legal.controller.relation', $v$BÜ Kampüs, Bingöl Üniversitesi'nin resmî bir uygulaması değildir; Bingöl Üniversitesi öğrencileri ve personeli için Yusuf Akın tarafından kişisel olarak geliştirilen ve işletilen bağımsız bir uygulamadır. Bingöl Üniversitesi ile kurumsal bir bağlantısı, ortaklığı veya onayı bulunmamaktadır; üniversitenin adı ve alan adı (bingol.edu.tr) yalnızca üyelik doğrulaması ve hizmetin hedef kitlesini belirtmek amacıyla anılır. Üniversitenin adı ve logosu üniversiteye aittir; bunların anılması izin veya ortaklık anlamına gelmez.$v$, now())
ON CONFLICT (setting_key) DO UPDATE
    SET setting_value = EXCLUDED.setting_value, updated_at = now();
