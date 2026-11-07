-- V1260: kota asiminda ERTELENMIS e-posta dogrulama (QT-BE). verification_deferred: hesap kota doluyken dogrulama kodu
-- gonderilemedigi icin dogrulanmamis ACILDI (yalniz okur, UnverifiedWriteFilter). verification_mailed_at: DeferredVerificationJob son kod postasi.
ALTER TABLE app_user ADD COLUMN verification_deferred BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE app_user ADD COLUMN verification_mailed_at TIMESTAMPTZ;
-- is taramasi ve gece saklama: yalniz dogrulanmamis ertelenmis satirlar (kucuk kume)
CREATE INDEX qd_app_user_deferred_idx ON app_user (created_at) WHERE verification_deferred AND NOT email_verified;
