package edu.bingol.backend.config;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.startsWith;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ClientIp;
import edu.bingol.backend.common.RateLimiter;
import jakarta.servlet.FilterChain;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

class BasicAuthThrottleFilterTest {

    private final RateLimiter limiter = mock(RateLimiter.class);
    private final StringRedisTemplate redis = mock(StringRedisTemplate.class);
    @SuppressWarnings("unchecked")
    private final ValueOperations<String, String> ops = mock(ValueOperations.class);
    private final BasicAuthThrottleFilter filter =
            new BasicAuthThrottleFilter(limiter, new ClientIp("10.0.0.0/8"), redis);

    BasicAuthThrottleFilterTest() {
        when(redis.opsForValue()).thenReturn(ops);
    }

    private static MockHttpServletRequest basic(String user, String pw) {
        MockHttpServletRequest req = new MockHttpServletRequest("GET", "/api/admin/users");
        req.setRemoteAddr("203.0.113.9");
        req.addHeader("Authorization", "Basic "
                + Base64.getEncoder().encodeToString((user + ":" + pw).getBytes(StandardCharsets.UTF_8)));
        return req;
    }

    @Test
    void requestsWithoutBasicHeaderPassUntouched() throws Exception {
        FilterChain chain = mock(FilterChain.class);
        MockHttpServletRequest req = new MockHttpServletRequest("GET", "/api/admin/users");
        req.addHeader("Authorization", "Bearer abc");

        filter.doFilter(req, new MockHttpServletResponse(), chain);

        verify(chain).doFilter(any(), any());
        verify(redis, never()).opsForValue();
    }

    @Test
    void failedAttemptsAreCountedPerIpAndPerUsername() throws Exception {
        FilterChain failing = (rq, rs) -> ((MockHttpServletResponse) rs).setStatus(401);

        filter.doFilter(basic("admin", "yanlis"), new MockHttpServletResponse(), failing);

        verify(ops).increment("adminbasic:fail:ip:203.0.113.9");
        verify(ops).increment(startsWith("adminbasic:fail:user:"));
    }

    @Test
    void ipFailureCeilingAnswers429WithoutReachingTheChain() throws Exception {
        when(ops.get("adminbasic:fail:ip:203.0.113.9")).thenReturn(String.valueOf(BasicAuthThrottleFilter.IP_FAIL_MAX));
        FilterChain chain = mock(FilterChain.class);
        MockHttpServletResponse res = new MockHttpServletResponse();

        filter.doFilter(basic("admin", "x"), res, chain);

        assertEquals(429, res.getStatus());
        verify(chain, never()).doFilter(any(), any());
    }

    @Test
    void usernameCeilingBlocksDistributedGuessing() throws Exception {
        when(ops.get(startsWith("adminbasic:fail:user:")))
                .thenReturn(String.valueOf(BasicAuthThrottleFilter.USER_FAIL_MAX));
        MockHttpServletResponse res = new MockHttpServletResponse();

        filter.doFilter(basic("admin", "x"), res, mock(FilterChain.class));

        assertEquals(429, res.getStatus());
    }

    @Test
    void redisFailureIsFailClosed() throws Exception {
        doThrow(new IllegalStateException("redis down")).when(limiter).check(anyString(), anyInt(), any());
        FilterChain chain = mock(FilterChain.class);
        MockHttpServletResponse res = new MockHttpServletResponse();

        filter.doFilter(basic("admin", "x"), res, chain);

        assertEquals(503, res.getStatus());
        verify(chain, never()).doFilter(any(), any());
    }

    @Test
    void failClosedCanBeSwitchedOffForRedislessTests() throws Exception {
        BasicAuthThrottleFilter open = new BasicAuthThrottleFilter(limiter, new ClientIp("10.0.0.0/8"), redis, false);
        doThrow(new IllegalStateException("redis down")).when(limiter).check(anyString(), anyInt(), any());
        FilterChain chain = mock(FilterChain.class);

        open.doFilter(basic("admin", "x"), new MockHttpServletResponse(), chain);

        verify(chain).doFilter(any(), any());
    }

    @Test
    void successfulLoginClearsIpFailureCounter() throws Exception {
        FilterChain ok = (rq, rs) -> ((MockHttpServletResponse) rs).setStatus(200);

        filter.doFilter(basic("admin", "dogru"), new MockHttpServletResponse(), ok);

        verify(redis).delete("adminbasic:fail:ip:203.0.113.9");
    }

    @Test
    void usernameParsingNeverExposesThePassword() {
        String h = "Basic " + Base64.getEncoder().encodeToString("Admin:pw".getBytes(StandardCharsets.UTF_8));
        assertEquals("admin", BasicAuthThrottleFilter.username(h));
        assertFalse(BasicAuthThrottleFilter.username(h).contains("pw"));
    }
}
