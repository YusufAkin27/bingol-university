package edu.bingol.backend.community.admin;

import edu.bingol.backend.admin.AdminReasonRequired;
import edu.bingol.backend.admin.AuditContext;
import edu.bingol.backend.admin.AuditRead;
import edu.bingol.backend.admin.Csv;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.community.admin.ClubAdminDtos.ActionResult;
import edu.bingol.backend.community.admin.ClubAdminDtos.ClubDetail;
import edu.bingol.backend.community.admin.ClubAdminDtos.ClubRow;
import edu.bingol.backend.community.admin.ClubAdminDtos.MemberActionResult;
import edu.bingol.backend.community.admin.ClubAdminDtos.MemberRow;
import edu.bingol.backend.community.admin.ClubAdminDtos.PageResult;
import edu.bingol.backend.community.admin.ClubAdminDtos.ReasonRequest;
import edu.bingol.backend.community.admin.ClubAdminDtos.RoleRequest;
import edu.bingol.backend.community.admin.ClubAdminDtos.TransferRequest;
import edu.bingol.backend.community.admin.ClubAdminDtos.UpdateRequest;
import edu.bingol.backend.community.admin.ClubAdminQueryService.ClubFilter;
import edu.bingol.backend.community.permissions.ClubAuditService;
import edu.bingol.backend.community.permissions.ClubDtos.AuditView;
import edu.bingol.backend.community.permissions.ClubDtos.InviteView;
import edu.bingol.backend.community.permissions.ClubInviteService;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.validation.Valid;
import java.io.BufferedWriter;
import java.io.IOException;
import java.io.OutputStreamWriter;
import java.io.Writer;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Arrays;
import java.util.List;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

/**
 * Yonetici kulup yonetimi (P06; `/api/admin/**` yalniz ADMIN). Onay kuyrugu (`GET ?status=` imecli, approve/reject)
 * CommunityAdminController'da DEGISMEDEN kalir: `page` parametresi verilen GET liste bu denetleyiciye duser (sayfa
 * tabanli, tum durumlar). Yazma uclari AdminGuardInterceptor ile hiz sinirli; kapatma/silme/devir/uye cikarma/rol
 * SEBEP ister (AdminGuardPolicy) ve COMMUNITY/{id} hedefiyle denetlenir. Sozlesme: docs/changes/clubadmin.md.
 */
@RestController
@RequestMapping("/api/admin/communities")
public class ClubAdminController {

    static final int READ_PER_MINUTE = 120;
    private static final List<String> CSV_HEADER = Arrays.asList("id", "ad", "slug", "kategori", "durum", "gorunurluk",
            "katilim", "sahipId", "sahipAd", "sahipEposta", "uye", "bekleyen", "acikRapor", "etkinlik", "olusturma");

    private final ClubAdminQueryService query;
    private final ClubAdminService service;
    private final ClubAuditService clubAudit;
    private final ClubInviteService invites;
    private final RateLimiter limiter;

    public ClubAdminController(ClubAdminQueryService query, ClubAdminService service, ClubAuditService clubAudit,
                               ClubInviteService invites, RateLimiter limiter) {
        this.query = query;
        this.service = service;
        this.clubAudit = clubAudit;
        this.invites = invites;
        this.limiter = limiter;
    }

