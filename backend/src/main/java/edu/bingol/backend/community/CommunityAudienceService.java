package edu.bingol.backend.community;

import edu.bingol.backend.catalog.CatalogService;
import edu.bingol.backend.common.ApiException;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Kulup onerisi hedef kitlesi (fakulte/bolum). Yalniz siralama/oneri: gorunurluk ve katilim kurallarini
 * etkilemez. Degerler katalogdaki kanonik (Turkce) adlardir.
 */
@Service
public class CommunityAudienceService {

    public static final int MAX_TARGETS = 12;
    private static final int POOL = 500;

    private final CommunityAudienceRepository repo;
    private final CatalogService catalog;

    public CommunityAudienceService(CommunityAudienceRepository repo, CatalogService catalog) {
        this.repo = repo;
        this.catalog = catalog;
    }

    public record Targets(List<String> faculties, List<String> departments) {
        public static final Targets NONE = new Targets(List.of(), List.of());
    }

    /** Tekillestirir, bosluk kirpar; katalog disi ad 400 ACADEMIC_INVALID. */
    List<String> clean(List<String> raw, boolean faculty) {
        LinkedHashSet<String> out = new LinkedHashSet<>();
        if (raw != null) {
            for (String s : raw) {
                if (s != null && !s.isBlank()) {
                    out.add(s.trim());
                }
            }
        }
        if (out.size() > MAX_TARGETS) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "En fazla 12 hedef seçilebilir.");
        }
        for (String s : out) {
            boolean ok = faculty ? catalog.isValidFaculty(s)
                    : catalog.catalog().faculties().stream()
                            .anyMatch(f -> f.departments().stream().anyMatch(d -> d.name().equals(s)));
            if (!ok) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "ACADEMIC_INVALID",
                        "Fakülte, bölüm veya sınıf bilgisi geçersiz.");
            }
        }
        return new ArrayList<>(out);
    }

    /** Liste null = o tur icin dokunma; bos liste = temizle. Ikisi de null ise hicbir sey yapmaz. */
    @Transactional
    public void replace(Long communityId, List<String> faculties, List<String> departments) {
        if (faculties == null && departments == null) {
            return;
        }
        List<String> f = faculties == null ? null : clean(faculties, true);
        List<String> d = departments == null ? null : clean(departments, false);
        Targets cur = of(List.of(communityId)).getOrDefault(communityId, Targets.NONE);
        List<String> nf = f == null ? cur.faculties() : f;
        List<String> nd = d == null ? cur.departments() : d;
        repo.deleteAllFor(communityId);
        repo.flush();
        for (String s : nf) {
            repo.save(new CommunityAudience(communityId, CommunityAudience.FACULTY, s));
        }
        for (String s : nd) {
            repo.save(new CommunityAudience(communityId, CommunityAudience.DEPARTMENT, s));
        }
    }

    @Transactional(readOnly = true)
    public Map<Long, Targets> of(Collection<Long> communityIds) {
        if (communityIds.isEmpty()) {
            return Map.of();
        }
        Map<Long, List<String>> fs = new HashMap<>();
        Map<Long, List<String>> ds = new HashMap<>();
        for (CommunityAudience a : repo.findByCommunityIdIn(communityIds)) {
            (CommunityAudience.FACULTY.equals(a.getKind()) ? fs : ds)
                    .computeIfAbsent(a.getCommunityId(), k -> new ArrayList<>()).add(a.getTargetValue());
        }
        Map<Long, Targets> out = new HashMap<>();
        for (Long id : communityIds) {
            out.put(id, new Targets(fs.getOrDefault(id, List.of()), ds.getOrDefault(id, List.of())));
        }
        return out;
    }

    /**
     * Kullanicinin fakulte/bolumune uyan kulup kimlikleri, puana gore azalan (bolum 2, fakulte 1; esitlikte
     * yeni kulup once). Profili bos kullanicida bos liste.
     */
    @Transactional(readOnly = true)
    public List<Long> rankedFor(String faculty, String department) {
        boolean noF = faculty == null || faculty.isBlank();
        boolean noD = department == null || department.isBlank();
        if (noF && noD) {
            return List.of();
        }
        Map<Long, Integer> score = new HashMap<>();
        for (CommunityAudience a : repo.matching(noF ? "" : faculty, noD ? "" : department, PageRequest.of(0, POOL))) {
            score.merge(a.getCommunityId(), CommunityAudience.DEPARTMENT.equals(a.getKind()) ? 2 : 1, Integer::sum);
        }
        return score.entrySet().stream()
                .sorted((x, y) -> !y.getValue().equals(x.getValue()) ? y.getValue() - x.getValue()
                        : Long.compare(y.getKey(), x.getKey()))
                .map(Map.Entry::getKey).toList();
    }
}
