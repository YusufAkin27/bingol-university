package edu.bingol.backend.admin;

import edu.bingol.backend.admin.AdminDtos.AcceptanceStat;
import edu.bingol.backend.admin.AdminDtos.LegalVersion;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.legal.DocumentRepository;
import edu.bingol.backend.legal.LegalType;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** Sozlesme yonetimi eksikleri: tum surum/dil listesi ve guncel surum kabul orani. */
@RestController
@RequestMapping("/api/admin/legal")
public class AdminLegalController {

    private final DocumentRepository docs;
    private final NamedParameterJdbcTemplate jdbc;

    public AdminLegalController(DocumentRepository docs, NamedParameterJdbcTemplate jdbc) {
        this.docs = docs;
        this.jdbc = jdbc;
    }

    /** Tum diller ve surumler, en yeni once (icerik dahil). */
    @GetMapping("/{type}/versions")
    public List<LegalVersion> versions(@PathVariable String type) {
        LegalType t = LegalType.parse(type);
        if (t == null) {
            throw new ApiException(HttpStatus.NOT_FOUND, "LEGAL_NOT_FOUND", "Belge bulunamadı.");
        }
        return docs.findByTypeOrderByVersionDescLangAsc(t).stream()
                .map(d -> new LegalVersion(d.getVersion(), d.getLang(), d.getTitle(), d.getContent(),
                        d.isRequireReaccept(), d.isActive(), d.getPublishedAt().toString()))
                .toList();
    }

    /** Guncel (aktif tr) surum basina kabul eden aktif kullanici sayisi ve aktif kullanici toplami. */
    @GetMapping("/acceptance-stats")
    public List<AcceptanceStat> acceptanceStats() {
        Long total = jdbc.queryForObject("SELECT count(*) FROM app_user WHERE status = 'ACTIVE' AND email_verified",
                Map.of(), Long.class);
        long totalUsers = total == null ? 0 : total;
        return jdbc.query("SELECT d.type AS type, d.version AS version, "
                + "(SELECT count(*) FROM legal_acceptance a JOIN app_user u ON u.id = a.user_id "
                + "WHERE a.doc_type = d.type AND a.version = d.version AND u.status = 'ACTIVE' AND u.email_verified) AS accepted "
                + "FROM legal_document d WHERE d.active AND d.lang = 'tr' ORDER BY d.type", Map.of(),
                (rs, i) -> new AcceptanceStat(rs.getString("type"), rs.getInt("version"), rs.getLong("accepted"),
                        totalUsers));
    }
}
