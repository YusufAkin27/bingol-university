package edu.bingol.backend.messaging.ws;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.messaging.MessageService;
import edu.bingol.backend.messaging.dto.MessagingDtos.ChatRead;
import edu.bingol.backend.messaging.dto.MessagingDtos.ChatSend;
import edu.bingol.backend.messaging.dto.MessagingDtos.ChatTyping;
import edu.bingol.backend.messaging.dto.MessagingDtos.ErrorFrame;
import java.security.Principal;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.messaging.handler.annotation.MessageExceptionHandler;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.messaging.simp.annotation.SendToUser;
import org.springframework.stereotype.Controller;

/**
 * STOMP komutlari (/app/chat.*). Gonderen daima kimlikten (Principal) alinir, yukten degil.
 * Hatalar kullaniciya /user/queue/errors ile `{code, message, clientId?}` olarak gider; baglanti kapanmaz.
 */
@Controller
public class ChatWsController {

    private static final Logger log = LoggerFactory.getLogger(ChatWsController.class);

    private final MessageService messages;
    private final SimpMessagingTemplate template;

    public ChatWsController(MessageService messages, SimpMessagingTemplate template) {
        this.messages = messages;
        this.template = template;
    }

    /** Teslim ve "ack": kaydedilen mesaj gondericinin /user/queue/messages kuyruguna da (clientId ile) duser. */
    @MessageMapping("/chat.send")
    public void send(@Payload ChatSend p, Principal principal) {
        Long uid = userId(principal);
        try {
            messages.send(uid, p.conversationId(), p.text(), p.clientId(), p.replyToMessageId());
        } catch (ApiException e) {
            template.convertAndSendToUser(principal.getName(), "/queue/errors",
                    new ErrorFrame(e.code(), e.getMessage(), p.clientId()));
        }
    }

    @MessageMapping("/chat.read")
    public void read(@Payload ChatRead p, Principal principal) {
        messages.markRead(userId(principal), p.conversationId(), p.lastMessageId());
    }

    @MessageMapping("/chat.typing")
    public void typing(@Payload ChatTyping p, Principal principal) {
        messages.typing(userId(principal), p.conversationId());
    }

    @MessageExceptionHandler(ApiException.class)
    @SendToUser(destinations = "/queue/errors", broadcast = false)
    public ErrorFrame apiError(ApiException e) {
        return new ErrorFrame(e.code(), e.getMessage(), null);
    }

    @MessageExceptionHandler(Exception.class)
    @SendToUser(destinations = "/queue/errors", broadcast = false)
    public ErrorFrame unexpected(Exception e) {
        log.warn("STOMP komutu islenemedi: {}", e.toString());
        return new ErrorFrame("BAD_REQUEST", "İstek işlenemedi.", null);
    }

    private static Long userId(Principal principal) {
        try {
            return Long.valueOf(principal.getName());
        } catch (NullPointerException | NumberFormatException e) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "UNAUTHORIZED", "Giriş gerekli.");
        }
    }
}
