package edu.bingol.backend.moderation;

public enum ReportReason { SPAM, HARASSMENT, INAPPROPRIATE, IMPERSONATION,
    /** Kampus Forum: baskasinin kisisel bilgisinin (telefon, adres, kimlik...) ifsasi. Eklendi: V1430 donemi, sutun VARCHAR(32), CHECK yok. */
    PERSONAL_INFO, OTHER }
