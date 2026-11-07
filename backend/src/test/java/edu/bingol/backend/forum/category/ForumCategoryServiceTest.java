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
    @Autowired ForumCategoryGroupRepository groupRepo;
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

    @Test
    void groupsAreReturnedLocalizedAndValidated() {
        ForumCategoryGroup g = new ForumCategoryGroup();
        g.setGroupKey(uniq("g").toLowerCase(Locale.ROOT));
        g.setNameTr("Akademik Grup");
        g.setNameEn("Academic Group");
        g.setNameAr("مجموعة");
        g.setSortOrder(20);
        groupRepo.save(g);
        AdminCategoryView c = service.create(new CategoryInput(uniq("gc-"), "Gruplu", "Grouped", "مجمعة", 7, null, g.getGroupKey()));
        assertEquals(g.getGroupKey(), c.groupKey());
        assertEquals("FORUM_CATEGORY_INVALID",
                code(() -> service.create(new CategoryInput(uniq("gx-"), "X", "X", "X", 8, null, "yok-boyle-grup"))));

        CategoryView tr = find(service.publicList(), c.id());
        assertEquals("Akademik Grup", tr.groupName());
        assertEquals(20, tr.groupOrder());
        LocaleContextHolder.setLocale(Locale.forLanguageTag("en"));
        assertEquals("Academic Group", find(service.publicList(), c.id()).groupName());

        AdminCategoryView cleared = service.update(c.id(), new CategoryInput(null, null, null, null, null, null, " "));
        assertEquals(null, cleared.groupKey());
        assertEquals(null, find(service.publicList(), c.id()).groupKey());
        assertEquals(Integer.MAX_VALUE, find(service.publicList(), c.id()).groupOrder());
    }

    @Test
    void searchFiltersByNameSlugAndGroupIgnoringTurkishCharsAndCase() {
        String tag = uniq("zz").toLowerCase(Locale.ROOT);
        ForumCategoryGroup g = new ForumCategoryGroup();
        g.setGroupKey(uniq("g").toLowerCase(Locale.ROOT));
        g.setNameTr("Hobi " + tag);
        g.setNameEn("Hobbies " + tag);
        g.setNameAr("هوايات");
        g.setSortOrder(70);
        groupRepo.save(g);
        AdminCategoryView muzik = service.create(new CategoryInput(uniq("m-"), "Müzik " + tag, "Music " + tag, "الموسيقى", 9, null, g.getGroupKey()));
        AdminCategoryView yurt = service.create(new CategoryInput(uniq("y-"), "Yurtlar " + tag, "Dorms " + tag, "السكن", 10, null, null));

        // Turkce karakter + buyuk/kucuk duyarsiz, kismi sozcuk
        assertEquals(List.of(muzik.id()), ids(service.publicList("MUZIK " + tag)));
        assertEquals(List.of(muzik.id()), ids(service.publicList("MÜZİK " + tag.toUpperCase(Locale.ROOT))));
        // ingilizce ad ve arapca ad
        assertEquals(List.of(muzik.id()), ids(service.publicList("music " + tag)));
        assertTrue(ids(service.publicList("موسيقى")).contains(muzik.id()));
        // grup adi ile: gruptaki kategori gelir, grupsuz gelmez
        List<Long> byGroup = ids(service.publicList("hobi " + tag));
        assertTrue(byGroup.contains(muzik.id()) && !byGroup.contains(yurt.id()));
        // konu aramasi icin kategori kimlikleri: ad eslesir, grup adi KATILMAZ
        assertTrue(service.matchingActiveIds("MUZIK " + tag).contains(muzik.id()));
        assertFalse(service.matchingActiveIds("hobi " + tag).contains(muzik.id()));
        assertTrue(service.matchingActiveIds("  ").isEmpty());
        // tum sozcukler eslesmeli (VE)
        assertTrue(service.publicList("müzik yurtlar " + tag).isEmpty());
        // bos / bosluk = tum liste; eslesmeyen = bos
        assertTrue(ids(service.publicList("   ")).containsAll(List.of(muzik.id(), yurt.id())));
        assertTrue(service.publicList("hicbirsey-yok-" + tag + "q").isEmpty());
        // LIKE ozel karakterleri sorguda literal: % hepsini getirmez
        assertTrue(service.publicList("%").isEmpty());
        // arsivli kategori aramada da yok
        service.archive(muzik.id());
        assertTrue(service.publicList("müzik " + tag).isEmpty());
    }

    private static List<Long> ids(List<CategoryView> l) {
        return l.stream().map(CategoryView::id).toList();
    }

    private static CategoryView find(List<CategoryView> l, Long id) {
        return l.stream().filter(x -> x.id().equals(id)).findFirst().orElseThrow();
    }
}
