package edu.bingol.backend.profile.dto;

import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.util.List;

public final class ProfileDtos {

    private ProfileDtos() {}

    /** Kendi profilim: her alan gorunur. */
    public record ProfileView(Long id, String email, String displayName, String department, Short classYear,
                              String bio, String avatarUrl, boolean showEmail, Role role, String language,
                              String createdAt) {
        public static ProfileView of(User u) {
            return new ProfileView(u.getId(), u.getEmail(), u.getDisplayName(), u.getDepartment(), u.getClassYear(),
                    u.getBio(), u.getAvatarUrl(), u.isShowEmail(), u.getRole(), u.getLanguage(),
                    u.getCreatedAt().toString());
        }
    }

    /** Baskasinin profili: e-posta yalnizca sahibi izin verdiyse. */
    public record PublicProfile(Long id, String displayName, String department, Short classYear, String bio,
                                String avatarUrl, String email) {
        public static PublicProfile of(User u) {
            return new PublicProfile(u.getId(), u.getDisplayName(), u.getDepartment(), u.getClassYear(), u.getBio(),
                    u.getAvatarUrl(), u.isShowEmail() ? u.getEmail() : null);
        }
    }

    /** Verilmeyen (null) alanlar degismez. Bos metin gonderilirse alan temizlenir. */
    public record UpdateProfileRequest(@Size(min = 2, max = 80) String displayName,
                                       @Size(max = 120) String department,
                                       @Min(0) @Max(8) Short classYear,
                                       @Size(max = 300) String bio,
                                       Boolean showEmail,
                                       @Pattern(regexp = "tr|en|ar") String language) {}

    public record DeleteAccountRequest(@NotBlank String password) {}

    public record UserSearchResult(List<PublicProfile> items) {}
}
