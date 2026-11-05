-- Kampus Forum (E alani): bildirim tercihleri + olay tekrar defteri. Onek: fe14_.
-- Tercih satiri yoksa hepsi ACIK sayilir (satir ilk degisiklikte yazilir). moderation sutunu bilgi icindir:
-- moderasyon bildirimi kapatilamaz (hizmet sabit true yazar/okur).
CREATE TABLE forum_notification_pref (
    user_id         BIGINT      PRIMARY KEY REFERENCES app_user (id) ON DELETE CASCADE,
    all_enabled     BOOLEAN     NOT NULL DEFAULT TRUE,
    topic_comments  BOOLEAN     NOT NULL DEFAULT TRUE,
    comment_replies BOOLEAN     NOT NULL DEFAULT TRUE,
    likes           BOOLEAN     NOT NULL DEFAULT TRUE,
    followed_topics BOOLEAN     NOT NULL DEFAULT TRUE,
    moderation      BOOLEAN     NOT NULL DEFAULT TRUE,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Ayni olay icin ayni aliciya ikinci bildirim gitmesin (begeni al-ver-al, yeniden denenen istek, cift olay):
-- (tur, hedef, eden, alici) benzersizdir; ekleme basarili olursa bildirim gider. Satirlar 90 gunden sonra temizlenir.
CREATE TABLE forum_notify_seen (
    kind         VARCHAR(24) NOT NULL,
    target_id    BIGINT      NOT NULL,
    actor_id     BIGINT      NOT NULL,
    recipient_user_id BIGINT NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (kind, target_id, actor_id, recipient_user_id)
);
CREATE INDEX fe14_seen_created ON forum_notify_seen (created_at);
CREATE INDEX fe14_seen_actor ON forum_notify_seen (actor_id);
CREATE INDEX fe14_seen_recipient ON forum_notify_seen (recipient_user_id);
