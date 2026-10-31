package edu.bingol.backend.common;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityMember;
import edu.bingol.backend.community.CommunityMemberRepository;
import edu.bingol.backend.community.CommunityRepository;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.community.extras.ClubExtrasHooks;
import edu.bingol.backend.community.permissions.ClubAuditService;
import edu.bingol.backend.community.permissions.ClubMemberGrantRepository;
import edu.bingol.backend.community.permissions.ClubPermissions;
import edu.bingol.backend.media.MediaService;
import edu.bingol.backend.media.StoredImage;
import edu.bingol.backend.menu.MenuAdminService;
import edu.bingol.backend.menu.MenuCalorieService;
import edu.bingol.backend.menu.MenuDay;
import edu.bingol.backend.menu.MenuRepository;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.profile.ProfileService;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.support.AbstractPlatformTransactionManager;
import org.springframework.transaction.support.DefaultTransactionStatus;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.web.multipart.MultipartFile;

/**
 * T-068 (A2-05): avatar / kapak / logo yuklemede agir gorsel isleme (media.storeImage) acik DB islemi DISINDA
 * calisir; yalniz URL yazimi kisa islemdedir. Aksi halde Hikari baglantisi/PostgreSQL oturumu "idle in transaction"
 * kalir (24 eszamanli yuklemede 24 bosta islem, yukte idle-in-transaction zaman asimiyla 500).
 */
class ImageUploadOutsideTxTest {

    /** Gercek baglanti acmayan, yalniz "islem acik mi" bilgisini eşzamanlama yoneticisine yansitan yonetici. */
    private static final class FakeTxManager extends AbstractPlatformTransactionManager {
        int commits;

        @Override
        protected Object doGetTransaction() {
            return new Object();
        }

        @Override
        protected void doBegin(Object transaction, TransactionDefinition definition) {
        }

        @Override
        protected void doCommit(DefaultTransactionStatus status) {
            commits++;
        }

        @Override
        protected void doRollback(DefaultTransactionStatus status) {
        }
    }

    private final FakeTxManager tm = new FakeTxManager();
    /** storeImage ve release cagrilirken islem acik miydi (true = hata). */
    private final List<Boolean> storeInTx = new ArrayList<>();
    private final List<Boolean> writeInTx = new ArrayList<>();
    private final List<Boolean> releaseInTx = new ArrayList<>();
    private final MediaService media = mock(MediaService.class);
    private final MultipartFile file = new MockMultipartFile("file", "a.jpg", "image/jpeg", new byte[] {1});
    private final StoredImage stored = new StoredImage("/files/avatars/new.jpg", "/files/avatars/new-t.jpg", 1, 1, 1,
            "image/jpeg");

    private void stubMedia() {
        when(media.storeImage(any(), any())).thenAnswer(inv -> {
            storeInTx.add(TransactionSynchronizationManager.isActualTransactionActive());
            return stored;
        });
        Mockito.doAnswer(inv -> {
            releaseInTx.add(TransactionSynchronizationManager.isActualTransactionActive());
            return null;
        }).when(media).release(any());
    }

    @Test
    void shortTxRunsWorkInsideOneTransactionAndDirectWithoutManager() {
        ShortTx with = ShortTx.of(tm);
        assertTrue(with.call(TransactionSynchronizationManager::isActualTransactionActive));
        assertEquals(1, tm.commits);
        assertFalse(TransactionSynchronizationManager.isActualTransactionActive());
        assertFalse(ShortTx.direct().call(TransactionSynchronizationManager::isActualTransactionActive));
    }

