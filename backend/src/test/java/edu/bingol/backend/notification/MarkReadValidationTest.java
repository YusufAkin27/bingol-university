package edu.bingol.backend.notification;

import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import edu.bingol.backend.common.RateLimiter;
import java.util.List;
import java.util.stream.Collectors;
import java.util.stream.LongStream;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.bind.MethodArgumentNotValidException;

/** QA: POST /api/notifications/read govdesi dogrulanmali (ids en fazla 200); eskiden @Valid yoktu, IN listesi sinirsizdi. */
class MarkReadValidationTest {

    private final NotificationInboxService inbox = mock(NotificationInboxService.class);
    private MockMvc mvc;

    @BeforeEach
    void setUp() {
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(7L, null, List.of()));
        mvc = MockMvcBuilders.standaloneSetup(new NotificationController(inbox, null, null, mock(RateLimiter.class))).build();
    }

    @AfterEach
    void tearDown() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void tooManyIdsRejected() {
        String ids = LongStream.rangeClosed(1, 201).mapToObj(Long::toString).collect(Collectors.joining(","));
        Exception e = org.junit.jupiter.api.Assertions.assertThrows(Exception.class, () -> mvc.perform(
                post("/api/notifications/read").contentType(MediaType.APPLICATION_JSON).content("{\"ids\":[" + ids + "]}")));
        Throwable c = e.getCause() != null ? e.getCause() : e;
        assertTrue(c instanceof MethodArgumentNotValidException, c.toString());
        verify(inbox, never()).markRead(any(), any(), org.mockito.ArgumentMatchers.anyBoolean(), any());
    }

    @Test
    void twoHundredIdsAccepted() throws Exception {
        String ids = LongStream.rangeClosed(1, 200).mapToObj(Long::toString).collect(Collectors.joining(","));
        mvc.perform(post("/api/notifications/read").contentType(MediaType.APPLICATION_JSON).content("{\"ids\":[" + ids + "]}"))
                .andExpect(status().isNoContent());
    }
}
