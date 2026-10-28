package edu.bingol.backend.community.category;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityRepository;
import edu.bingol.backend.community.category.CommunityCategoryDtos.AdminCategory;
import edu.bingol.backend.community.category.CommunityCategoryDtos.PublicCategory;
import edu.bingol.backend.community.category.CommunityCategoryDtos.SaveRequest;
import java.util.List;
import java.util.Locale;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.http.HttpStatus;
import org.springframework.transaction.annotation.Transactional;

/** Kategori yasam dongusu (H2): ekle / pasifle / sil / kullanimda sil 409 / sira / sinir / herkese acik liste. */
@SpringBootTest
@Transactional
class CommunityCategoryServiceTest {

    @Autowired CommunityCategoryService svc;
    @Autowired CommunityCategoryRepository repo;
    @Autowired CommunityRepository communities;

    @BeforeEach
    void clean() {
        repo.deleteAll();
        repo.flush();
        svc.setMaxActive(20);
    }

    @AfterEach
    void reset() {
        LocaleContextHolder.resetLocaleContext();
        svc.setMaxActive(20);
    }

    private static SaveRequest save(String key, String tr) {
        return new SaveRequest(key, tr, null, null, null, null);
    }

    private static ApiException fail(Runnable r) {
        return assertThrows(ApiException.class, r::run);
    }

    private void club(String category, Community.Status st) {
        Community c = new Community();
        c.setName("Kulup");
        c.setSlug("k-" + UUID.randomUUID());
        c.setOwnerId(1L);
        c.setStatus(st);
        c.setCategory(category);
        communities.saveAndFlush(c);
    }

    @Test
    void createGeneratesKeyAppendsOrderAndFillsMissingLanguagesFromTurkish() {
        AdminCategory a = svc.create(save(null, "Sosyal Sorumluluk"));
        AdminCategory b = svc.create(new SaveRequest("spor", "Spor", "Sports", "رياضة", "sports", null));

        assertEquals("sosyal-sorumluluk", a.key());
        assertEquals("Sosyal Sorumluluk", a.nameEn());
        assertEquals("Sosyal Sorumluluk", a.nameAr());
        assertTrue(a.active());
        assertTrue(b.sortOrder() > a.sortOrder());
        assertEquals("Sports", b.nameEn());
    }

    @Test
    void duplicateKeyAndBadKeyAreRejected() {
        svc.create(save("spor", "Spor"));

        assertEquals("COMMUNITY_CATEGORY_KEY_TAKEN", fail(() -> svc.create(save("spor", "Baska"))).code());
        assertEquals(HttpStatus.CONFLICT, fail(() -> svc.create(save("spor", "Baska"))).status());
        assertEquals("VALIDATION_ERROR", fail(() -> svc.create(save("Bad Key!", "X"))).code());
    }

    @Test
    void activeLimitBlocksCreateAndReactivationButNotInactiveCreate() {
        svc.setMaxActive(2);
        svc.create(save("a", "A"));
        AdminCategory b = svc.create(save("b", "B"));

        ApiException e = fail(() -> svc.create(save("c", "C")));
        assertEquals("COMMUNITY_CATEGORY_LIMIT", e.code());
        assertEquals(HttpStatus.CONFLICT, e.status());

        // pasif olarak eklemek sinira takilmaz; yeniden aktiflestirmek takilir
        AdminCategory c = svc.create(new SaveRequest("c", "C", null, null, null, false));
        assertFalse(c.active());
        assertEquals("COMMUNITY_CATEGORY_LIMIT", fail(() -> svc.setActive(c.id(), true)).code());

        // bir aktif pasife alininca yer acilir
        svc.setActive(b.id(), false);
        assertTrue(svc.setActive(c.id(), true).active());
        assertEquals(2, svc.adminList().activeCount());
    }

    @Test
    void inUseCategoryCannotBeDeletedButCanBeDeactivatedAndUnusedIsDeleted() {
        AdminCategory used = svc.create(save("spor", "Spor"));
        AdminCategory unused = svc.create(save("sanat", "Sanat"));
        club("spor", Community.Status.ACTIVE);
        club("spor", Community.Status.PENDING_REVIEW);
        club("spor", Community.Status.DELETED); // silinmis kulup sayilmaz

        ApiException e = fail(() -> svc.delete(used.id()));
        assertEquals("COMMUNITY_CATEGORY_IN_USE", e.code());
        assertEquals(HttpStatus.CONFLICT, e.status());
        assertTrue(e.getMessage().contains("2"), e.getMessage());
        assertEquals(2, svc.adminList().items().stream().filter(i -> i.key().equals("spor")).findFirst()
                .orElseThrow().usageCount());

        assertFalse(svc.setActive(used.id(), false).active());
        svc.delete(unused.id());
        assertEquals(List.of("spor"), svc.adminList().items().stream().map(AdminCategory::key).toList());
        assertEquals("COMMUNITY_CATEGORY_NOT_FOUND", fail(() -> svc.delete(unused.id())).code());
    }

