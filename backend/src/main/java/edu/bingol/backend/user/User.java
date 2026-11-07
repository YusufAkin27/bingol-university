package edu.bingol.backend.user;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.ColumnDefault;

@Entity
@Table(name = "app_user")
@Getter
@Setter
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 254)
    private String email;

    @Column(nullable = false, length = 100)
    private String passwordHash;

    @Column(nullable = false, length = 80)
    private String displayName;

    /** Ad / soyad (profil tamamlama; kullanici beyani). Eski hesaplarda null: gorunen ad tek alandi. */
    @Column(length = 60)
    private String firstName;

    @Column(length = 60)
    private String lastName;

    /**
     * Benzersiz kullanici adi: 3-24 karakter, yalniz kucuk harf/rakam/nokta/alt cizgi (buyuk-kucuk harf duyarsizligi
     * KUCUK HARFE normallestirilerek saglanir; benzersiz indeks bu sutundadir). Eski hesaplarda null (sonradan atanir).
     */
    @Column(length = 24, unique = true)
    private String username;

    /** Kullanici adinin son atanma/degisim ani (degisim bekleme suresi icin). */
    private Instant usernameSetAt;

    /** Kullanici beyani universite adi (null = Bingol Universitesi varsayilani). Dogrulanmis ogrenci anlamina GELMEZ. */
    @Column(length = 120)
    private String universityName;

    /**
     * Profil tamamlanma ani. null = tamamlanmadi: yazma uclari 403 PROFILE_INCOMPLETE (ProfileIncompleteWriteFilter).
     * DB varsayilani now(): ham INSERT yazan betikler/eski yollar kilitlenmesin; yalniz OAuth ile acilan hesap bilincli
     * null yazar. Migration mevcut tum kullanicilar icin created_at atar.
     */
    @ColumnDefault("CURRENT_TIMESTAMP")
    private Instant profileCompletedAt = Instant.now(); // yeni User() varsayilan TAMAM; OAuth yolu bilincli null yazar

    private boolean emailVerified;

    /**
     * Hesap e-postasi Apple "E-postami gizle" role adresi mi (RelayEmails; V1472). true = bildirim/sifre sifirlama
     * postasi guvenilir ulasmaz; kullanicidan gercek adres istenir (POST /api/users/me/email/start).
     */
    @ColumnDefault("false")
    private boolean emailRelay;

    /**
     * Gercek e-posta KAPISI (V1472): yalniz YENI role hesaplarda true; gercek adres dogrulanana kadar yazma uclari
     * 403 REAL_EMAIL_REQUIRED. Mevcut canli role hesaplar false kalir (yumusak adim; kilitlenmezler).
     */
    @ColumnDefault("false")
    private boolean realEmailRequired;

    /** Gercek adresin kodla dogrulandigi an (role hesaplar icin); null = hic role olmadi / henuz dogrulanmadi. */
    private Instant realEmailVerifiedAt;

    /**
     * Kota asiminda ertelenmis dogrulama (QT-BE): hesap kod gonderilemedigi icin dogrulanmamis acildi; yalniz okur.
     * email_verified=true olunca anlamsizdir (dogrulama anlik false yapar).
     */
    @ColumnDefault("false")
    private boolean verificationDeferred;

    /** DeferredVerificationJob'un bu hesaba son kod postasi kuyruga aldigi an (kota gunu basina en cok 1). */
    private Instant verificationMailedAt;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private Role role = Role.USER;

    /** Yonetici profili (P16); yalniz role=ADMIN icin anlamli. null + ADMIN = FULL (migrasyon oncesi geriye uyum). */
    @Enumerated(EnumType.STRING)
    @Column(length = 16)
    private edu.bingol.backend.admin.rbac.AdminProfile adminProfile;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private UserStatus status = UserStatus.ACTIVE;

    @Column(length = 120)
    private String department;

    /** Fakulte (serbest metin; yonetici `faculties` ayarini doldurduysa listeden biri). */
    @Column(length = 120)
    private String faculty;

    private Short classYear;

    /** Sinif: PREP, 1..6, MASTER, PHD (katalog `grades`); eski kullanicilarda null. */
    @Column(length = 8)
    private String grade;

    @Column(length = 300)
    private String bio;

    @Column(length = 300)
    private String avatarUrl;

    private boolean showEmail;

    /** tr | en | ar: bildirim ve e-posta dili. */
    @Column(nullable = false, length = 2)
    private String language = "tr";

    @Column(length = 300)
    private String suspendedReason;

    /** E-posta kodlu iki faktorlu dogrulama acik mi (kullanici kendisi acar; bkz. auth.twofactor). */
    // DB varsayilani: ham INSERT yazan betikler/testler alani vermeyince NOT NULL ihlali olmasin (V1060'ta da DEFAULT FALSE)
    @ColumnDefault("false")
    private boolean twoFactorEnabled;

    private Instant twoFactorEnabledAt;

    private Instant deletedAt;

    /** Son gorulme (en cok 5 dakikada bir guncellenir; bkz. analytics.ActivityTracker). */
    private Instant lastSeenAt;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    /** Rehber eslestirme icin e-postanin SHA-256'si; kayitta/guncellemede otomatik, silinmis hesapta null. */
    @Column(length = 64)
    @com.fasterxml.jackson.annotation.JsonIgnore
    private String emailSha256;

    @jakarta.persistence.PrePersist
    @jakarta.persistence.PreUpdate
    void syncEmailHash() {
        boolean gone = status == UserStatus.DELETED || deletedAt != null || email == null;
        emailSha256 = gone ? null : edu.bingol.backend.common.Hashing.sha256(email.trim().toLowerCase(java.util.Locale.ROOT));
    }

    public boolean isActive() {
        return status == UserStatus.ACTIVE;
    }

    /** OAuth ile acilan hesabin parola alani: bcrypt bicimine uymaz, matches() daima false doner (parola girisi kapali). */
    public static final String NO_PASSWORD_PREFIX = "!oauth:";

    /** Kullanilabilir bir parola ozeti var mi: "!" ile baslayan isaretler (OAuth "!oauth:", silinmis "!deleted:") parola DEGILDIR. */
    public static boolean hasUsablePassword(String hash) {
        return hash != null && !hash.isEmpty() && !hash.startsWith("!");
    }

    public boolean hasPassword() {
        return hasUsablePassword(passwordHash);
    }

    public boolean isProfileCompleted() {
        return profileCompletedAt != null;
    }
}
