package edu.bingol.backend.messaging;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

import edu.bingol.backend.messaging.dto.MessagingDtos.MessageView;
import edu.bingol.backend.messaging.media.AttachmentView;
import java.util.List;
import org.junit.jupiter.api.Test;

/** Aciklamasiz medya push onizlemesi: tur belirleme (metin/tek gosterimlik/paylasim ise null). */
class MediaPreviewKindTest {

    private static AttachmentView att(String kind, boolean viewOnce) {
        return new AttachmentView(5L, kind, 800, 600, 1234, "image/jpeg", false, "/u", null, viewOnce, false);
    }

    private static Message msg(String body) {
        Message m = new Message();
        m.setBody(body);
        return m;
    }

    private static MessageView view(List<AttachmentView> a) {
        MessageView v = org.mockito.Mockito.mock(MessageView.class);
        org.mockito.Mockito.when(v.attachments()).thenReturn(a);
        return v;
    }

    @Test
    void captionlessPhotoAndVideoGetKinds() {
        assertEquals("PHOTO", MessageService.mediaKindOf(msg(""), view(List.of(att("IMAGE", false)))));
        assertEquals("VIDEO", MessageService.mediaKindOf(msg(""), view(List.of(att("VIDEO", false)))));
        assertEquals("PHOTO", MessageService.mediaKindOf(msg(""), view(List.of(att("VIDEO", false), att("IMAGE", false)))));
    }

    @Test
    void captionOrViewOnceOrNoMediaHasNoKind() {
        assertNull(MessageService.mediaKindOf(msg("tatil"), view(List.of(att("IMAGE", false)))));
        assertNull(MessageService.mediaKindOf(msg(""), view(List.of(att("IMAGE", true)))));
        assertNull(MessageService.mediaKindOf(msg(""), view(List.of())));
    }

    @Test
    void captionlessVoiceMessageGetsAudioKindNotPhoto() {
        assertEquals("AUDIO", MessageService.mediaKindOf(msg(""), view(List.of(att("AUDIO", false)))));
    }
}
