-- Google / Apple ile giris + profil tamamlama (onboarding). YALNIZ EKLEME, geriye uyumlu.
--
-- 1) app_user: ad/soyad, benzersiz kullanici adi, universite beyani, profil tamamlanma ani.
--    profile_completed_at DEFAULT now(): ham INSERT yazan betikler/eski yollar "tamamlanmis" sayilir (kilitlenmez);
--    yalniz OAuth ile acilan hesap uygulama kodunda bilincli NULL yazar ve sunucu kapisi (ProfileIncompleteWriteFilter)
--    onboarding bitene kadar yazma uclarini 403 PROFILE_INCOMPLETE ile kapatir.
--    MEVCUT TUM KULLANICILAR tamamlanmis sayilir (created_at); hicbir mevcut kullanici kilitlenmez.
--    Kullanici adi mevcutlara BOS kalir (PUT /api/users/me/username ile istege bagli atanir).
ALTER TABLE app_user ADD COLUMN first_name VARCHAR(60);
ALTER TABLE app_user ADD COLUMN last_name VARCHAR(60);
ALTER TABLE app_user ADD COLUMN username VARCHAR(24);
ALTER TABLE app_user ADD COLUMN username_set_at TIMESTAMPTZ;
ALTER TABLE app_user ADD COLUMN university_name VARCHAR(120);
ALTER TABLE app_user ADD COLUMN profile_completed_at TIMESTAMPTZ DEFAULT now();
UPDATE app_user SET profile_completed_at = created_at;

-- Kullanici adi KUCUK harfe normallestirilerek saklanir; benzersizlik kucuk harf duyarsizdir (eszamanli iki istekte
-- ikincisi bu indeksle reddedilir -> 409 USERNAME_TAKEN). NULL'lar serbesttir (PostgreSQL'de NULL'lar birbirinden farkli).
CREATE UNIQUE INDEX au1450_app_user_username_uq ON app_user (username);
ALTER TABLE app_user ADD CONSTRAINT au1450_app_user_username_chk
    CHECK (username IS NULL OR (username = lower(username) AND username ~ '^[a-z][a-z0-9._]{2,23}$'));

-- 2) Saglayici kimligi: (provider, subject) benzersiz. subject saglayicinin degismez kullanici kimligidir (Google/Apple
--    `sub`); e-posta degisse de ayni kisi taninir. E-posta yalniz bilgi (gizli Apple relay adresi olabilir).
--    Bir kullanici saglayici basina en fazla BIR kimlik baglar. Hesap silinince satirlar AccountDataPurger ile silinir.
CREATE TABLE auth_identity (
    id               BIGSERIAL PRIMARY KEY,
    user_id          BIGINT       NOT NULL REFERENCES app_user (id),
    provider         VARCHAR(16)  NOT NULL,
    subject          VARCHAR(255) NOT NULL,
    email            VARCHAR(254),
    email_is_private BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    last_login_at    TIMESTAMPTZ
);
CREATE UNIQUE INDEX au1450_auth_identity_prov_sub_uq ON auth_identity (provider, subject);
CREATE UNIQUE INDEX au1450_auth_identity_user_prov_uq ON auth_identity (user_id, provider);
