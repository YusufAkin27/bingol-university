-- V992 (W2-E, T-059): uygunsuz ifade kategorileri. PROFANITY (kufur, mevcut), HATE (nefret/asagilama), TERROR (teror
-- ovgusu/propagandasi), SELF_HARM (kendine zarara tesvik). Yonetici kelimeleri ve engelleme gunlugu kategori tasir;
-- yerlesik kategori listeleri kaynak dosyalardadir (moderation/profanity-<kategori>-*.txt). lang: KU (Kurtce) kabul edilir.
ALTER TABLE profanity_term ADD COLUMN category VARCHAR(12) NOT NULL DEFAULT 'PROFANITY';
ALTER TABLE profanity_term ADD CONSTRAINT mod9_prf_term_cat_chk CHECK (category IN ('PROFANITY', 'HATE', 'TERROR', 'SELF_HARM'));
ALTER TABLE profanity_hit_log ADD COLUMN category VARCHAR(12) NOT NULL DEFAULT 'PROFANITY';
CREATE INDEX mod9_prf_hit_cat ON profanity_hit_log (category, at);
