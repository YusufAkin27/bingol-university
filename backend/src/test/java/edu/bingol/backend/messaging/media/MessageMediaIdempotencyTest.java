package edu.bingol.backend.messaging.media;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.IdempotentCreate;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.moderation.ReportService;
import java.util.List;
import javax.sql.DataSource;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.jdbc.datasource.embedded.EmbeddedDatabase;
import org.springframework.jdbc.datasource.embedded.EmbeddedDatabaseBuilder;
import org.springframework.jdbc.datasource.embedded.EmbeddedDatabaseType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

/** G10: sohbet medya yukleme ucu Idempotency-Key ile yeniden denemede tek ek uretir (arka plan aktarimi). */
class MessageMediaIdempotencyTest {

    private static EmbeddedDatabase db;
    private static IdempotentCreate idem;

    @BeforeAll
    static void setUp() {
        db = new EmbeddedDatabaseBuilder().setType(EmbeddedDatabaseType.H2).setName("chatmedia_idem").build();
        JdbcTemplate jdbc = new JdbcTemplate((DataSource) db);
        jdbc.execute("CREATE TABLE idempotency_record (id BIGINT AUTO_INCREMENT PRIMARY KEY, user_id BIGINT NOT NULL, "
                + "scope VARCHAR(40) NOT NULL, idem_key VARCHAR(64) NOT NULL, resource_id BIGINT NOT NULL, "
                + "created_at TIMESTAMP WITH TIME ZONE DEFAULT now(), CONSTRAINT uq UNIQUE (user_id, scope, idem_key))");
        idem = new IdempotentCreate(jdbc, new DataSourceTransactionManager((DataSource) db));
    }

    @AfterAll
    static void tearDown() {
        db.shutdown();
    }

    @AfterEach
    void clear() {
        SecurityContextHolder.clearContext();
    }

    private static MessageAttachment attachment(long id) {
        MessageAttachment a = new MessageAttachment();
        a.setId(id);
        a.setConversationId(5L);
        a.setUploaderId(7L);
        a.setContentType("image/jpeg");
        a.setWidth(10);
        a.setHeight(10);
        a.setBytes(100);
        return a;
    }

    @Test
    void retryWithSameKeyReturnsSameAttachmentAndUploadsOnce() {
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(7L, null, List.of()));
        MessageAttachmentService service = mock(MessageAttachmentService.class);
        MessageMediaController c = new MessageMediaController(service, mock(ReportService.class), mock(RateLimiter.class));
        c.setIdem(idem);
        MockMultipartFile file = new MockMultipartFile("file", "a.jpg", "image/jpeg", new byte[] {1, 2, 3});
        AttachmentView first = AttachmentView.of(attachment(41L));
        when(service.upload(eq(7L), eq(5L), any(), any())).thenReturn(first);
        when(service.require(7L, 5L, 41L)).thenReturn(attachment(41L));

        AttachmentView a = c.upload(5L, file, null, "job-abcdef12");
        AttachmentView b = c.upload(5L, file, null, "job-abcdef12");

        assertEquals(41L, a.id());
        assertEquals(a.id(), b.id());
        verify(service, times(1)).upload(eq(7L), eq(5L), any(), any());
    }

    @Test
    void withoutKeyEveryCallUploads() {
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(7L, null, List.of()));
        MessageAttachmentService service = mock(MessageAttachmentService.class);
        MessageMediaController c = new MessageMediaController(service, mock(ReportService.class), mock(RateLimiter.class));
        c.setIdem(idem);
        MockMultipartFile file = new MockMultipartFile("file", "a.jpg", "image/jpeg", new byte[] {1});
        when(service.upload(eq(7L), eq(5L), any(), any())).thenReturn(AttachmentView.of(attachment(50L)));
        c.upload(5L, file, null, null);
        c.upload(5L, file, null, null);
        verify(service, times(2)).upload(eq(7L), eq(5L), any(), any());
    }
}
