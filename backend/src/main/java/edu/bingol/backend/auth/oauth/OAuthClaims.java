package edu.bingol.backend.auth.oauth;

/**
 * Dogrulanmis saglayici token'indan okunan talepler. {@code subject} saglayicinin degismez kimligidir; {@code email}
 * kucuk harfe normallestirilmistir ve Apple'da (sonraki girislerde) bos olabilir; {@code emailPrivate} Apple gizli
 * e-posta (relay) adresidir.
 */
public record OAuthClaims(OAuthProvider provider, String subject, String email, boolean emailVerified,
                          boolean emailPrivate, String givenName, String familyName) {
}
