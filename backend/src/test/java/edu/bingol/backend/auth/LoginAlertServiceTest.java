package edu.bingol.backend.auth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.accessban.ClientContext;
import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.notification.Device;
import edu.bingol.backend.notification.DeviceRepository;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.user.User;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

/** Yeni cihaz / oturum baska cihazda / sifre degisti guvenlik bildirimleri (tasarim 07). */
class LoginAlertServiceTest {

    private final NotificationService notifications = mock(NotificationService.class);
    private final DeviceRepository devices = mock(DeviceRepository.class);
    private final I18n i18n = mock(I18n.class);
    private LoginAlertService alerts;
    private User user;

    @BeforeEach
    void setUp() {
        alerts = new LoginAlertService(notifications, devices, i18n,
                Clock.fixed(Instant.parse("2026-11-02T06:41:00Z"), ZoneOffset.UTC)); // Istanbul 09:41
        user = new User();
        user.setId(5L);
        user.setLanguage("tr");
        when(i18n.msg(anyString(), any(Lang.class))).thenAnswer(i -> i.getArgument(0));
        when(i18n.msg(anyString(), any(Lang.class), any(Object[].class))).thenAnswer(i -> {
            Object[] a = i.getArguments();
            StringBuilder sb = new StringBuilder((String) a[0]);
            for (int k = 2; k < a.length; k++) {
                Object v = a[k];
                if (v instanceof Object[] arr) {
                    for (Object o : arr) sb.append('|').append(o);
                } else {
                    sb.append('|').append(v);
                }
            }
            return sb.toString();
        });
    }

    private static Device dev(String token) {
        Device d = new Device();
        d.setFcmToken(token);
        d.setPlatform("ANDROID");
        return d;
    }

    private static ClientContext ctx(String platform, String model) {
        return new ClientContext("1.2.3.4", "hash", platform, "2.0.8", model);
    }

    @Test
    void newDeviceMobileLoginAlertsOldTokensWithModelAndTimeButNoIpOrCity() {
        List<Device> old = List.of(dev("old-token"));
        alerts.afterLogin(user, ctx("ANDROID", "Samsung Galaxy S24"), true, true, true, old);

        ArgumentCaptor<String> body = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<Map<String, String>> data = ArgumentCaptor.forClass(Map.class);
        verify(notifications).sendSecurity(eq(5L), eq("notif.security.newdevice.title"), body.capture(), data.capture(),
                eq(old));
        assertEquals("notif.security.newdevice.body|Samsung Galaxy S24|09:41", body.getValue());
        assertEquals("SECURITY_NEW_DEVICE", data.getValue().get("card"));
        assertEquals(false, body.getValue().contains("1.2.3.4"));
    }

    @Test
    void sessionReplacedOnSameKnownDeviceUsesPlatformAndNeverDuplicatesNewDeviceAlert() {
        List<Device> old = List.of(dev("old-token"));
        alerts.afterLogin(user, ctx("IOS", null), true, false, true, old);
        verify(notifications).sendSecurity(eq(5L), eq("notif.security.session.title"),
                eq("notif.security.session.body|iOS"), anyMap(), eq(old));
        // tek bildirim: yeni cihaz + oturum degisimi birlikte ise yalniz yeni cihaz uyarisi gider
        alerts.afterLogin(user, ctx("IOS", null), true, true, true, old);
        verify(notifications, org.mockito.Mockito.times(1)).sendSecurity(anyLong(), eq("notif.security.session.title"),
                anyString(), anyMap(), anyCollection());
    }

    @Test
    void firstLoginOrKnownDeviceWithoutOtherSessionSendsNothing() {
        alerts.afterLogin(user, ctx("ANDROID", null), true, false, false, List.of());
        verify(notifications, never()).sendSecurity(anyLong(), anyString(), anyString(), anyMap(), any());
    }

    @Test
    void webLoginFromNewDeviceAlertsCurrentMobileDevices() {
        alerts.afterLogin(user, ctx("WEB", null), false, true, false, List.of());
        verify(notifications).sendSecurity(eq(5L), eq("notif.security.newdevice.title"),
                eq("notif.security.newdevice.body|Web|09:41"), anyMap(), org.mockito.ArgumentMatchers.isNull());
    }

    @Test
    void passwordChangedGoesToSnapshotTokensAndNeverBreaksTheFlow() {
        List<Device> all = List.of(dev("t1"), dev("t2"));
        alerts.passwordChanged(user, all);
        verify(notifications).sendSecurity(eq(5L), eq("notif.security.password.title"),
                eq("notif.security.password.body"), anyMap(), eq(all));
        doThrow(new IllegalStateException("boom")).when(notifications)
                .sendSecurity(anyLong(), anyString(), anyString(), anyMap(), any());
        alerts.passwordChanged(user, List.of()); // istisna sizmaz
        alerts.afterLogin(user, ctx("ANDROID", null), true, true, true, List.of());
    }

    @Test
    void snapshotReadsCurrentDevicesAndSurvivesErrors() {
        Device d = dev("tok-1");
        when(devices.findByUserId(5L)).thenReturn(List.of(d));
        assertEquals(List.of(d), alerts.snapshotDevices(5L));
        when(devices.findByUserId(6L)).thenThrow(new IllegalStateException("db"));
        assertEquals(List.of(), alerts.snapshotDevices(6L));
    }

    @Test
    void deviceLabelPrefersModelThenPlatform() {
        assertEquals("Pixel 8", LoginAlertService.deviceLabel(ctx("ANDROID", "Pixel 8")));
        assertEquals("Android", LoginAlertService.deviceLabel(ctx("ANDROID", null)));
        assertEquals("?", LoginAlertService.deviceLabel(ctx("UNKNOWN", " ")));
        assertEquals("?", LoginAlertService.deviceLabel(null));
    }
}
