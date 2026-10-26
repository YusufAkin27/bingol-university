package edu.bingol.backend.support.ticket;

import edu.bingol.backend.common.ClientIp;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.support.ticket.PublicSupportDtos.CodeSent;
import edu.bingol.backend.support.ticket.PublicSupportDtos.SubmitRequest;
import edu.bingol.backend.support.ticket.PublicSupportDtos.TrackReplyRequest;
import edu.bingol.backend.support.ticket.PublicSupportDtos.TrackRequest;
import edu.bingol.backend.support.ticket.PublicSupportDtos.Verified;
import edu.bingol.backend.support.ticket.PublicSupportDtos.VerifyRequest;
import edu.bingol.backend.support.ticket.TicketDtos.TicketDetail;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Herkese acik destek talebi uclari (kimlik gerektirmez; hiz siniri servis katmaninda). */
@RestController
@RequestMapping("/api/public/support")
public class PublicSupportController {

    private final PublicSupportService service;
    private final ClientIp clientIp;

    public PublicSupportController(PublicSupportService service, ClientIp clientIp) {
        this.service = service;
        this.clientIp = clientIp;
    }

    @PostMapping("/tickets")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public CodeSent submit(@Valid @RequestBody SubmitRequest r, HttpServletRequest req) {
        return service.submit(r, clientIp.of(req), Lang.of(LocaleContextHolder.getLocale()));
    }

    @PostMapping("/tickets/verify")
    public Verified verify(@Valid @RequestBody VerifyRequest r, HttpServletRequest req) {
        return service.verify(r.email(), r.code(), clientIp.of(req));
    }

    /** Anahtar govdede (URL/log'a dusmesin diye POST). */
    @PostMapping("/track")
    public TicketDetail track(@Valid @RequestBody TrackRequest r, HttpServletRequest req) {
        return service.track(r.token(), clientIp.of(req));
    }

    @PostMapping("/track/messages")
    public TicketDetail reply(@Valid @RequestBody TrackReplyRequest r, HttpServletRequest req) {
        return service.userReply(r.token(), r.text(), clientIp.of(req));
    }
}
