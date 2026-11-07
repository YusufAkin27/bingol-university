package edu.bingol.backend.moderation;

import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.post.follow.FollowRequestService;
import edu.bingol.backend.post.follow.FollowService;
import edu.bingol.backend.user.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.support.DefaultListableBeanFactory;

/**
 * FIX-P05 (A06#3, K15): engelleme iki yonlu takibi ve bekleyen takip isteklerini de siler
 * (gizli hesapta engel kalkinca eski takipci olarak kalma sorunu).
 */
class BlockDropsFollowTest {

    private final UserBlockRepository blocks = mock(UserBlockRepository.class);
    private final UserRepository users = mock(UserRepository.class);
    private final BlockService svc = new BlockService(blocks, users);
    private final FollowService follows = mock(FollowService.class);
    private final FollowRequestService requests = mock(FollowRequestService.class);

    private void wire() {
        DefaultListableBeanFactory bf = new DefaultListableBeanFactory();
        bf.registerSingleton("followService", follows);
        bf.registerSingleton("followRequestService", requests);
        svc.setFollowProviders(bf.getBeanProvider(FollowService.class), bf.getBeanProvider(FollowRequestService.class));
    }

    @Test
    void blockDropsFollowsAndPendingRequestsBetweenTheTwoUsers() {
        wire();
        when(users.existsById(2L)).thenReturn(true);

        svc.block(1L, 2L);

        verify(blocks).save(org.mockito.ArgumentMatchers.any(UserBlock.class));
        verify(follows).dropBetween(1L, 2L);
        verify(requests).dropBetween(1L, 2L);
    }

    @Test
    void alreadyBlockedStillCleansLeftoverRelations() {
        wire();
        when(users.existsById(2L)).thenReturn(true);
        when(blocks.existsByBlockerIdAndBlockedId(1L, 2L)).thenReturn(true);

        svc.block(1L, 2L);

        verify(blocks, never()).save(org.mockito.ArgumentMatchers.any(UserBlock.class));
        verify(follows).dropBetween(1L, 2L);
    }

    @Test
    void worksWithoutFollowBeans() {
        when(users.existsById(2L)).thenReturn(true);

        svc.block(1L, 2L); // sag taraf yok (birim testlerinde elle kurulum): hata vermez

        verify(blocks).save(org.mockito.ArgumentMatchers.any(UserBlock.class));
    }
}
