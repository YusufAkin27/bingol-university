package edu.bingol.backend.profile.privacy;

public final class PrivacyDtos {

    private PrivacyDtos() {}

    public record PrivacyView(Audience avatar, Audience bio, Audience department, Audience faculty,
                              Audience classYear, boolean avatarHiddenByModeration, Audience presence) {
        public static PrivacyView of(ProfilePrivacy p) {
            return new PrivacyView(p.getAvatarAudience(), p.getBioAudience(), p.getDepartmentAudience(),
                    p.getFacultyAudience(), p.getClassYearAudience(), p.isAvatarHidden(), p.getPresenceAudience());
        }
    }

    /**
     * Verilmeyen (null) alanlar degismez. presence: cevrimici/son gorulme kitlesi (EVERYONE | SHARED_CONTEXT | ONLY_ME;
     * varsayilan SHARED_CONTEXT, T-025).
     */
    public record UpdatePrivacyRequest(Audience avatar, Audience bio, Audience department, Audience faculty,
                                       Audience classYear, Audience presence) {
        /** Eski 5 alanli kurucu (presence yok). */
        public UpdatePrivacyRequest(Audience avatar, Audience bio, Audience department, Audience faculty,
                                    Audience classYear) {
            this(avatar, bio, department, faculty, classYear, null);
        }
    }
}