    @Test
    void avatarImageIsProcessedOutsideTransactionAndOldFileReleasedAfterCommit() {
        stubMedia();
        UserRepository users = mock(UserRepository.class);
        User u = new User();
        u.setId(5L);
        u.setAvatarUrl("/files/avatars/old.jpg");
        when(users.findById(5L)).thenReturn(Optional.of(u));
        when(users.saveAndFlush(any())).thenAnswer(inv -> {
            writeInTx.add(TransactionSynchronizationManager.isActualTransactionActive());
            return inv.getArgument(0);
        });
        ProfileService svc = new ProfileService(users, mock(BlockService.class), media, null, null, null, null, null,
                null, null, null, null, null);
        org.springframework.test.util.ReflectionTestUtils.invokeMethod(svc, "setTxManager", tm);

        User out = svc.setAvatar(5L, file);

        assertEquals("/files/avatars/new.jpg", out.getAvatarUrl());
        assertEquals(List.of(false), storeInTx, "gorsel isleme islem disinda olmali");
        assertEquals(List.of(true), writeInTx, "URL yazimi kisa islemde olmali");
        assertEquals(List.of(false), releaseInTx, "eski dosya commit sonrasi birakilmali");
        verify(media).release("/files/avatars/old.jpg");
        assertEquals(1, tm.commits);
    }

    @Test
    void menuImageIsProcessedOutsideTransaction() {
        stubMedia();
        MenuRepository repo = mock(MenuRepository.class);
        LocalDate date = LocalDate.of(2026, 10, 28);
        MenuDay d = new MenuDay();
        d.setMenuDate(date);
        d.setItems("Corba");
        d.setImageUrl("/files/covers/old.jpg");
        when(repo.findByMenuDate(date)).thenReturn(Optional.of(d));
        when(repo.saveAndFlush(any())).thenAnswer(inv -> {
            writeInTx.add(TransactionSynchronizationManager.isActualTransactionActive());
            return inv.getArgument(0);
        });
        MenuAdminService svc = new MenuAdminService(repo, media, mock(MenuCalorieService.class));
        org.springframework.test.util.ReflectionTestUtils.invokeMethod(svc, "setTxManager", tm);

        svc.setImage(date, file);

        assertEquals(List.of(false), storeInTx);
        assertEquals(List.of(true), writeInTx);
        assertEquals(List.of(false), releaseInTx);
        assertEquals("/files/avatars/new.jpg", d.getImageUrl());
    }

    @Test
    void clubCoverAndLogoAreProcessedOutsideTransaction() {
        stubMedia();
        CommunityRepository communities = mock(CommunityRepository.class);
        CommunityMemberRepository members = mock(CommunityMemberRepository.class);
        CommunityService svc = new CommunityService(communities, members, mock(UserRepository.class),
                mock(BlockService.class), mock(NotificationService.class), media,
                new ClubPermissions(members, mock(ClubMemberGrantRepository.class)), mock(ClubAuditService.class),
                mock(ClubExtrasHooks.class));
        org.springframework.test.util.ReflectionTestUtils.invokeMethod(svc, "setTxManager", tm);
        Community c = new Community();
        c.setId(10L);
        c.setName("Kulup");
        c.setOwnerId(99L);
        c.setStatus(Community.Status.ACTIVE);
        c.setCoverUrl("/files/covers/old.jpg");
        c.setLogoUrl("/files/avatars/oldlogo.jpg");
        when(communities.findById(10L)).thenReturn(Optional.of(c));
        when(communities.saveAndFlush(any())).thenAnswer(inv -> {
            writeInTx.add(TransactionSynchronizationManager.isActualTransactionActive());
            return inv.getArgument(0);
        });
        when(members.findByCommunityIdAndUserId(10L, 99L))
                .thenReturn(Optional.of(new CommunityMember(10L, 99L, CommunityMember.Role.OWNER,
                        CommunityMember.Status.ACTIVE)));
        Actor owner = new Actor(99L, false);

        svc.setCover(owner, 10L, file);
        svc.setLogo(owner, 10L, file);

        assertEquals(List.of(false, false), storeInTx);
        assertEquals(List.of(true, true), writeInTx);
        assertEquals(List.of(false, false), releaseInTx);
        verify(media).release("/files/covers/old.jpg");
        verify(media).release("/files/avatars/oldlogo.jpg");
    }
}
