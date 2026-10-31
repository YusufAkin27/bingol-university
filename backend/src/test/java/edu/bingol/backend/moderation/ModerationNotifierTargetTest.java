package edu.bingol.backend.moderation;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.messaging.Message;
import edu.bingol.backend.messaging.MessageRepository;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.user.UserRepository;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

/** A13-05: MESSAGE moderasyon bildirimi mesaj kimligini sohbet kimligi gibi gondermemeli. */
class ModerationNotifierTargetTest {

    private final NotificationService notifications = mock(NotificationService.class);
    private final MessageRepository messages = mock(MessageRepository.class);
    private final ModerationNotifier notifier = new ModerationNotifier(notifications, mock(I18n.class),
            mock(UserRepository.class));

    @SuppressWarnings("unchecked")
    private Map<String, String> sentData() {
        ArgumentCaptor<Map<String, String>> c = ArgumentCaptor.forClass(Map.class);
        verify(notifications).sendTemplated(eq(7L), eq(NotificationType.SYSTEM), anyString(), c.capture(),
                any(String[].class));
        return c.getValue();
    }

    @Test
    void messageTargetCarriesConversationIdAndNoRawMessageTarget() {
        Message m = new Message();
        m.setConversationId(55L);
        when(messages.findById(900L)).thenReturn(Optional.of(m));
        notifier.setMessages(messages);

        notifier.removed(7L, ReportTargetType.MESSAGE, 900L, "x");

        Map<String, String> d = sentData();
        assertEquals("55", d.get("conversationId"));
        assertEquals("900", d.get("messageId"));
        assertFalse(d.containsKey("targetType")); // mesaj kimligi hedef kimligi olarak GITMEZ
        assertFalse(d.containsKey("targetId"));
    }

    @Test
    void messageTargetWithoutConversationSendsNoTarget() {
        when(messages.findById(901L)).thenReturn(Optional.empty());
        notifier.setMessages(messages);

        notifier.restored(7L, ReportTargetType.MESSAGE, 901L);

        assertTrue(sentData().isEmpty());
    }

    @Test
    void otherTargetsKeepTypeAndId() {
        notifier.autoHidden(7L, ReportTargetType.POST, 12L);

        Map<String, String> d = sentData();
        assertEquals("POST", d.get("targetType"));
        assertEquals("12", d.get("targetId"));
    }
}
