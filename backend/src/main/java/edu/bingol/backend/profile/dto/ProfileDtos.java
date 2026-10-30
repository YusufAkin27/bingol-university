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
    public record ProfileView(Long id, String email, String displayName, String faculty, String department,
                              Short classYear, String bio, String avatarUrl, boolean showEmail, Role role,
                              String language, String createdAt, String grade,
                              @com.fasterxml.jackson.annotation.JsonInclude(com.fasterxml.jackson.annotation.JsonInclude.Include.NON_NULL) Boolean avatarHidden) {
        /** avatarHidden yok (null): yalnizca GET /users/me doldurur. */
        public static ProfileView of(User u) {
            return new ProfileView(u.getId(), u.getEmail(), u.getDisplayName(), u.getFaculty(), u.getDepartment(),
                    u.getClassYear(), u.getBio(), u.getAvatarUrl(), u.isShowEmail(), u.getRole(), u.getLanguage(),
                    u.getCreatedAt().toString(), u.getGrade(), null);
        }

        /** Profil fotografi moderasyonla gizlendi mi (mobil bilgi karti). */
        public ProfileView withAvatarHidden(boolean hidden) {
            return new ProfileView(id, email, displayName, faculty, department, classYear, bio, avatarUrl, showEmail,
                    role, language, createdAt, grade, hidden);
        }
    }

    /** Baskasinin profili: e-posta yalnizca sahibi izin verdiyse. */
    public record PublicProfile(Long id, String displayName, String faculty, String department, Short classYear,
                                String bio, String avatarUrl, String email, Long followerCount, Long followingCount,
                                Boolean followedByMe, Boolean followsMe,
                                @com.fasterxml.jackson.annotation.JsonInclude(com.fasterxml.jackson.annotation.JsonInclude.Include.NON_NULL) Boolean blockedByMe) {
        /** 12 alanli kurucu (blockedByMe yok): yalniz GET /users/{id} doldurur. */
        public PublicProfile(Long id, String displayName, String faculty, String department, Short classYear,
                             String bio, String avatarUrl, String email, Long followerCount, Long followingCount,
                             Boolean followedByMe, Boolean followsMe) {
            this(id, displayName, faculty, department, classYear, bio, avatarUrl, email, followerCount,
                    followingCount, followedByMe, followsMe, null);
        }

        /** Istek sahibi bu kullaniciyi engellemis mi (yalniz baskasinin profilinde, oturumlu istekte). */
        public PublicProfile withBlockedByMe(boolean blocked) {
            return new PublicProfile(id, displayName, faculty, department, classYear, bio, avatarUrl, email,
                    followerCount, followingCount, followedByMe, followsMe, blocked);
        }

        /** Takip alanlari olmadan (yalniz profil ucu doldurur; digerlerinde null). */
        public PublicProfile(Long id, String displayName, String faculty, String department, Short classYear,
                             String bio, String avatarUrl, String email) {
            this(id, displayName, faculty, department, classYear, bio, avatarUrl, email, null, null, null, null);
        }

        /** Eski 11 alanli kurucu (followsMe null). */
        public PublicProfile(Long id, String displayName, String faculty, String department, Short classYear,
                             String bio, String avatarUrl, String email, Long followerCount, Long followingCount,
                             Boolean followedByMe) {
            this(id, displayName, faculty, department, classYear, bio, avatarUrl, email, followerCount,
                    followingCount, followedByMe, null);
        }

        public PublicProfile withFollow(long followers, long following, boolean followedByMe, boolean followsMe) {
            return new PublicProfile(id, displayName, faculty, department, classYear, bio, avatarUrl, email, followers,
                    following, followedByMe, followsMe, blockedByMe);
        }

        public PublicProfile withFollow(long followers, long following, boolean followedByMe) {
            return withFollow(followers, following, followedByMe, false);
        }

        public static PublicProfile of(User u) {
            return new PublicProfile(u.getId(), u.getDisplayName(), u.getFaculty(), u.getDepartment(),
                    u.getClassYear(), u.getBio(), u.getAvatarUrl(), u.isShowEmail() ? u.getEmail() : null);
        }
    }

    /** Verilmeyen (null) alanlar degismez. Bos metin gonderilirse alan temizlenir. */
    public record UpdateProfileRequest(@Size(min = 2, max = 80) String displayName,
                                       @Size(max = 120) String faculty,
                                       @Size(max = 120) String department,
                                       @Min(0) @Max(8) Short classYear,
                                       @Size(max = 8) String grade,
                                       @Size(max = 300) String bio,
                                       Boolean showEmail,
                                       @Pattern(regexp = "tr|en|ar") String language) {}

    public record DeleteAccountRequest(@NotBlank String password) {}

    /** nextCursor null ise baska sayfa yok; devam icin `?cursor=<nextCursor>`. */
    public record UserSearchResult(List<PublicProfile> items, Long nextCursor) {}

    /** Ana sayfa rozetleri ve profil istatistikleri icin tek istekte sayimlar. */
    public record MeSummary(long communities, long events, long bookmarks, long unreadNotifications,
                            long unreadMessages) {}
}