    /**
     * Sayfa tabanli liste (`page` zorunlu: yoksa eski imecli onay kuyrugu ucu calisir). status bos = silinmisler haric,
     * ALL = hepsi; sort: createdAt|name|memberCount|openReports|id; dir: asc|desc.
     */
    @GetMapping(params = "page")
    public PageResult<ClubRow> list(@RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "20") int size,
                                    @RequestParam(required = false) String status,
                                    @RequestParam(required = false) String category,
                                    @RequestParam(required = false) String q,
                                    @RequestParam(required = false) String visibility,
                                    @RequestParam(required = false) String joinPolicy,
                                    @RequestParam(required = false) Long ownerId,
                                    @RequestParam(required = false) Integer minReports,
                                    @RequestParam(required = false) String sort,
                                    @RequestParam(required = false) String dir) {
        limit();
        return query.list(new ClubFilter(status, category, q, visibility, joinPolicy, ownerId, minReports, sort, dir),
                page, size);
    }

    /** Ayni suzgeclerle CSV (UTF-8 BOM, formul kacisli, en cok 50.000 satir). Kendisi de denetlenir. */
    @GetMapping("/export.csv")
    public void exportCsv(@RequestParam(required = false) String status, @RequestParam(required = false) String category,
                          @RequestParam(required = false) String q, @RequestParam(required = false) String visibility,
                          @RequestParam(required = false) String joinPolicy, @RequestParam(required = false) Long ownerId,
                          @RequestParam(required = false) Integer minReports, HttpServletResponse res)
            throws IOException {
        limit();
        List<ClubRow> rows = query.export(new ClubFilter(status, category, q, visibility, joinPolicy, ownerId, minReports,
                null, null));
        res.setStatus(HttpStatus.OK.value());
        res.setContentType("text/csv; charset=UTF-8");
        res.setHeader(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"kulupler.csv\"");
        res.setHeader(HttpHeaders.CACHE_CONTROL, "no-store");
        try (Writer w = new BufferedWriter(new OutputStreamWriter(res.getOutputStream(), StandardCharsets.UTF_8))) {
            w.write(Csv.BOM);
            w.write(Csv.row(CSV_HEADER));
            for (ClubRow r : rows) {
                w.write(Csv.row(Arrays.asList(r.id(), r.name(), r.slug(), r.category(), r.status(), r.visibility(),
                        r.joinPolicy(), r.ownerId(), r.ownerName(), r.ownerEmail(), r.memberCount(), r.pendingCount(),
                        r.openReportCount(), r.eventCount(), r.createdAt())));
            }
            w.flush();
        } finally {
            AuditContext.target("COMMUNITY", null).summary("csv satir=" + rows.size());
        }
    }

    @GetMapping("/{id}")
    public ClubDetail detail(@PathVariable Long id) {
        limit();
        return query.detail(id);
    }

    @PatchMapping("/{id}")
    public ClubDetail update(@PathVariable Long id, @Valid @RequestBody UpdateRequest body) {
        return service.update(id, body);
    }

    @PostMapping("/{id}/cover")
    public ClubDetail cover(@PathVariable Long id, @RequestParam("file") MultipartFile file) {
        return service.setCover(id, file);
    }

    @DeleteMapping("/{id}/cover")
    public ClubDetail removeCover(@PathVariable Long id) {
        return service.removeCover(id);
    }

    // ---- durum ----

    @AdminReasonRequired
    @PostMapping("/{id}/close")
    public ActionResult close(@PathVariable Long id, @RequestBody(required = false) ReasonRequest body) {
        return service.close(id, reason(body));
    }

    @AdminReasonRequired
    @PostMapping("/{id}/reopen")
    public ActionResult reopen(@PathVariable Long id, @RequestBody(required = false) ReasonRequest body) {
        return service.reopen(id, reason(body));
    }

    /** Yumusak silme, GERI ALINAMAZ (cevapta irreversible=true). */
    @AdminReasonRequired
    @DeleteMapping("/{id}")
    public ActionResult delete(@PathVariable Long id, @RequestBody(required = false) ReasonRequest body) {
        return service.delete(id, reason(body));
    }

    // ---- uyeler ----

    /** Uye e-postalari kisisel veridir: okuma denetlenir. status: ACTIVE|PENDING|BANNED, role: OWNER|ADMIN|MODERATOR|MEMBER. */
    @AuditRead
    @GetMapping("/{id}/members")
    public PageResult<MemberRow> members(@PathVariable Long id, @RequestParam(required = false) String status,
                                         @RequestParam(required = false) String role,
                                         @RequestParam(required = false) String q,
                                         @RequestParam(defaultValue = "0") int page,
                                         @RequestParam(defaultValue = "20") int size) {
        limit();
        return query.members(id, status, role, q, page, size);
    }

    @AdminReasonRequired
    @DeleteMapping("/{id}/members/{userId}")
    public MemberActionResult removeMember(@PathVariable Long id, @PathVariable Long userId,
                                           @RequestParam(defaultValue = "false") boolean ban,
                                           @RequestBody(required = false) ReasonRequest body) {
        return service.removeMember(id, userId, ban);
    }

    @AdminReasonRequired
    @PatchMapping("/{id}/members/{userId}/role")
    public MemberActionResult setRole(@PathVariable Long id, @PathVariable Long userId, @Valid @RequestBody RoleRequest body) {
        return service.setRole(id, userId, body.role());
    }

    @AdminReasonRequired
    @PostMapping("/{id}/transfer-ownership")
    public ActionResult transfer(@PathVariable Long id, @Valid @RequestBody TransferRequest body) {
        return service.transferOwnership(id, body);
    }

    // ---- basvurular / davetler / kulup denetimi ----

    @AuditRead
    @GetMapping("/{id}/join-requests")
    public PageResult<MemberRow> joinRequests(@PathVariable Long id, @RequestParam(required = false) String q,
                                              @RequestParam(defaultValue = "0") int page,
                                              @RequestParam(defaultValue = "20") int size) {
        limit();
        return query.members(id, "PENDING", null, q, page, size);
    }

    @PostMapping("/{id}/join-requests/{userId}/approve")
    public MemberActionResult approveRequest(@PathVariable Long id, @PathVariable Long userId) {
        return service.decideRequest(id, userId, true);
    }

    @PostMapping("/{id}/join-requests/{userId}/reject")
    public MemberActionResult rejectRequest(@PathVariable Long id, @PathVariable Long userId) {
        return service.decideRequest(id, userId, false);
    }

    @GetMapping("/{id}/invites")
    public List<InviteView> invites(@PathVariable Long id) {
        limit();
        return invites.list(ClubAdminService.actor(), id);
    }

    @AdminReasonRequired
    @DeleteMapping("/{id}/invites/{inviteId}")
    public void revokeInvite(@PathVariable Long id, @PathVariable Long inviteId) {
        service.revokeInvite(id, inviteId);
    }

    /** Kulup ici denetim kaydi (club_audit; kulup yetkililerinin gordugu ayni liste), imecli. */
    @GetMapping("/{id}/club-audit")
    public CursorPage<AuditView> clubAudit(@PathVariable Long id, @RequestParam(required = false) Long cursor,
                                           @RequestParam(defaultValue = "20") int size) {
        limit();
        return clubAudit.page(ClubAdminService.actor(), id, cursor, size);
    }

    private static String reason(ReasonRequest body) {
        String h = AuditContext.currentReason();
        return h != null ? h : body == null ? null : body.reason();
    }

    private void limit() {
        Long id = ClubAdminService.actorId();
        limiter.check("adminclubs:" + (id == null ? "basic" : id), READ_PER_MINUTE, Duration.ofMinutes(1));
    }
}
