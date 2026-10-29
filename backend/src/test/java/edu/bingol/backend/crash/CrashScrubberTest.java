package edu.bingol.backend.crash;

import static org.assertj.core.api.Assertions.assertThat;

import edu.bingol.backend.admin.rbac.AdminPermissionPolicy;
import edu.bingol.backend.admin.rbac.AdminProfile;
import edu.bingol.backend.admin.rbac.PermissionMatrix;
import java.time.Instant;
import org.junit.jupiter.api.Test;

/** Cokme raporu saf mantigi: maskeleme, imza, surum karsilastirma, yeniden acma, izin eslemesi. */
class CrashScrubberTest {

    @Test
    void masksEmailsTokensQueriesAndHomeDirs() {
        String raw = "Exception: kullanici ali.veli@bingol.edu.tr giris yapamadi\n"
                + "#0 fetch (package:bu_kampus/core/api.dart:42:7) https://api.bingol.edu.tr/api/x?token=abc123&e=a@b.com\n"
                + "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NSJ9.sig_value_here\n"
                + "path C:\\Users\\Toprak\\AppData\\app.dart and /Users/ayse/dev/app.dart and /home/can/x\n"
                + "ogrenci 226051015 ve tel 5321234567; id 123e4567-e89b-12d3-a456-426614174000\n"
                + "key a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8";
        String out = CrashScrubber.stack(raw);
        assertThat(out).doesNotContain("ali.veli", "a@b.com", "abc123", "Toprak", "ayse", "/home/can", "226051015",
                "5321234567", "123e4567", "eyJhbGci", "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8");
        assertThat(out).contains("[eposta]", "?[gizli]", "[kullanici]", "[sayi]", "[uuid]", "[gizli]");
        // dosya yolu ve satir/sutun korunur
        assertThat(out).contains("package:bu_kampus/core/api.dart:42:7");
    }

    @Test
    void keepsLongIdentifiersWithoutDigits() {
        String out = CrashScrubber.stack("#0 _handleSubmittedLoginFormValuesCorrectlyNow (package:bu_kampus/a.dart:1:1)");
        assertThat(out).contains("_handleSubmittedLoginFormValuesCorrectlyNow");
    }

