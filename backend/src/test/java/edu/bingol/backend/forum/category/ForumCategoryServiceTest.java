package edu.bingol.backend.forum.category;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.forum.category.ForumCategoryDtos.AdminCategoryView;
import edu.bingol.backend.forum.category.ForumCategoryDtos.CategoryInput;
import edu.bingol.backend.forum.category.ForumCategoryDtos.CategoryView;
import edu.bingol.backend.forum.topic.ForumTestSupport;
import edu.bingol.backend.forum.topic.ForumTopicRepository;
import edu.bingol.backend.forum.topic.spi.ForumTopicStateService;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.List;
import java.util.Locale;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

/** Kategori yonetimi (D'nin admin ucu bu servisi cagirir) ve herkese acik liste: yerellestirme, sayac, arsiv, sira. */
@SpringBootTest
class ForumCategoryServiceTest {

    @MockitoBean edu.bingol.backend.common.RateLimiter limiter;

    @Autowired ForumCategoryService service;
    @Autowired ForumCategoryRepository repo;
    @Autowired ForumTopicRepository topics;
    @Autowired UserRepository users;
    @Autowired ForumTopicStateService state;

    @AfterEach
    void resetLocale() {
        LocaleContextHolder.setLocale(Locale.forLanguageTag("tr"));
    }

    private static String code(Runnable r) {
        return assertThrows(ApiException.class, r::run).code();
    }

    private static String uniq(String p) {
        return p + UUID.randomUUID().toString().substring(0, 6);
    }

    @Test
    void createGeneratesUniqueSlugValidatesAndRejectsDuplicates() {
        String tr = "Spor " + uniq("x");
        AdminCategoryView a = service.create(new CategoryInput(null, tr, "Sports", "رياضة", null, null));
        assertTrue(a.active());
        assertTrue(a.slug().startsWith("spor-"), a.slug());
        AdminCategoryView b = service.create(new CategoryInput(null, tr, "Sports 2", "رياضة 2", null, null));
        assertEquals(a.slug() + "-2", b.slug(), "ayni adin slug'i numaralanir");
        assertEquals("FORUM_CATEGORY_SLUG_TAKEN", code(() -> service.create(new CategoryInput(a.slug(), "Baska", "Other", "اخر", null, null))));
        assertEquals("FORUM_CATEGORY_INVALID", code(() -> service.create(new CategoryInput("Gecersiz Slug!", "Baska", "Other", "اخر", null, null))));
        assertEquals("FORUM_CATEGORY_INVALID", code(() -> service.create(new CategoryInput(null, "  ", "Other", "اخر", null, null))));
        assertEquals("FORUM_CATEGORY_INVALID", code(() -> service.create(new CategoryInput(null, "Ad", null, "اخر", null, null))));
        assertEquals("FORUM_CATEGORY_INVALID", code(() -> service.create(new CategoryInput(null, "x".repeat(81), "Other", "اخر", null, null))));
        assertEquals("FORUM_CATEGORY_INVALID", code(() -> service.create(null)));
    }

    @Test
    void updatePatchesOnlyGivenFieldsAndChecksSlugConflict() {
        AdminCategoryView a = service.create(new CategoryInput(uniq("a-"), "A", "A en", "A ar", 5, null));
        AdminCategoryView b = service.create(new CategoryInput(uniq("b-"), "B", "B en", "B ar", 6, null));
        AdminCategoryView u = service.update(a.id(), new CategoryInput(null, "A yeni", null, null, 99, null));
        assertEquals("A yeni", u.nameTr());
        assertEquals("A en", u.nameEn());
        assertEquals(99, u.sortOrder());
        assertEquals(a.slug(), u.slug());
        assertEquals("FORUM_CATEGORY_SLUG_TAKEN", code(() -> service.update(a.id(), new CategoryInput(b.slug(), null, null, null, null, null))));
        AdminCategoryView same = service.update(a.id(), new CategoryInput(a.slug(), null, null, null, null, null));
        assertEquals(a.slug(), same.slug(), "kendi slug'ini tekrar vermek cakisma degildir");
        assertEquals("FORUM_CATEGORY_NOT_FOUND", code(() -> service.update(987654L, new CategoryInput(null, "x", null, null, null, null))));
    }

    @Test
    void publicListIsLocalizedCountedAndHidesArchived() {
        User me = ForumTestSupport.user(users, "ben");
        AdminCategoryView c = service.create(new CategoryInput(uniq("l-"), "Gundem", "Trending", "الأحداث", 3, null));
        ForumTestSupport.topic(topics, me.getId(), c.id(), "bir", 0, 0, false, 1);
        ForumTestSupport.topic(topics, me.getId(), c.id(), "iki", 0, 0, false, 1);
        edu.bingol.backend.forum.topic.ForumTopic removed = ForumTestSupport.topic(topics, me.getId(), c.id(), "uc", 0, 0, false, 1);
        state.remove(removed.getId(), "x");

        LocaleContextHolder.setLocale(Locale.forLanguageTag("en"));
        CategoryView en = find(service.publicList(), c.id());
        assertEquals("Trending", en.name());
        assertEquals(2, en.topicCount(), "kaldirilmis konu sayilmaz");
        LocaleContextHolder.setLocale(Locale.forLanguageTag("ar"));
        assertEquals("الأحداث", find(service.publicList(), c.id()).name());
        LocaleContextHolder.setLocale(Locale.forLanguageTag("tr"));
        assertEquals("Gundem", find(service.publicList(), c.id()).name());

        AdminCategoryView arch = service.archive(c.id());
        assertFalse(arch.active());
        assertTrue(service.publicList().stream().noneMatch(x -> x.id().equals(c.id())), "arsivli kategori listede yok");
        assertTrue(service.adminList().stream().anyMatch(x -> x.id().equals(c.id()) && !x.active()), "yonetici arsivliyi gorur");
        assertEquals("FORUM_CATEGORY_ARCHIVED", code(() -> service.requireOpen(c.id())));
        service.archive(c.id()); // idempotent
        service.update(c.id(), new CategoryInput(null, null, null, null, null, true));
        service.requireOpen(c.id());
    }

    @Test
    void reorderWritesTheGivenOrderAndRejectsUnknownIds() {
        AdminCategoryView a = service.create(new CategoryInput(uniq("r1-"), "R1", "R1", "R1", 1000, null));
        AdminCategoryView b = service.create(new CategoryInput(uniq("r2-"), "R2", "R2", "R2", 1001, null));
        AdminCategoryView c = service.create(new CategoryInput(uniq("r3-"), "R3", "R3", "R3", 1002, null));
        List<AdminCategoryView> after = service.reorder(List.of(c.id(), a.id(), b.id()));
        List<Long> ids = after.stream().map(AdminCategoryView::id).toList();
        assertTrue(ids.indexOf(c.id()) < ids.indexOf(a.id()) && ids.indexOf(a.id()) < ids.indexOf(b.id()), ids.toString());
        List<Long> pub = service.publicList().stream().map(CategoryView::id).toList();
        assertTrue(pub.indexOf(c.id()) < pub.indexOf(a.id()) && pub.indexOf(a.id()) < pub.indexOf(b.id()));
        assertEquals("FORUM_CATEGORY_NOT_FOUND", code(() -> service.reorder(List.of(a.id(), 424242L))));
    }

    private static CategoryView find(List<CategoryView> l, Long id) {
        return l.stream().filter(x -> x.id().equals(id)).findFirst().orElseThrow();
    }
}
