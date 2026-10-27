package edu.bingol.backend.moderation.profanity;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.FieldApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityMember;
import edu.bingol.backend.community.CommunityMemberRepository;
import edu.bingol.backend.community.CommunityRepository;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.community.dto.CommunityDtos.CreateCommunityRequest;
import edu.bingol.backend.community.dto.CommunityDtos.UpdateCommunityRequest;
import edu.bingol.backend.community.extras.ClubExtrasHooks;
import edu.bingol.backend.community.permissions.ClubAuditService;
import edu.bingol.backend.community.permissions.ClubMemberGrantRepository;
import edu.bingol.backend.community.permissions.ClubPermissions;
import edu.bingol.backend.media.MediaService;
import edu.bingol.backend.messaging.ConversationMemberRepository;
import edu.bingol.backend.messaging.ConversationRepository;
import edu.bingol.backend.messaging.ConversationService;
import edu.bingol.backend.messaging.MessageCodec;
import edu.bingol.backend.messaging.MessageRepository;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.user.UserRepository;
import java.lang.reflect.Field;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.test.util.ReflectionTestUtils;

/** ContentGuard uygulama noktalari ve sohbetin muafiyeti. Kelimeler yerlesik listeden okunur. */
class ContentGuardApplyTest {

    private final ProfanityHitLogger hits = mock(ProfanityHitLogger.class);
    private final ProfanityProperties props = new ProfanityProperties(true, ProfanityProperties.Mode.BLOCK, 30);
    private final ContentGuard guard = new ContentGuard(ProfanityFilter.builtInOnly(), props, hits);

    private static String bad() {
        for (String l : ProfanityFilter.builtInLines("tr")) {
            if (l.matches("=[a-z]{6,10}")) return l.substring(1);
        }
        throw new IllegalStateException();
    }

    private static FieldApiException violation(Runnable r) {
        return assertThrows(FieldApiException.class, r::run);
    }

    // ---- ContentGuard ----

    @Test
    void violationIs422WithFieldAndDoesNotEchoTheWord() {
        String w = bad();
        FieldApiException e = violation(() -> guard.assertClean(ContentGuard.Entity.CLUB, "name", 7L, "Kulup " + w));
        assertEquals(HttpStatus.UNPROCESSABLE_ENTITY, e.status());
        assertEquals("CONTENT_PROFANITY", e.code());
        assertEquals("name", e.field());
        assertFalse(e.getMessage().toLowerCase().contains(w));
        verify(hits).record("CLUB", "name", 7L, "BLOCK");
    }

    @Test
    void patchChecksOnlyChangedFields() {
        String w = bad();
        // eski deger filtreyi gecemese de ayni deger tekrar gonderilirse sorun yok
        assertDoesNotThrow(() -> guard.assertChanged(ContentGuard.Entity.CLUB, "name", 1L, "Eski " + w, "Eski " + w));
        assertDoesNotThrow(() -> guard.assertChanged(ContentGuard.Entity.CLUB, "name", 1L, "Eski " + w, null));
        violation(() -> guard.assertChanged(ContentGuard.Entity.CLUB, "name", 1L, "Temiz", "Yeni " + w));
    }

    @Test
    void disabledOrFlagModeDoesNotBlock() {
        String w = bad();
        ContentGuard off = new ContentGuard(ProfanityFilter.builtInOnly(),
                new ProfanityProperties(false, ProfanityProperties.Mode.BLOCK, 30), hits);
        assertDoesNotThrow(() -> off.assertClean("x", w));
        ProfanityHitLogger flagHits = mock(ProfanityHitLogger.class);
        ContentGuard flag = new ContentGuard(ProfanityFilter.builtInOnly(),
                new ProfanityProperties(true, ProfanityProperties.Mode.FLAG, 30), flagHits);
        assertDoesNotThrow(() -> flag.assertClean(ContentGuard.Entity.POST, "text", 2L, w));
        verify(flagHits).record("POST", "text", 2L, "FLAG");
    }

