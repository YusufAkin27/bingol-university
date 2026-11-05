package edu.bingol.backend.forum.moderation;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;

import edu.bingol.backend.common.ApiException;
import org.junit.jupiter.api.Test;
import org.springframework.context.ApplicationContext;

/** B yorum durum servisi yoksa kopru 503 verir (kayit yazilmaz). */
class ForumCommentStatesImplTest {

    @Test
    void missingCommentStateServiceGives503() {
        ForumCommentStatesImpl impl = new ForumCommentStatesImpl(mock(ApplicationContext.class));
        assertThatThrownBy(() -> impl.remove(1L, "x")).isInstanceOfSatisfying(ApiException.class,
                e -> org.assertj.core.api.Assertions.assertThat(e.status().value()).isEqualTo(503));
    }
}
