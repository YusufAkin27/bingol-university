package edu.bingol.backend.common;

import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.community.Actor;
import edu.bingol.backend.event.EventService;
import edu.bingol.backend.event.UserEvent;
import edu.bingol.backend.event.UserEventRepository;
import edu.bingol.backend.forum.category.ForumCategory;
import edu.bingol.backend.forum.category.ForumCategoryRepository;
import edu.bingol.backend.forum.topic.ForumFeedService;
import edu.bingol.backend.forum.topic.ForumTestSupport;
import edu.bingol.backend.forum.topic.ForumTopicRepository;
import edu.bingol.backend.post.PostFixtures;
import edu.bingol.backend.post.PostRepository;
import edu.bingol.backend.post.PostService;
import edu.bingol.backend.post.media.PostMediaRepository;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Proxy;
import java.sql.Connection;
import java.time.Duration;
import java.time.Instant;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.function.Supplier;
import javax.sql.DataSource;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.config.BeanPostProcessor;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;

/**
 * B7: liste uclarinda N+1 yok. Veri 3 satirdan 15 satira cikarken SQL sayisi (JDBC prepareStatement/createStatement)
 * satir sayisiyla BUYUMEMELI (kucuk bir sabit pay). Sayac DataSource vekiliyle Hibernate ve JdbcTemplate yollarini
 * birlikte sayar. (H2; PostgreSQL'e ozel sorgu yollari smoke betiklerinde dogrulanir.)
 */
@SpringBootTest
@Import(ListQueryCountTest.Counting.class)
class ListQueryCountTest {

    static final AtomicInteger SQL = new AtomicInteger();

    @TestConfiguration
    static class Counting {
        @Bean
        static BeanPostProcessor sqlCounter() {
            return new BeanPostProcessor() {
                @Override
                public Object postProcessAfterInitialization(Object bean, String name) {
                    if (!(bean instanceof DataSource ds) || Proxy.isProxyClass(bean.getClass())) {
                        return bean;
                    }
                    return Proxy.newProxyInstance(bean.getClass().getClassLoader(), new Class<?>[] {DataSource.class},
                            (p, m, a) -> {
                                Object r = invoke(ds, m, a);
                                if (r instanceof Connection c && m.getName().equals("getConnection")) {
                                    return Proxy.newProxyInstance(c.getClass().getClassLoader(), new Class<?>[] {Connection.class},
                                            (p2, m2, a2) -> {
                                                String n = m2.getName();
                                                if (n.equals("prepareStatement") || n.equals("createStatement")
                                                        || n.equals("prepareCall")) {
                                                    SQL.incrementAndGet();
                                                }
                                                return invoke(c, m2, a2);
                                            });
                                }
                                return r;
                            });
                }
            };
        }

        private static Object invoke(Object target, java.lang.reflect.Method m, Object[] a) throws Throwable {
            try {
                return m.invoke(target, a);
            } catch (InvocationTargetException e) {
                throw e.getCause();
            }
        }
    }

    @Autowired UserRepository users;
    @Autowired EventService events;
    @Autowired UserEventRepository eventRepo;
    @Autowired PostService posts;
    @Autowired PostRepository postRepo;
    @Autowired PostMediaRepository mediaRepo;
    @Autowired ForumFeedService forumFeed;
    @Autowired ForumTopicRepository topicRepo;
    @Autowired ForumCategoryRepository cats;

    private static int count(Supplier<?> call) {
        call.get(); // isinma (lazy init) sayilmaz
        int before = SQL.get();
        call.get();
        return SQL.get() - before;
    }

    private static void assertFlat(String what, int small, int large) {
        assertTrue(large <= small + 2, what + ": SQL sayisi satirla buyuyor (3 satir=" + small + ", 15 satir=" + large + ")");
    }

    @Test
    void eventListIsFlat() {
        User me = ForumTestSupport.user(users, "etkinlik-bakan");
        User owner = ForumTestSupport.user(users, "etkinlik-sahibi");
        Actor a = new Actor(me.getId(), false);
        addEvents(owner, 3);
        int small = count(() -> events.list(a, null, null, null, null, 50));
        addEvents(owner, 12);
        int large = count(() -> events.list(a, null, null, null, null, 50));
        assertFlat("EventService.list", small, large);
    }

    private void addEvents(User owner, int n) {
        for (int i = 0; i < n; i++) {
            UserEvent e = new UserEvent();
            e.setTitle("Sayim etkinligi " + i);
            e.setStartsAt(Instant.now().plus(Duration.ofDays(2)));
            e.setEndsAt(Instant.now().plus(Duration.ofDays(2)).plus(Duration.ofHours(2)));
            e.setCreatedBy(owner.getId());
            e.setStatus(UserEvent.Status.ACTIVE);
            eventRepo.saveAndFlush(e);
        }
    }

    @Test
    void postFeedIsFlat() {
        User me = ForumTestSupport.user(users, "gonderi-bakan");
        User author = ForumTestSupport.user(users, "gonderi-yazar");
        for (int i = 0; i < 3; i++) {
            PostFixtures.withPhoto(postRepo, mediaRepo, author.getId(), "g" + i);
        }
        int small = count(() -> posts.feed(me.getId(), "latest", null, 50));
        for (int i = 0; i < 12; i++) {
            PostFixtures.withPhoto(postRepo, mediaRepo, author.getId(), "h" + i);
        }
        int large = count(() -> posts.feed(me.getId(), "latest", null, 50));
        assertFlat("PostService.feed", small, large);
    }

    @Test
    void forumFeedIsFlat() {
        User me = ForumTestSupport.user(users, "forum-bakan");
        User author = ForumTestSupport.user(users, "forum-yazar");
        ForumCategory c = ForumTestSupport.category(cats, "Sayim");
        for (int i = 0; i < 3; i++) {
            ForumTestSupport.topic(topicRepo, author.getId(), c.getId(), "k" + i, 1, 1, false, 10);
        }
        int small = count(() -> forumFeed.feed(me.getId(), ForumFeedService.Sort.NEWEST, c.getId(), null, 50));
        for (int i = 3; i < 15; i++) {
            ForumTestSupport.topic(topicRepo, author.getId(), c.getId(), "k" + i, 1, 1, false, 10);
        }
        int large = count(() -> forumFeed.feed(me.getId(), ForumFeedService.Sort.NEWEST, c.getId(), null, 50));
        assertFlat("ForumFeedService.feed", small, large);
    }
}