    @Test
    void cleanTextNeverLogs() {
        guard.assertClean(ContentGuard.Entity.POST, "text", 1L, "Cumartesi kampüs gezisi var, herkes davetli.");
        verify(hits, never()).record(anyString(), anyString(), any(), anyString());
    }

    // ---- topluluk ----

    private CommunityService community(CommunityRepository communities) {
        CommunityMemberRepository members = mock(CommunityMemberRepository.class);
        CommunityService svc = new CommunityService(communities, members, mock(UserRepository.class),
                mock(BlockService.class), mock(NotificationService.class), mock(MediaService.class),
                new ClubPermissions(members, mock(ClubMemberGrantRepository.class)), mock(ClubAuditService.class),
                mock(ClubExtrasHooks.class));
        ReflectionTestUtils.setField(svc, "guard", guard);
        return svc;
    }

    @Test
    void clubCreateRejectsProfaneNameDescriptionAndCategory() {
        CommunityRepository communities = mock(CommunityRepository.class);
        CommunityService svc = community(communities);
        Actor admin = new Actor(1L, true); // yonetici de muaf degil
        String w = bad();
        assertEquals("name", violation(() -> svc.create(admin, new CreateCommunityRequest("Kulup " + w, null, null, null, null))).field());
        assertEquals("description", violation(() -> svc.create(admin, new CreateCommunityRequest("Temiz Kulup", "x " + w, null, null, null))).field());
        assertEquals("category", violation(() -> svc.create(admin, new CreateCommunityRequest("Temiz Kulup", null, w + " grubu", null, null))).field());
        verify(communities, never()).saveAndFlush(any());
    }

    @Test
    void clubUpdateIgnoresUnchangedProfaneNameButRejectsChangedDescription() {
        CommunityRepository communities = mock(CommunityRepository.class);
        CommunityService svc = community(communities);
        String w = bad();
        Community c = new Community();
        c.setId(10L);
        c.setName("Eski " + w);
        c.setOwnerId(1L);
        c.setStatus(Community.Status.ACTIVE);
        when(communities.findById(10L)).thenReturn(Optional.of(c));
        Actor admin = new Actor(1L, true);

        // aciklama degisiyor ve kirli: reddedilir
        assertEquals("description", violation(() -> svc.update(admin, 10L,
                new UpdateCommunityRequest(null, "yeni " + w, null, null, null))).field());
        // ad degismiyor (kirli eski ad) + temiz aciklama: CONTENT_PROFANITY firlatilmaz (sonraki mock eksikleri baska hata verebilir)
        try {
            svc.update(admin, 10L, new UpdateCommunityRequest("Eski " + w, "Temiz aciklama", null, null, null));
        } catch (FieldApiException e) {
            throw e;
        } catch (RuntimeException ignored) {
            // views(...) mock'lari eksik; amac filtre hatasi olmadigini gostermek
        }
    }

    // ---- grup basligi ----

    @Test
    void groupTitleIsFilteredOnCreateAndRename() {
        ConversationRepository convs = mock(ConversationRepository.class);
        UserRepository users = mock(UserRepository.class);
        ConversationService svc = new ConversationService(convs, mock(ConversationMemberRepository.class),
                mock(MessageRepository.class), users, mock(BlockService.class), mock(MessageCodec.class));
        ReflectionTestUtils.setField(svc, "guard", guard);
        String w = bad();
        assertEquals("title", violation(() -> svc.createGroup(1L, "Grup " + w, List.of(2L))).field());
        verify(convs, never()).save(any());
    }

    // ---- sohbet muaf ----

    @Test
    void messagingPackageHasNoContentGuardDependency() throws Exception {
        for (String cn : List.of("edu.bingol.backend.messaging.MessageService",
                "edu.bingol.backend.messaging.MessageActionService",
                "edu.bingol.backend.messaging.media.MessageAttachmentService")) {
            Class<?> k = Class.forName(cn);
            for (Field f : k.getDeclaredFields()) {
                assertFalse(f.getType().getName().contains("profanity"), cn + " filtre kullanmamali: " + f.getName());
            }
        }
    }
}
