package edu.bingol.backend.community;

/**
 * Kulup silindi (yumusak). Kulube bagli etkinlikler (event paketi) bu olayla iptal edilir; olay uyelik/silme
 * islemiyle ayni islemde yayinlanir, dinleyiciler commit sonrasi calisir ve exception sizdirmamalidir.
 */
public record ClubDeletedEvent(Long communityId) {}
