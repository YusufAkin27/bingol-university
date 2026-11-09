-- Bolum kanali otomatik katilim: kullanici kanaldan KENDISI ciktiysa tercih kalici saklanir; hicbir otomatik katilim
-- (profil guncelleme, geri doldurma) onu o kanala yeniden eklemez. Elle yeniden katilinca kayit silinir. Onek dco1810_.
CREATE TABLE department_chat_optout (
    user_id    BIGINT       NOT NULL REFERENCES app_user (id) ON DELETE CASCADE,
    dept_key   VARCHAR(200) NOT NULL,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT dco1810_pk PRIMARY KEY (user_id, dept_key)
);
