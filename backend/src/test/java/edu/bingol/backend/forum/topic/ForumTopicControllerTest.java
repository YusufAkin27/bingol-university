package edu.bingol.backend.forum.topic;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.forum.category.ForumCategoryController;
import edu.bingol.backend.forum.category.ForumCategoryDtos.CategoryView;
import edu.bingol.backend.forum.category.ForumCategoryService;
import edu.bingol.backend.forum.media.ForumMediaController;
import edu.bingol.backend.forum.media.ForumMediaService;
import edu.bingol.backend.forum.topic.ForumTopicDtos.CreateTopicRequest;
import edu.bingol.backend.forum.topic.ForumTopicDtos.FollowState;
import edu.bingol.backend.forum.topic.ForumTopicDtos.LikeState;
import edu.bingol.backend.forum.topic.ForumTopicDtos.NotificationsState;
import edu.bingol.backend.forum.topic.ForumTopicDtos.SaveState;
import edu.bingol.backend.forum.topic.dto.Author;
import edu.bingol.backend.forum.topic.dto.CategoryRef;
import edu.bingol.backend.forum.topic.dto.ForumPage;
import edu.bingol.backend.forum.topic.dto.TopicSummary;
import edu.bingol.backend.forum.topic.dto.TopicView;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

/** HTTP eslemesi: yol/yontem, durum kodu, JSON bicimi, Idempotency-Key, hiz siniri cagrisi (servisler sahte). */
class ForumTopicControllerTest {

    final ForumTopicService service = mock(ForumTopicService.class);
    final ForumFeedService feed = mock(ForumFeedService.class);
    final ForumReactionService reactions = mock(ForumReactionService.class);
    final ForumCategoryService categories = mock(ForumCategoryService.class);
    final ForumMediaService media = mock(ForumMediaService.class);
    final RateLimiter limiter = mock(RateLimiter.class);
    MockMvc mvc;

