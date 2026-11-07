package edu.bingol.backend.forum.moderation;

import edu.bingol.backend.common.ApiException;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import org.springframework.context.ApplicationContext;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

/**
 * B'nin {@code forum.comment.spi.ForumCommentStateService} bean'ine (remove/restore) kopru. Paralel gelistirme sirasinda
 * B dali D'den ONCE/SONRA birlesebilsin diye arayuz derleme zamaninda DEGIL calisma zamaninda bulunur (sinif adi ve
 * imza B'nin sozlesmesidir: {@code remove(Long, String)}, {@code restore(Long)}). Bean yoksa (B birlesmemis) islem
 * 503 FORUM_MOD_COMMENTS_UNAVAILABLE verir, hicbir kayit yazilmaz. B birlestikten sonra bu sinif dogrudan arayuz
 * cagrisina cevrilebilir.
 */
@Component
class ForumCommentStatesImpl implements ForumCommentStates {

    private static final String SPI = "edu.bingol.backend.forum.comment.spi.ForumCommentStateService";

    private final ApplicationContext ctx;

    ForumCommentStatesImpl(ApplicationContext ctx) {
        this.ctx = ctx;
    }

    @Override
    public void remove(Long commentId, String reason) {
        invoke("remove", new Class<?>[] {Long.class, String.class}, commentId, reason);
    }

    @Override
    public void restore(Long commentId) {
        invoke("restore", new Class<?>[] {Long.class}, commentId);
    }

    private void invoke(String method, Class<?>[] types, Object... args) {
        Object bean;
        Method m;
        try {
            Class<?> spi = Class.forName(SPI);
            var provider = ctx.getBeanProvider(spi);
            bean = provider == null ? null : provider.getIfAvailable();
            if (bean == null) {
                throw unavailable();
            }
            m = spi.getMethod(method, types);
        } catch (ClassNotFoundException | NoSuchMethodException e) {
            throw unavailable();
        }
        try {
            m.invoke(bean, args);
        } catch (InvocationTargetException e) {
            if (e.getCause() instanceof RuntimeException re) {
                throw re;
            }
            throw new IllegalStateException(e.getCause());
        } catch (IllegalAccessException e) {
            throw new IllegalStateException(e);
        }
    }

    private static ApiException unavailable() {
        return new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "FORUM_MOD_COMMENTS_UNAVAILABLE",
                "Yorum moderasyonu şu anda kullanılamıyor.");
    }
}
