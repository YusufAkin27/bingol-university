package edu.bingol.backend.auth.dto;

import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * acceptTerms: kullanim kosullari, gizlilik, KVKK aydinlatma ve topluluk kurallarinin kabulu (zorunlu).
 * displayName: opsiyonel; bos/yoksa sunucu gecici ad atar (e-posta yerel kismi ya da "Öğrenci"), asil ad ve bolum/sinif
 * kayittan sonra profil guncellemesiyle girilir. Yonetici kaydinda (ADMIN_EMAILS / adminPortal) ad zorunludur.
 * language: tr | en | ar (opsiyonel; verilmezse Accept-Language, o da yoksa tr) — bildirim ve e-posta dili.
 * faculty/department/grade: opsiyonel; verilirse akademik katalogla dogrulanir (ACADEMIC_INVALID).
 * adminPortal: yonetici paneli kayit sayfasi true gonderir (opsiyonel, varsayilan false). YALNIZ daha siki davranis ister:
 * e-posta ADMIN_EMAILS listesinde degilse sunucu hicbir sey yapmadan genel 202 doner (kod gitmez, kayit yazilmaz).
 * Bayrak hicbir kuralı gevsetmez; genel kayit kurali (bingol.edu.tr + ADMIN_EMAILS istisnasi) aynen gecerlidir.
 */
public record RegisterRequest(@NotBlank @Size(max = 254) String email,
                              @NotBlank @Size(max = 72) String password,
                              @Size(max = 80) String displayName,
                              @AssertTrue(message = "{error.TERMS_NOT_ACCEPTED}") boolean acceptTerms,
                              @Pattern(regexp = "tr|en|ar") String language,
                              @Size(max = 120) String faculty,
                              @Size(max = 120) String department,
                              @Size(max = 8) String grade,
                              Boolean adminPortal) {
}
