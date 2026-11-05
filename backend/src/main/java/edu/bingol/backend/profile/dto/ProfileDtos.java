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
                              @com.fasterxml.jackson.annotation.JsonInclude(com.fasterxml.jackson.annotation.JsonInclude.Include.NON_NULL) Boolean avatarHidden,
                              @com.fasterxml.jackson.annotation.JsonInclude(com.fasterxml.jackson.annotation.JsonInclude.Include.NON_NULL) Integer popularityScore,
                              @com.fasterxml.jackson.annotation.JsonInclude(com.fasterxml.jackson.annotation.JsonInclude.Include.NON_NULL) Integer followerCount,
                              @com.fasterxml.jackson.annotation.JsonInclude(com.fasterxml.jackson.annotation.JsonInclude.Include.NON_NULL) Long likesReceived,
                              @com.fasterxml.jackson.annotation.JsonInclude(com.fasterxml.jackson.annotation.JsonInclude.Include.NON_NULL) Integer postCount,
                              @com.fasterxml.jackson.annotation.JsonInclude(com.fasterxml.jackson.annotation.JsonInclude.Include.NON_NULL) Long reelCount,
                              boolean emailVerified, boolean verificationDeferred,
                              boolean profileCompleted,
                              @com.fasterxml.jackson.annotation.JsonInclude(com.fasterxml.jackson.annotation.JsonInclude.Include.NON_NULL) String username,
                              @com.fasterxml.jackson.annotation.JsonInclude(com.fasterxml.jackson.annotation.JsonInclude.Include.NON_NULL) String firstName,
                              @com.fasterxml.jackson.annotation.JsonInclude(com.fasterxml.jackson.annotation.JsonInclude.Include.NON_NULL) String lastName,
                              @com.fasterxml.jackson.annotation.JsonInclude(com.fasterxml.jackson.annotation.JsonInclude.Include.NON_NULL) String universityName,
                              @com.fasterxml.jackson.annotation.JsonInclude(com.fasterxml.jackson.annotation.JsonInclude.Include.NON_NULL) List<String> authProviders) {
        /** avatarHidden ve populerlik alanlari yok (null): yalnizca GET /users/me doldurur. */
        public static ProfileView of(User u) {
            return new ProfileView(u.getId(), u.getEmail(), u.getDisplayName(), u.getFaculty(), u.getDepartment(),
                    u.getClassYear(), u.getBio(), u.getAvatarUrl(), u.isShowEmail(), u.getRole(), u.getLanguage(),
                    u.getCreatedAt().toString(), u.getGrade(), null, null, null, null, null, null,
                    u.isEmailVerified(), u.isVerificationDeferred() && !u.isEmailVerified(),
                    u.isProfileCompleted(), u.getUsername(), u.getFirstName(), u.getLastName(), u.getUniversityName(), null);
        }

        /** Bagli giris saglayicilari (GOOGLE, APPLE; yalniz GET /users/me doldurur; parola ile giris her zaman vardir). */
        public ProfileView withAuthProviders(List<String> providers) {
            return new ProfileView(id, email, displayName, faculty, department, classYear, bio, avatarUrl, showEmail,
                    role, language, createdAt, grade, avatarHidden, popularityScore, followerCount, likesReceived,
                    postCount, reelCount, emailVerified, verificationDeferred, profileCompleted, username, firstName,
                    lastName, universityName, providers);
        }

        /** Profil fotografi moderasyonla gizlendi mi (mobil bilgi karti). */
        public ProfileView withAvatarHidden(boolean hidden) {
            return new ProfileView(id, email, displayName, faculty, department, classYear, bio, avatarUrl, showEmail,
                    role, language, createdAt, grade, hidden, popularityScore, followerCount, likesReceived, postCount, reelCount,
                    emailVerified, verificationDeferred, profileCompleted, username, firstName, lastName, universityName,
                    authProviders);
        }

        /** Populerlik puani (0..100) ve bilesenleri: takipci, alinan toplam begeni, gonderi sayisi (gercek sayilar). */
        public ProfileView withPopularity(int score, int followers, long likes, int posts) {
            return new ProfileView(id, email, displayName, faculty, department, classYear, bio, avatarUrl, showEmail,
                    role, language, createdAt, grade, avatarHidden, score, followers, likes, posts, reelCount,
                    emailVerified, verificationDeferred, profileCompleted, username, firstName, lastName, universityName,
                    authProviders);
        }

        /** Reels (video gonderi) sayisi (KS-BE2; yalniz GET /users/me doldurur). */
        public ProfileView withReelCount(long reels) {
            return new ProfileView(id, email, displayName, faculty, department, classYear, bio, avatarUrl, showEmail,
                    role, language, createdAt, grade, avatarHidden, popularityScore, followerCount, likesReceived,
                    postCount, reels, emailVerified, verificationDeferred, profileCompleted, username, firstName,
                    lastName, universityName, authProviders);
        }
    }

    /** Baskasinin profili: e-posta yalnizca sahibi izin verdiyse. */
    public record PublicProfile(Long id, String displayName, String faculty, String department, Short classYear,
                                String bio, String avatarUrl, String email, Long followerCount, Long followingCount,
                                Boolean followedByMe, Boolean followsMe,
                                @com.fasterxml.jackson.annotation.JsonInclude(com.fasterxml.jackson.annotation.JsonInclude.Include.NON_NULL) Boolean blockedByMe,
                                @com.fasterxml.jackson.annotation.JsonProperty("isPrivate") @com.fasterxml.jackson.annotation.JsonInclude(com.fasterxml.jackson.annotation.JsonInclude.Include.NON_NULL) Boolean isPrivate,
                                @com.fasterxml.jackson.annotation.JsonInclude(com.fasterxml.jackson.annotation.JsonInclude.Include.NON_NULL) String followState,
                                @com.fasterxml.jackson.annotation.JsonInclude(com.fasterxml.jackson.annotation.JsonInclude.Include.NON_NULL) Boolean locked,
                                @com.fasterxml.jackson.annotation.JsonInclude(com.fasterxml.jackson.annotation.JsonInclude.Include.NON_NULL) Integer popularityScore,
                                @com.fasterxml.jackson.annotation.JsonInclude(com.fasterxml.jackson.annotation.JsonInclude.Include.NON_NULL) Long likesReceived,
                                @com.fasterxml.jackson.annotation.JsonInclude(com.fasterxml.jackson.annotation.JsonInclude.Include.NON_NULL) Integer postCount,
                                @com.fasterxml.jackson.annotation.JsonInclude(com.fasterxml.jackson.annotation.JsonInclude.Include.NON_NULL) Long reelCount) {
        /** 16 alanli kurucu (populerlik yok): yalniz GET /users/{id} doldurur (withPopularity). */
        public PublicProfile(Long id, String displayName, String faculty, String department, Short classYear,
                             String bio, String avatarUrl, String email, Long followerCount, Long followingCount,
                             Boolean followedByMe, Boolean followsMe, Boolean blockedByMe, Boolean isPrivate,
                             String followState, Boolean locked) {
            this(id, displayName, faculty, department, classYear, bio, avatarUrl, email, followerCount,
                    followingCount, followedByMe, followsMe, blockedByMe, isPrivate, followState, locked, null, null,
                    null, null);
        }

        /** Populerlik puani (0..100), alinan toplam begeni ve gonderi sayisi; takipci sayisi followerCount'tadir. */
        public PublicProfile withPopularity(int score, long likes, int posts) {
            return new PublicProfile(id, displayName, faculty, department, classYear, bio, avatarUrl, email,
                    followerCount, followingCount, followedByMe, followsMe, blockedByMe, isPrivate, followState, locked,
                    score, likes, posts, reelCount);
        }

        /** Reels (video gonderi) sayisi (KS-BE2; gizli/kilitli hesapta cagrilmaz = alan yok). */
        public PublicProfile withReelCount(long reels) {
            return new PublicProfile(id, displayName, faculty, department, classYear, bio, avatarUrl, email,
                    followerCount, followingCount, followedByMe, followsMe, blockedByMe, isPrivate, followState, locked,
                    popularityScore, likesReceived, postCount, reels);
        }

        /**
         * 13 alanli kurucu (gizli hesap alanlari yok): isPrivate/followState/locked yalniz profil ve arama ucunda
         * doldurulur (withRelation); digerlerinde JSON'a yazilmaz.
         */
        public PublicProfile(Long id, String displayName, String faculty, String department, Short classYear,
                             String bio, String avatarUrl, String email, Long followerCount, Long followingCount,
                             Boolean followedByMe, Boolean followsMe, Boolean blockedByMe) {
            this(id, displayName, faculty, department, classYear, bio, avatarUrl, email, followerCount,
                    followingCount, followedByMe, followsMe, blockedByMe, null, null, null);
        }

        /**
         * Gizli hesap iliskisi: isPrivate, followState (NONE | REQUESTED | FOLLOWING | SELF), locked (gizli ve bakan
         * sahibi/kabul edilmis takipcisi degil). locked iken takipci/takip sayaclari gizlenir (null).
         */
        public PublicProfile withRelation(boolean isPrivate, String followState, boolean locked) {
            return new PublicProfile(id, displayName, faculty, department, classYear, bio, avatarUrl, email,
                    locked ? null : followerCount, locked ? null : followingCount, followedByMe, followsMe,
                    blockedByMe, isPrivate, followState, locked, popularityScore, likesReceived, postCount, reelCount);
        }

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
                    followerCount, followingCount, followedByMe, followsMe, blocked, isPrivate, followState, locked,
                    popularityScore, likesReceived, postCount, reelCount);
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
                    following, followedByMe, followsMe, blockedByMe, isPrivate, followState, locked, popularityScore,
                    likesReceived, postCount, reelCount);
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
    /**
     * Metin sinirlari KOD NOKTASI ile ProfileService.update'te denetlenir (T-055; @Size UTF-16 sayar). Buradaki @Size
     * yalniz kaba ust sinirdir (kod noktasi basina en cok 2 UTF-16 birimi).
     */
    public record UpdateProfileRequest(@Size(max = 160) String displayName,
                                       @Size(max = 240) String faculty,
                                       @Size(max = 240) String department,
                                       @Min(0) @Max(8) Short classYear,
                                       @Size(max = 8) String grade,
                                       @Size(max = 600) String bio,
                                       Boolean showEmail,
                                       @Pattern(regexp = "tr|en|ar") String language) {}

    /**
     * Hesap silme yeniden dogrulamasi: parolasi olan hesapta `password` zorunlu. Parolasiz (yalniz OAuth) hesapta
     * `provider` + `token` (+ Apple icin `nonce`) ile bagli saglayicinin TAZE token'i gerekir.
     */
    public record DeleteAccountRequest(@Size(max = 72) String password,
                                       @Pattern(regexp = "(?i)google|apple") String provider,
                                       @Size(max = 8192) String token, @Size(max = 256) String nonce) {}

    /** nextCursor null ise baska sayfa yok; devam icin `?cursor=<nextCursor>`. */
    public record UserSearchResult(List<PublicProfile> items, Long nextCursor) {}

    /** Ana sayfa rozetleri ve profil istatistikleri icin tek istekte sayimlar. */
    public record MeSummary(long communities, long events, long bookmarks, long unreadNotifications,
                            long unreadMessages) {}
}
