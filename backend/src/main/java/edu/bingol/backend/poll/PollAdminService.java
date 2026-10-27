package edu.bingol.backend.poll;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.poll.PollDtos.AdminPollPage;
import edu.bingol.backend.poll.PollDtos.AdminPollRow;
import edu.bingol.backend.poll.PollDtos.AdminStats;
import edu.bingol.backend.poll.PollDtos.BulkResult;
import edu.bingol.backend.poll.PollDtos.PollView;
import jakarta.persistence.criteria.Predicate;
import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Yonetici islemleri (liste, istatistik, toplu islem) ve kimliksiz sonuc CSV'si. */
@Service
public class PollAdminService {

    static final int MAX_BULK = 100;

    private final PollRepository polls;
    private final PollOptionRepository options;
    private final PollService service;
    private final PollViewAssembler assembler;
    private final PollAccess access;
    private final Clock clock;

    public PollAdminService(PollRepository polls, PollOptionRepository options, PollService service,
                            PollViewAssembler assembler, PollAccess access, Clock clock) {
        this.polls = polls;
        this.options = options;
        this.service = service;
        this.assembler = assembler;
        this.access = access;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public AdminPollPage list(String status, String scope, String q, int page, int size) {
        Poll.Status st = parse(Poll.Status.class, status);
        Poll.Scope sc = parse(Poll.Scope.class, scope);
        String like = q == null || q.isBlank() ? null
                : "%" + q.trim().toLowerCase(Locale.ROOT).replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_") + "%";
        Specification<Poll> spec = (root, query, cb) -> {
            List<Predicate> ps = new ArrayList<>();
            if (st != null) {
                ps.add(cb.equal(root.get("status"), st));
            }
            if (sc != null) {
                ps.add(cb.equal(root.get("scope"), sc));
            }
            if (like != null) {
                ps.add(cb.like(cb.lower(root.get("title")), like, '\\'));
            }
            return cb.and(ps.toArray(new Predicate[0]));
        };
        int s = Math.min(Math.max(size, 1), 100);
        Page<Poll> res = polls.findAll(spec, PageRequest.of(Math.max(page, 0), s, Sort.by(Sort.Direction.DESC, "id")));
        Instant now = clock.instant();
        List<AdminPollRow> rows = res.getContent().stream().map(p -> new AdminPollRow(p.getId(), p.getTitle(),
                p.getType().name(), p.getScope().name(), p.getCommunityId(), p.getStatus().name(),
                PollViewAssembler.state(p, now), p.isAnonymous(), p.getVoterCount(), PollViewAssembler.at(p.getOpensAt()),
                PollViewAssembler.at(p.getClosesAt()), PollViewAssembler.at(p.getCreatedAt()), p.getCreatedBy())).toList();
        return new AdminPollPage(rows, res.getNumber(), s, res.getTotalElements());
    }

    @Transactional(readOnly = true)
    public PollView get(Actor admin, Long id) {
        Poll p = polls.findById(id).orElseThrow(PollService::notFound);
        return assembler.view(p, admin, true);
    }

    @Transactional(readOnly = true)
    public AdminStats stats() {
        Map<String, Long> byScope = new LinkedHashMap<>();
        for (Poll.Scope s : Poll.Scope.values()) {
            byScope.put(s.name(), polls.countByScope(s));
        }
        long total = polls.count();
        Double avg = null;
        double sum = 0;
        int n = 0;
        for (Poll p : polls.findAll(PageRequest.of(0, 200, Sort.by(Sort.Direction.DESC, "id"))).getContent()) {
            if (p.getStatus() == Poll.Status.DRAFT) {
                continue;
            }
            Integer eligible = access.eligibleCount(p);
            if (eligible != null && eligible > 0) {
                sum += Math.min(100.0, p.getVoterCount() * 100.0 / eligible);
                n++;
            }
        }
        if (n > 0) {
            avg = PollViewAssembler.round1(sum / n);
        }
        return new AdminStats(total, polls.countByStatus(Poll.Status.OPEN), polls.countByStatus(Poll.Status.CLOSED),
                polls.countByStatus(Poll.Status.DRAFT), polls.countByStatus(Poll.Status.CANCELLED), polls.totalVoters(),
                byScope, avg);
    }

    public BulkResult bulk(Actor admin, List<Long> ids, String action) {
        if (ids == null || ids.isEmpty() || ids.size() > MAX_BULK || action == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "POLL_INVALID", "Anket bilgileri geçersiz.", "ids");
        }
        String a = action.trim().toUpperCase(Locale.ROOT);
        if (!List.of("CLOSE", "CANCEL", "DELETE").contains(a)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "POLL_INVALID", "Anket bilgileri geçersiz.", "action");
        }
        int done = 0;
        int skipped = 0;
        for (Long id : ids) {
            try {
                switch (a) {
                    case "CLOSE" -> service.close(admin, id);
                    case "CANCEL" -> service.cancel(id);
                    default -> service.delete(admin, id);
                }
                done++;
            } catch (RuntimeException e) {
                skipped++;
            }
        }
        return new BulkResult(done, skipped);
    }

    /** Olusturan / kulup yoneticisi / ADMIN icin sonuc CSV'si. */
    @Transactional(readOnly = true)
    public String csvFor(Actor actor, Long id) {
        Poll p = polls.findById(id).orElseThrow(PollService::notFound);
        if (!access.canManage(p, actor)) {
            throw PollService.notFound();
        }
        return csv(p);
    }

    @Transactional(readOnly = true)
    public String csv(Long id) {
        return csv(polls.findById(id).orElseThrow(PollService::notFound));
    }

    String csv(Poll p) {
        StringBuilder sb = new StringBuilder("optionId,text,count,percent,score\r\n");
        for (PollOption o : options.findByPollIdOrderByPositionAsc(p.getId())) {
            sb.append(o.getId()).append(',').append(cell(o.getText())).append(',').append(o.getVoteCount()).append(',')
                    .append(PollViewAssembler.percent(o.getVoteCount(), p.getVoterCount())).append(',')
                    .append(p.getType() == Poll.Type.RANKED ? String.valueOf(o.getRankScore()) : "").append("\r\n");
        }
        return sb.toString();
    }

    /** CSV enjeksiyonuna karsi: formul baslangici ' ile etkisizlestirilir, tirnak/virgul/satir sonu kacirilir. */
    static String cell(String v) {
        if (v == null) {
            return "";
        }
        String s = v;
        if (!s.isEmpty() && "=+-@\t\r".indexOf(s.charAt(0)) >= 0) {
            s = "'" + s;
        }
        if (s.contains(",") || s.contains("\"") || s.contains("\n") || s.contains("\r")) {
            s = "\"" + s.replace("\"", "\"\"") + "\"";
        }
        return s;
    }

    private static <E extends Enum<E>> E parse(Class<E> type, String raw) {
        if (raw == null || raw.isBlank()) {
            return null;
        }
        try {
            return Enum.valueOf(type, raw.trim().toUpperCase(Locale.ROOT));
        } catch (IllegalArgumentException e) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "POLL_INVALID", "Anket bilgileri geçersiz.", raw);
        }
    }
}
