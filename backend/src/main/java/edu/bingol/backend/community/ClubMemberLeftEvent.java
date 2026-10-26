package edu.bingol.backend.community;

/**
 * Kullanici kulup uyeliginden dustu (ayrildi, cikarildi, yasaklandi, istegi reddedildi). Kulup odasi senkronu
 * ayrica yapilir; bu olay kulube bagli diger odalar (ornegin etkinlik sohbet odalari) icin gevsek bag saglar.
 * Senkron yayinlanir (uyelik islemiyle ayni islemde); dinleyiciler exception sizdirmamalidir.
 */
public record ClubMemberLeftEvent(Long communityId, Long userId) {}