    @Test
    void updateChangesNamesButNeverTheKey() {
        AdminCategory a = svc.create(save("spor", "Spor"));

        AdminCategory u = svc.update(a.id(), new SaveRequest("baska", "Spor Yeni", "New Sports", "ar", "ball", null));

        assertEquals("spor", u.key());
        assertEquals("Spor Yeni", u.nameTr());
        assertEquals("ball", u.icon());
    }

    @Test
    void reorderMustBeCompletePermutation() {
        AdminCategory a = svc.create(save("a", "A"));
        AdminCategory b = svc.create(save("b", "B"));
        AdminCategory c = svc.create(save("c", "C"));

        var out = svc.reorder(List.of(c.id(), a.id(), b.id()));

        assertEquals(List.of("c", "a", "b"), out.items().stream().map(AdminCategory::key).toList());
        assertEquals("COMMUNITY_CATEGORY_ORDER_INVALID", fail(() -> svc.reorder(List.of(a.id(), b.id()))).code());
        assertEquals("COMMUNITY_CATEGORY_ORDER_INVALID", fail(() -> svc.reorder(List.of(a.id(), a.id(), b.id()))).code());
        assertEquals("COMMUNITY_CATEGORY_ORDER_INVALID", fail(() -> svc.reorder(List.of(a.id(), b.id(), 9999L))).code());
    }

    @Test
    void publicListHasOnlyActiveInOrderWithLocalizedNameAndFallback() {
        svc.create(new SaveRequest("spor", "Spor", "Sports", "رياضة", null, null));
        svc.create(save("sanat", "Sanat")); // en/ar bos -> tr
        AdminCategory hidden = svc.create(save("gizli", "Gizli"));
        svc.setActive(hidden.id(), false);
        club("spor", Community.Status.ACTIVE);
        club("spor", Community.Status.ACTIVE);

        LocaleContextHolder.setLocale(Locale.forLanguageTag("en"));
        List<PublicCategory> en = svc.listActive();
        assertEquals(List.of("spor", "sanat"), en.stream().map(PublicCategory::key).toList());
        assertEquals("Sports", en.get(0).name());
        assertEquals("Sanat", en.get(1).name());
        assertEquals("spor", en.get(0).category()); // eski alan adi korunur
        assertEquals(2, en.get(0).count());
        assertEquals(0, en.get(1).count());

        LocaleContextHolder.setLocale(Locale.forLanguageTag("ar"));
        assertEquals("رياضة", svc.listActive().get(0).name());
        LocaleContextHolder.setLocale(Locale.forLanguageTag("tr"));
        assertEquals("Spor", svc.listActive().get(0).name());
    }

    @Test
    void resolveForWriteRequiresActiveCategoryButKeepsUnchangedAndAllowsBlank() {
        svc.create(save("spor", "Spor"));
        AdminCategory old = svc.create(save("eski", "Eski"));
        svc.setActive(old.id(), false);

        assertEquals("spor", svc.resolveForWrite(" spor ", null));
        assertEquals("spor", svc.resolveForWrite("SPOR", null)); // kanonik key doner
        assertEquals(null, svc.resolveForWrite("   ", "spor"));
        assertEquals("COMMUNITY_CATEGORY_INVALID", fail(() -> svc.resolveForWrite("yok", null)).code());
        assertEquals("COMMUNITY_CATEGORY_INVALID", fail(() -> svc.resolveForWrite("eski", null)).code());
        // mevcut kulubun pasif kategorisi degismedigi surece korunur
        assertEquals("eski", svc.resolveForWrite("eski", "eski"));
    }

    @Test
    void versionChangesWhenACategoryChanges() {
        AdminCategory a = svc.create(save("a", "A"));
        String v1 = svc.version();
        svc.create(save("b", "B"));
        assertFalse(v1.equals(svc.version()));
        assertTrue(a.id() != null);
    }
}
