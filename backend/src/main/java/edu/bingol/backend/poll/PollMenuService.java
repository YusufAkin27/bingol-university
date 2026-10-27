package edu.bingol.backend.poll;

import edu.bingol.backend.community.Actor;
import edu.bingol.backend.menu.MenuRepository;
import edu.bingol.backend.poll.PollDtos.PollView;
import java.time.Clock;
import java.time.LocalDate;
import java.util.Optional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;

/** "Bugunku menuyu puanla" anketi: yemek listesi olan gun icin tembel/zamanlanmis olusturulur (gun basina tek). */
@Service
public class PollMenuService {

    private static final Logger log = LoggerFactory.getLogger(PollMenuService.class);

    private final MenuRepository menus;
    private final PollRepository polls;
    private final PollService service;
    private final PollViewAssembler assembler;
    private final Clock clock;

    public PollMenuService(MenuRepository menus, PollRepository polls, PollService service, PollViewAssembler assembler,
                           Clock clock) {
        this.menus = menus;
        this.polls = polls;
        this.service = service;
        this.assembler = assembler;
        this.clock = clock;
    }

    /** Bugunun menu anketi; yemek listesi yoksa bos. */
    public Optional<PollView> today(Actor actor) {
        return ensure(LocalDate.now(clock.withZone(PollAccess.ZONE))).map(p -> assembler.view(p, actor, false));
    }

    /** Zamanlayici icin: bugunun anketini garantiler (hata yutulur). */
    public void ensureToday() {
        try {
            ensure(LocalDate.now(clock.withZone(PollAccess.ZONE)));
        } catch (RuntimeException e) {
            log.warn("Menu anketi olusturulamadi: {}", e.toString());
        }
    }

    private Optional<Poll> ensure(LocalDate day) {
        if (menus.findByMenuDate(day).isEmpty()) {
            return Optional.empty();
        }
        Optional<Poll> existing = polls.findByMenuDate(day);
        if (existing.isPresent()) {
            return existing;
        }
        try {
            return Optional.of(service.createMenuPoll(day));
        } catch (DataIntegrityViolationException e) {
            return polls.findByMenuDate(day); // baska istek ayni anda olusturdu
        }
    }
}