    @BeforeEach
    void setUp() {
        mvc = MockMvcBuilders.standaloneSetup(new ForumTopicController(service, feed, reactions, limiter),
                new ForumCategoryController(categories, limiter), new ForumMediaController(media, limiter)).build();
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(42L, null, List.of()));
    }

    @AfterEach
    void clear() {
        SecurityContextHolder.clearContext();
    }

    private static TopicView view() {
        return TopicView.of(summary(), "tam govde", List.of(), null, true, true, true);
    }

    private static TopicSummary summary() {
        return new TopicSummary(7L, "Baslik", "onizleme", new CategoryRef(1L, "Gundem", "gundem"),
                Author.anonymous("Anonim #1"), Instant.parse("2026-11-05T10:00:00Z"), null, 2, 3, false, false, false,
                null, 0, false, false, false, true, false, "ACTIVE");
    }

    @Test
    void createReturns201WithJsonBodyPassesIdempotencyKeyAndRateLimits() throws Exception {
        when(service.create(eq(42L), any(), anyString())).thenReturn(view());
        mvc.perform(post("/api/forum/topics").header("Idempotency-Key", "abcdefgh-1")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"T\",\"body\":\"B\",\"categoryId\":1,\"anonymous\":true,\"imageIds\":[3,4],"
                                + "\"poll\":{\"question\":\"Q?\",\"options\":[\"a\",\"b\"],\"endsAt\":\"2030-01-01T00:00:00Z\","
                                + "\"allowChangeVote\":true}}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(7))
                .andExpect(jsonPath("$.body").value("tam govde"))
                .andExpect(jsonPath("$.author.anonymous").value(true))
                .andExpect(jsonPath("$.author.userId").doesNotExist())
                .andExpect(jsonPath("$.author.displayName").value("Anonim #1"))
                .andExpect(jsonPath("$.category.slug").value("gundem"))
                .andExpect(jsonPath("$.canEdit").value(true))
                .andExpect(jsonPath("$.images").isArray());
        ArgumentCaptor<CreateTopicRequest> cap = ArgumentCaptor.forClass(CreateTopicRequest.class);
        verify(service).create(eq(42L), cap.capture(), eq("abcdefgh-1"));
        CreateTopicRequest r = cap.getValue();
        org.junit.jupiter.api.Assertions.assertEquals(List.of(3L, 4L), r.imageIds());
        org.junit.jupiter.api.Assertions.assertTrue(r.anonymous());
        org.junit.jupiter.api.Assertions.assertEquals(List.of("a", "b"), r.poll().options());
        org.junit.jupiter.api.Assertions.assertTrue(r.poll().allowChangeVote());
        verify(limiter).check("forum:topic:create:42", 5, Duration.ofHours(1));
    }

    @Test
    void listParsesSortCategoryCursorAndSize() throws Exception {
        when(feed.feed(eq(42L), eq(ForumFeedService.Sort.POPULAR), eq(3L), eq("cur"), eq(10)))
                .thenReturn(new ForumPage<>(List.of(summary()), "next"));
        mvc.perform(get("/api/forum/topics").param("sort", "popular").param("categoryId", "3").param("cursor", "cur")
                        .param("size", "10"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].id").value(7))
                .andExpect(jsonPath("$.items[0].bodyPreview").value("onizleme"))
                .andExpect(jsonPath("$.items[0].likeCount").value(2))
                .andExpect(jsonPath("$.items[0].thumbnail").doesNotExist())
                .andExpect(jsonPath("$.nextCursor").value("next"));
        when(feed.feed(eq(42L), eq(ForumFeedService.Sort.FOR_YOU), isNull(), isNull(), isNull()))
                .thenReturn(new ForumPage<>(List.of(), null));
        mvc.perform(get("/api/forum/topics")).andExpect(status().isOk()).andExpect(jsonPath("$.items").isEmpty())
                .andExpect(jsonPath("$.nextCursor").doesNotExist());
    }

    @Test
    void reactionEndpointsMapToServiceAndReturnStates() throws Exception {
        when(reactions.like(42L, 7L)).thenReturn(new LikeState(true, 5));
        when(reactions.unlike(42L, 7L)).thenReturn(new LikeState(false, 4));
        when(reactions.save(42L, 7L)).thenReturn(new SaveState(true));
        when(reactions.unsave(42L, 7L)).thenReturn(new SaveState(false));
        when(reactions.follow(42L, 7L)).thenReturn(new FollowState(true));
        when(reactions.unfollow(42L, 7L)).thenReturn(new FollowState(false));
        when(reactions.setNotifications(42L, 7L, false)).thenReturn(new NotificationsState(false));
        mvc.perform(put("/api/forum/topics/7/like")).andExpect(status().isOk())
                .andExpect(jsonPath("$.liked").value(true)).andExpect(jsonPath("$.likeCount").value(5));
        mvc.perform(delete("/api/forum/topics/7/like")).andExpect(jsonPath("$.liked").value(false))
                .andExpect(jsonPath("$.likeCount").value(4));
        mvc.perform(put("/api/forum/topics/7/bookmark")).andExpect(jsonPath("$.saved").value(true));
        mvc.perform(delete("/api/forum/topics/7/bookmark")).andExpect(jsonPath("$.saved").value(false));
        mvc.perform(put("/api/forum/topics/7/follow")).andExpect(jsonPath("$.following").value(true));
        mvc.perform(delete("/api/forum/topics/7/follow")).andExpect(jsonPath("$.following").value(false));
        mvc.perform(put("/api/forum/topics/7/notifications").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"enabled\":false}"))
                .andExpect(jsonPath("$.enabled").value(false));
    }

    @Test
    void getPatchDeleteAndWriteLimits() throws Exception {
        when(service.get(42L, 7L)).thenReturn(view());
        when(service.update(eq(42L), eq(7L), any())).thenReturn(view());
        mvc.perform(get("/api/forum/topics/7")).andExpect(status().isOk()).andExpect(jsonPath("$.mine").value(true));
        mvc.perform(patch("/api/forum/topics/7").contentType(MediaType.APPLICATION_JSON).content("{\"title\":\"Yeni\"}"))
                .andExpect(status().isOk());
        mvc.perform(delete("/api/forum/topics/7")).andExpect(status().isNoContent());
        verify(service).delete(42L, 7L);
        verify(limiter, org.mockito.Mockito.times(2)).check(eq("forum:topic:write:42"), eq(30), eq(Duration.ofMinutes(1)));
    }

    @Test
    void categoriesAndMediaEndpoints() throws Exception {
        when(categories.publicList()).thenReturn(List.of(new CategoryView(1L, "gundem", "Gundem", 10, 4)));
        mvc.perform(get("/api/forum/categories")).andExpect(status().isOk())
                .andExpect(jsonPath("$[0].slug").value("gundem")).andExpect(jsonPath("$[0].topicCount").value(4));

        when(media.upload(eq(42L), any())).thenReturn(new ForumMediaService.Uploaded(9L, "/api/forum/media/9",
                "/api/forum/media/9?thumb=true", 64, 48));
        mvc.perform(multipart("/api/forum/media").file(new MockMultipartFile("file", "a.png", "image/png", new byte[] {1, 2})))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(9))
                .andExpect(jsonPath("$.url").value("/api/forum/media/9"))
                .andExpect(jsonPath("$.thumbUrl").value("/api/forum/media/9?thumb=true"))
                .andExpect(jsonPath("$.width").value(64))
                .andExpect(jsonPath("$.height").value(48));
        verify(limiter).check("forum:media:42", 20, Duration.ofHours(1));
        mvc.perform(delete("/api/forum/media/9")).andExpect(status().isNoContent());
        verify(media).deleteUnattached(42L, 9L);
        verify(limiter, org.mockito.Mockito.atLeastOnce()).check(anyString(), anyInt(), any(Duration.class));
    }
}
