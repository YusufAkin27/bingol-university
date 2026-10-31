package edu.bingol.backend.profile.privacy;

public final class PrivacyDtos {

    private PrivacyDtos() {}

    /** privateAccount: gizli hesap (takip isteği ile takip edilir, içerik yalnız kabul edilmiş takipçilere). */
    public record PrivacyView(Audience avatar, Audience bio, Audience department, Audience faculty,
                              Audience classYear, boolean avatarHiddenByModeration, Audience presence,
                              boolean privateAccount) {
        public static PrivacyView of(ProfilePrivacy p) {
            return new PrivacyView(p.getAvatarAudience(), p.getBioAudience(), p.getDepartmentAudience(),
                    p.getFacultyAudience(), p.getClassYearAudience(), p.isAvatarHidden(), p.getPresenceAudience(),
                    p.isPrivateAccount());
        }
    }

    /**
     * Verilmeyen (null) alanlar değişmez. presence: çevrimiçi/son görülme kitlesi (EVERYONE | SHARED_CONTEXT | ONLY_ME;
     * varsayılan SHARED_CONTEXT, T-025). privateAccount: gizli hesap anahtarı (saatte en çok 10 değişiklik).
     */
    public record UpdatePrivacyRequest(Audience avatar, Audience bio, Audience department, Audience faculty,
                                       Audience classYear, Audience presence, Boolean privateAccount) {
        /** Önceki 6 alanlı kurucu (privateAccount yok). */
        public UpdatePrivacyRequest(Audience avatar, Audience bio, Audience department, Audience faculty,
                                    Audience classYear, Audience presence) {
            this(avatar, bio, department, faculty, classYear, presence, null);
        }

        /** Eski 5 alanlı kurucu (presence yok). */
        public UpdatePrivacyRequest(Audience avatar, Audience bio, Audience department, Audience faculty,
                                    Audience classYear) {
            this(avatar, bio, department, faculty, classYear, null, null);
        }
    }
}
