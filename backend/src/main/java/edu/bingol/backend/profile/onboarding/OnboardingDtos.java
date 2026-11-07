package edu.bingol.backend.profile.onboarding;

import com.fasterxml.jackson.annotation.JsonInclude;
import edu.bingol.backend.profile.dto.ProfileDtos.ProfileView;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/** Profil tamamlama (onboarding) ve kullanici adi sekilleri (bkz. docs/changes/auth.md). */
public final class OnboardingDtos {

    private OnboardingDtos() {
    }

    /**
     * Onboarding govdesi. Alanlar KULLANICI BEYANIDIR ("dogrulanmis ogrenci" anlamina gelmez).
     * <ul>
     *   <li>{@code universityName}: bos = Bingol Universitesi. Bingol ise fakulte/bolum katalogla (GET /api/catalog/academic)
     *       dogrulanir (gecersiz = 422 ACADEMIC_INVALID); baska universitede serbest metin kabul edilir.</li>
     *   <li>fakulte: {@code facultyId} (katalog kimligi) YA DA {@code facultyName} (TR/EN/AR ad); bolum: {@code departmentId}
     *       ya da {@code departmentName} (secilen fakulte altinda). {@code classYear=OTHER} disinda zorunludur.</li>
     *   <li>{@code classYear}: PREP | Y1..Y6 | POSTGRAD (=Yuksek lisans/MASTER) | MASTER | PHD | OTHER (sinif bilgisi yok).</li>
     *   <li>{@code acceptTerms}: kayit sozlesmelerinin kabulu; true ise onay kaydi yazilir. Gonderilmezse bekleyen
     *       sozlesme onayi {@code /api/legal/accept} ile onceden verilmis olmalidir, yoksa 400 TERMS_REQUIRED.</li>
     * </ul>
     */
    public record OnboardingRequest(@NotBlank @Size(max = 80) String firstName,
                                    @NotBlank @Size(max = 80) String lastName,
                                    @NotBlank @Size(max = 40) String username,
                                    @Size(max = 120) String universityName,
                                    @Size(max = 60) String facultyId, @Size(max = 160) String facultyName,
                                    @Size(max = 60) String departmentId, @Size(max = 160) String departmentName,
                                    @NotBlank @Pattern(regexp = "PREP|Y[1-6]|POSTGRAD|MASTER|PHD|OTHER") String classYear,
                                    @Size(max = 600) String bio,
                                    Boolean acceptTerms) {
    }

    public record OnboardingResponse(boolean profileCompleted, ProfileView user) {
    }

    /** {available, reason?}; reason yalniz available=false iken: TAKEN | INVALID | RESERVED. */
    @JsonInclude(JsonInclude.Include.NON_NULL)
    public record UsernameAvailability(boolean available, String reason) {
        public static UsernameAvailability yes() {
            return new UsernameAvailability(true, null);
        }

        public static UsernameAvailability no(String reason) {
            return new UsernameAvailability(false, reason);
        }
    }

    public record UsernameRequest(@NotBlank @Size(max = 40) String username) {
    }
}
