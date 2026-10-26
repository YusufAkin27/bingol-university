package edu.bingol.backend.profile.privacy;

public final class PrivacyDtos {

    private PrivacyDtos() {}

    public record PrivacyView(Audience avatar, Audience bio, Audience department, Audience faculty,
                              Audience classYear, boolean avatarHiddenByModeration) {
        public static PrivacyView of(ProfilePrivacy p) {
            return new PrivacyView(p.getAvatarAudience(), p.getBioAudience(), p.getDepartmentAudience(),
                    p.getFacultyAudience(), p.getClassYearAudience(), p.isAvatarHidden());
        }
    }

    /** Verilmeyen (null) alanlar degismez. */
    public record UpdatePrivacyRequest(Audience avatar, Audience bio, Audience department, Audience faculty,
                                       Audience classYear) {}
}
