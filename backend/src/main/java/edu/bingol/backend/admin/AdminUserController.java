package edu.bingol.backend.admin;

import edu.bingol.backend.admin.AdminDtos.AdminMe;
import edu.bingol.backend.admin.AdminDtos.AdminUserDetail;
import edu.bingol.backend.admin.AdminDtos.AdminUserRow;
import edu.bingol.backend.admin.AdminDtos.PageResponse;
import edu.bingol.backend.admin.AdminDtos.RoleRequest;
import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.profile.ProfileService;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserStatus;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.validation.Valid;
import java.io.BufferedWriter;
import java.io.IOException;
import java.io.OutputStreamWriter;
import java.io.UncheckedIOException;
import java.io.Writer;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Yonetim paneli kullanici uclari (/api/admin/** => ROLE_ADMIN). */
@RestController
@RequestMapping("/api/admin")
public class AdminUserController {

    private final AdminUserService service;
    private final ProfileService profiles;
    private final AdminAccountVerificationService accountOps;

    public AdminUserController(AdminUserService service, ProfileService profiles,
                               AdminAccountVerificationService accountOps) {
        this.service = service;
        this.profiles = profiles;
        this.accountOps = accountOps;
    }

    /** Giris yapmis yonetici (JWT gerekir; Basic auth'ta kullanici kaydi yoktur => 401). */
    @GetMapping("/me")
    public AdminMe me() {
        User u = profiles.get(CurrentUser.id());
        return new AdminMe(u.getId(), u.getEmail(), u.getDisplayName(), u.getRole());
    }

    @GetMapping("/users")
    public PageResponse<AdminUserRow> list(@RequestParam(required = false) String q,
                                           @RequestParam(required = false) UserStatus status,
                                           @RequestParam(required = false) Role role,
                                           @RequestParam(required = false) String faculty,
                                           @RequestParam(required = false) String department,
                                           @RequestParam(required = false) Short classYear,
                                           @RequestParam(required = false) String language,
                                           @RequestParam(required = false) Boolean verified,
                                           @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate createdFrom,
                                           @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate createdTo,
                                           @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate seenFrom,
                                           @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate seenTo,
                                           @RequestParam(defaultValue = "0") int page,
                                           @RequestParam(defaultValue = "20") int size,
                                           @RequestParam(required = false) String sort) {
        return service.list(new UserFilter(q, status, role, faculty, department, classYear, language, verified,
                createdFrom, createdTo, seenFrom, seenTo), sort, page, size);
    }

    /** Ayni filtreler; UTF-8 BOM'lu, formul-enjeksiyonuna karsi kacirilmis, en cok 50.000 satir, akis halinde. */
    @GetMapping("/users/export.csv")
    public void exportCsv(@RequestParam(required = false) String q,
                          @RequestParam(required = false) UserStatus status,
                          @RequestParam(required = false) Role role,
                          @RequestParam(required = false) String faculty,
                          @RequestParam(required = false) String department,
                          @RequestParam(required = false) Short classYear,
                          @RequestParam(required = false) String language,
                          @RequestParam(required = false) Boolean verified,
                          @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate createdFrom,
                          @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate createdTo,
                          @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate seenFrom,
                          @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate seenTo,
                          @RequestParam(required = false) String sort,
                          HttpServletResponse res) throws IOException {
        UserFilter f = new UserFilter(q, status, role, faculty, department, classYear, language, verified,
                createdFrom, createdTo, seenFrom, seenTo);
        f.where(); // ters tarih araligi da yanit yazilmadan once 400 versin
        AuditContext.target("USER", null).summary("kullanici CSV disa aktarma (suzgecli)");
        UserFilter.orderBy(sort); // gecersiz sort, yanit yazilmadan once 400 versin
        res.setStatus(HttpStatus.OK.value());
        res.setContentType("text/csv; charset=UTF-8");
        res.setHeader(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"users.csv\"");
        res.setHeader(HttpHeaders.CACHE_CONTROL, "no-store");
        try (Writer w = new BufferedWriter(new OutputStreamWriter(res.getOutputStream(), StandardCharsets.UTF_8))) {
            int rows = service.writeCsv(f, sort, w);
            AuditContext.summary("kullanici CSV disa aktarma: " + rows + " satir, tam e-posta");
        } catch (UncheckedIOException e) {
            throw e.getCause();
        }
    }

    /** Kisisel veri gosterir: okuma da denetim kaydina yazilir. */
    @AuditRead
    @GetMapping("/users/{id}")
    public AdminUserDetail detail(@PathVariable Long id) {
        return service.detail(id);
    }

    @PatchMapping("/users/{id}/role")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void role(@PathVariable Long id, @Valid @RequestBody RoleRequest r, Authentication auth) {
        AuditContext.target("USER", id);
        service.changeRole(actorId(auth), id, r.role());
        AuditContext.summary("rol -> " + r.role()); // yalniz basarida (T-016)
    }

    @DeleteMapping("/users/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id, Authentication auth) {
        AuditContext.target("USER", id);
        service.delete(actorId(auth), id);
        AuditContext.summary("hesap anonimlestirildi"); // yalniz basarida (T-016)
    }

    /** E-postasi dogrulanmamis satiri elle dogrular (idempotent). */
    @PostMapping("/users/{id}/verify-email")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void verifyEmail(@PathVariable Long id, Authentication auth) {
        accountOps.verifyUser(id, actorId(auth));
    }

    /** Kullaniciya sifre sifirlama kodu e-postasi gonderir. */
    @PostMapping("/users/{id}/send-reset")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void sendReset(@PathVariable Long id) {
        accountOps.sendReset(id);
    }

    /** Kullanicinin tum oturumlarini kapatir. */
    @PostMapping("/users/{id}/revoke-sessions")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void revokeSessions(@PathVariable Long id) {
        accountOps.revokeSessions(id);
    }

    /** Basic auth yoneticisinin principal'i Long degildir; kimlik null kalir. */
    private static Long actorId(Authentication auth) {
        return auth.getPrincipal() instanceof Long l ? l : null;
    }
}
