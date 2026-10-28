package edu.bingol.backend.community;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.CommunityMember.Role;
import edu.bingol.backend.community.category.CommunityCategory;
import edu.bingol.backend.community.category.CommunityCategoryRepository;
import edu.bingol.backend.community.category.CommunityCategoryService;
import edu.bingol.backend.community.dto.CommunityDtos.CreateCommunityRequest;
import edu.bingol.backend.community.dto.CommunityDtos.UpdateCommunityRequest;
import edu.bingol.backend.community.extras.ClubExtrasHooks;
import edu.bingol.backend.community.permissions.ClubAuditService;
import edu.bingol.backend.community.permissions.ClubMemberGrantRepository;
import edu.bingol.backend.community.permissions.ClubPermissions;
import edu.bingol.backend.media.MediaService;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.user.UserRepository;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** Kulup olustur/guncelle: kategori yonetilen listeden ve AKTIF olmali. */
class CommunityCategoryWriteTest {

    private final CommunityRepository communities = mock(CommunityRepository.class);
    private final CommunityMemberRepository members = mock(CommunityMemberRepository.class);
    private final CommunityCategoryRepository cats = mock(CommunityCategoryRepository.class);
    private final CommunityService svc = new CommunityService(communities, members, mock(UserRepository.class),
            mock(BlockService.class), mock(NotificationService.class), mock(MediaService.class),
            new ClubPermissions(members, mock(ClubMemberGrantRepository.class)), mock(ClubAuditService.class),
            mock(ClubExtrasHooks.class));
    private final Actor user = new Actor(1L, false);

    private static CommunityCategory cat(String key, boolean active) {
        CommunityCategory c = new CommunityCategory();
        c.setKey(key);
        c.setNameTr(key);
        c.setNameEn(key);
        c.setNameAr(key);
        c.setActive(active);
        return c;
    }

    @BeforeEach
    void wire() {
        svc.setCategoryService(new CommunityCategoryService(cats, communities));
        when(cats.findByKey("spor")).thenReturn(Optional.of(cat("spor", true)));
        when(cats.findByKey("eski")).thenReturn(Optional.of(cat("eski", false)));
        when(cats.findByKey("yok")).thenReturn(Optional.empty());
        when(cats.findAll()).thenReturn(List.of(cat("spor", true), cat("eski", false)));
        when(communities.saveAndFlush(any())).thenAnswer(i -> {
            Community c = i.getArgument(0);
            c.setId(10L);
            return c;
        });
    }

    private static CreateCommunityRequest create(String category) {
        return new CreateCommunityRequest("Yeni Kulup", null, category, null, null);
    }

    @Test
    void createRejectsUnknownAndInactiveCategory() {
        for (String bad : List.of("yok", "eski")) {
            ApiException e = assertThrows(ApiException.class, () -> svc.create(user, create(bad)));
            assertEquals("COMMUNITY_CATEGORY_INVALID", e.code());
            assertEquals(400, e.status().value());
        }
        verify(communities, never()).saveAndFlush(any());
    }

    @Test
    void createAcceptsActiveCategoryWithCanonicalKeyAndAllowsNone() {
        assertEquals("spor", svc.create(user, create(" SPOR ")).getCategory());
        assertEquals(null, svc.create(user, create(null)).getCategory());
    }

    @Test
    void updateValidatesChangedCategoryOnly() {
        Community c = new Community();
        c.setId(10L);
        c.setName("Kulup");
        c.setOwnerId(1L);
        c.setStatus(Community.Status.ACTIVE);
        c.setCategory("eski"); // pasife alinmis kategorideki mevcut kulup
        when(communities.findById(10L)).thenReturn(Optional.of(c));
        when(members.findByCommunityIdAndUserId(eq(10L), eq(1L)))
                .thenReturn(Optional.of(new CommunityMember(10L, 1L, Role.OWNER, CommunityMember.Status.ACTIVE)));

        // degismeyen pasif kategori sorun cikarmaz
        svc.update(user, 10L, new UpdateCommunityRequest(null, "yeni aciklama", "eski", null, null));
        assertEquals("eski", c.getCategory());

        // pasife/olmayana gecis reddedilir
        assertEquals("COMMUNITY_CATEGORY_INVALID", assertThrows(ApiException.class,
                () -> svc.update(user, 10L, new UpdateCommunityRequest(null, null, "yok", null, null))).code());
        // aktife gecis kabul
        svc.update(user, 10L, new UpdateCommunityRequest(null, null, "spor", null, null));
        assertEquals("spor", c.getCategory());
    }
}