    @Test
    void stackIsBounded() {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < 500; i++) {
            sb.append("#").append(i).append(" frame").append(i).append(" (package:x/y.dart:1:1)\n");
        }
        String out = CrashScrubber.stack(sb.toString());
        assertThat(out.split("\n").length).isLessThanOrEqualTo(CrashScrubber.MAX_STACK_LINES);
        assertThat(out.length()).isLessThanOrEqualTo(CrashScrubber.MAX_STACK_CHARS);
        assertThat(CrashScrubber.text("   ", 10)).isNull();
        assertThat(CrashScrubber.text("a\nb\tc", 10)).isEqualTo("a b c");
    }

    @Test
    void signatureIgnoresLineNumbersAddressesAndIndexes() {
        String a = "#0      Foo.bar (package:bu_kampus/a.dart:10:5)\n#1      baz (package:bu_kampus/b.dart:7:1)\n<asynchronous suspension>";
        String b = "#0      Foo.bar (package:bu_kampus/a.dart:99:2)\n#1      baz (package:bu_kampus/b.dart:70:9)\n<asynchronous suspension>";
        String c = "#0      Foo.other (package:bu_kampus/a.dart:10:5)\n#1      baz (package:bu_kampus/b.dart:7:1)";
        assertThat(CrashScrubber.signature("StateError", a)).isEqualTo(CrashScrubber.signature("StateError", b));
        assertThat(CrashScrubber.signature("StateError", a)).isNotEqualTo(CrashScrubber.signature("StateError", c));
        assertThat(CrashScrubber.signature("StateError", a)).isNotEqualTo(CrashScrubber.signature("TypeError", a));
        assertThat(CrashScrubber.signature("StateError", a)).hasSize(64);
    }

    @Test
    void topFrameSkipsIndexAndNoise() {
        assertThat(CrashScrubber.topFrame("Exception: x\n#0      Foo.bar (package:bu_kampus/a.dart:10:5)"))
                .isEqualTo("Foo.bar (package:bu_kampus/a.dart:10:5)");
        assertThat(CrashScrubber.topFrame("hic kare yok")).isNull();
    }

    @Test
    void versionComparison() {
        assertThat(CrashScrubber.compareVersions("1.2.10", "1.2.9")).isPositive();
        assertThat(CrashScrubber.compareVersions("1.2", "1.2.0")).isZero();
        assertThat(CrashScrubber.compareVersions("1.0.0+5", "1.0.0")).isZero();
        assertThat(CrashScrubber.compareVersions("1.0.9", "1.1.0")).isNegative();
        assertThat(CrashScrubber.compareVersions("2.0.0-beta", "1.9.9")).isPositive();
    }

    @Test
    void reopenRules() {
        // duzeltme surumu bildirildi: o surum ve sonrasi acar
        assertThat(CrashService.shouldReopen("1.3.0", "1.3.0", "1.2.0")).isTrue();
        assertThat(CrashService.shouldReopen("1.2.5", "1.3.0", "1.2.0")).isFalse();
        // bildirilmedi: cozuldugu surumden YENI surum acar, ayni/eski acmaz
        assertThat(CrashService.shouldReopen("1.2.1", null, "1.2.0")).isTrue();
        assertThat(CrashService.shouldReopen("1.2.0", null, "1.2.0")).isFalse();
        assertThat(CrashService.shouldReopen("1.1.0", null, "1.2.0")).isFalse();
        assertThat(CrashService.shouldReopen("1.1.0", null, null)).isFalse();
    }

    @Test
    void platformAndOccurredAtNormalization() {
        assertThat(CrashService.platform("android")).isEqualTo("ANDROID");
        assertThat(CrashService.platform("iOS")).isEqualTo("IOS");
        assertThat(CrashService.platform("windows")).isEqualTo("OTHER");
        assertThat(CrashService.platform(null)).isEqualTo("OTHER");
        Instant now = Instant.parse("2026-10-29T10:00:00Z");
        assertThat(CrashService.occurredAt(null, now)).isEqualTo(now);
        assertThat(CrashService.occurredAt(now.plusSeconds(3600), now)).isEqualTo(now);
        assertThat(CrashService.occurredAt(now.minusSeconds(86400L * 40), now)).isEqualTo(now);
        assertThat(CrashService.occurredAt(now.minusSeconds(60), now)).isEqualTo(now.minusSeconds(60));
    }

    @Test
    void adminEndpointsMapToSystemPermissions() {
        assertThat(AdminPermissionPolicy.explicit("GET", "/api/admin/crashes")).contains(PermissionMatrix.SYSTEM_READ);
        assertThat(AdminPermissionPolicy.explicit("GET", "/api/admin/crashes/7")).contains(PermissionMatrix.SYSTEM_READ);
        assertThat(AdminPermissionPolicy.explicit("PATCH", "/api/admin/crashes/7/status"))
                .contains(PermissionMatrix.SYSTEM_WRITE);
        assertThat(AdminPermissionPolicy.explicit("DELETE", "/api/admin/crashes/7")).contains(PermissionMatrix.SYSTEM_WRITE);
        // VIEWER okur, yazamaz; SUPPORT hic goremez
        assertThat(PermissionMatrix.allows(AdminProfile.VIEWER, PermissionMatrix.SYSTEM_READ)).isTrue();
        assertThat(PermissionMatrix.allows(AdminProfile.VIEWER, PermissionMatrix.SYSTEM_WRITE)).isFalse();
        assertThat(PermissionMatrix.allows(AdminProfile.SUPPORT, PermissionMatrix.SYSTEM_READ)).isFalse();
    }

    @Test
    void escapeLike() {
        assertThat(CrashAdminService.escapeLike("a%b_c\\d")).isEqualTo("a\\%b\\_c\\\\d");
        assertThat(CrashAdminService.requireStatus("ack")).isEqualTo("ACK");
    }
}
