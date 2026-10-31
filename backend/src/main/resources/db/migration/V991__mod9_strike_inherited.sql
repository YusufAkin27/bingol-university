-- V991 (W2-E, T-058): yeniden kayitta ihlal defterinden devralinan strike'lar isaretlenir (yonetici panelinde ayirt edilir).
ALTER TABLE moderation_strike ADD COLUMN inherited BOOLEAN NOT NULL DEFAULT FALSE;
