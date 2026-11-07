-- Gercek e-posta (role adresi) dogrulamasi. YALNIZ EKLEME, geriye uyumlu.
-- NUMARA NOTU: V1470 baska dalda (deploy/legal-20261106, hukuki metin) yazilir; bu dosya V1472'dir. Canlida V1470 once
-- uygulanmali (prod'da spring.flyway.out-of-order=false): once legal, sonra bu dal.
--
-- email_relay:          hesap e-postasi Apple "E-postami gizle" role adresi (@privaterelay.appleid.com) mi.
--                       Aciksa kullaniciya "gercek e-posta" adimi gosterilir (GET /api/users/me -> emailNeedsReal).
-- real_email_required:  KAPI. Yalniz bu ozellikten SONRA acilan yeni role hesaplarda TRUE; yazma uclari gercek e-posta
--                       dogrulanana kadar 403 REAL_EMAIL_REQUIRED. MEVCUT canli kullanicilar kilitlenmez (FALSE kalir,
--                       yalniz uygulamada yumusak adim gosterilir).
-- real_email_verified_at: gercek adresin kodla dogrulandigi an (bilgi).
ALTER TABLE app_user ADD COLUMN email_relay BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE app_user ADD COLUMN real_email_required BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE app_user ADD COLUMN real_email_verified_at TIMESTAMPTZ;

-- Geriye donuk isaretleme: e-postasi role alan adinda olanlar (alan adi listesi RelayEmails.RELAY_DOMAINS ile ayni).
UPDATE app_user SET email_relay = TRUE WHERE lower(email) LIKE '%@privaterelay.appleid.com';

-- Apple kimligi "gizli e-posta" diyen ve hesap e-postasi o kimligin adresiyle ayni olan hesaplar da role sayilir.
UPDATE app_user u SET email_relay = TRUE
 WHERE u.email_relay = FALSE
   AND EXISTS (SELECT 1 FROM auth_identity i
                WHERE i.user_id = u.id AND i.provider = 'APPLE' AND i.email_is_private = TRUE
                  AND lower(i.email) = lower(u.email));
