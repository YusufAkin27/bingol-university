package edu.bingol.backend.profile.privacy;

/** Bir profil alanini kimlerin gorebilecegi. */
public enum Audience {
    EVERYONE,
    /** Yalnizca ortak kulup / sohbet / etkinlik bagi olanlar. */
    SHARED_CONTEXT,
    ONLY_ME
}
