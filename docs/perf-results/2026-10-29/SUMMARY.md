# Yuk testi ozeti

Uretim: 2026-10-29T00:27:27.534Z (klasor: 2026-10-29)

## A-auth-with-load (A-auth-with-load.json)

istek(olcum)=5697, hata orani=0.00%, 429=2207, beklenmeyen hata=0, 503=0, sure=43 sn
genel: p50=10 p95=1850 p99=2416 ms

| uc | n | p50 | p95 | p99 | max | hata | 429 |
|---|---:|---:|---:|---:|---:|---:|---:|
| GET /feed (arka plan) | 1990 | 9 | 110 | 676 | 785 | 0 | 0 |
| GET /me/summary (login sonrasi) | 500 | 5 | 33 | 85 | 100 | 0 | 0 |
| POST /auth/login | 2707 | 32 | 2152 | 2783 | 3111 | 0 | 2207 |
| POST /auth/refresh | 500 | 10 | 71 | 131 | 183 | 0 | 0 |

ek: `{"loginOk":500,"loginGaveUp":null,"e2e_p50":18269,"e2e_p95":32030.399999999983,"e2e_max":33910}`

Kaynaklar: JVM CPU ort 68% maks 93%, heap maks 471 MB, GC duraklama 19 (0.14 sn), is parcacigi maks 225, Hikari aktif maks 5/30, bekleyen maks 0, Hikari zaman asimi 0; bu_ld_app cpu ort 142% maks 201% bellek 1058 MB; bu_ld_pg cpu ort 38% maks 92% bellek 1320 MB; bu_ld_redis cpu ort 4% maks 7% bellek 14 MB

## A-auth (A-auth.json)

istek(olcum)=3581, hata orani=0.00%, 429=2081, beklenmeyen hata=0, 503=0, sure=34 sn
genel: p50=9 p95=1986 p99=2673 ms

| uc | n | p50 | p95 | p99 | max | hata | 429 |
|---|---:|---:|---:|---:|---:|---:|---:|
| GET /feed (arka plan) | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| GET /me/summary (login sonrasi) | 500 | 5 | 9 | 59 | 105 | 0 | 0 |
| POST /auth/login | 2581 | 22 | 2252 | 3032 | 4722 | 0 | 2081 |
| POST /auth/refresh | 500 | 10 | 34 | 81 | 183 | 0 | 0 |

ek: `{"loginOk":500,"loginGaveUp":null,"e2e_p50":18324.5,"e2e_p95":31231,"e2e_max":32594}`

Kaynaklar: JVM CPU ort 67% maks 100%, heap maks 498 MB, GC duraklama 11 (0.08 sn), is parcacigi maks 225, Hikari aktif maks 1/30, bekleyen maks 0, Hikari zaman asimi 0; bu_ld_app cpu ort 129% maks 200% bellek 1055 MB; bu_ld_pg cpu ort 13% maks 26% bellek 1322 MB; bu_ld_redis cpu ort 3% maks 5% bellek 12 MB

## B-read-100 (B-read-100.json)

istek(olcum)=20112, hata orani=0.00%, 429=0, beklenmeyen hata=0, 503=0, sure=254 sn
genel: p50=6 p95=11 p99=15 ms

| uc | n | p50 | p95 | p99 | max | hata | 429 |
|---|---:|---:|---:|---:|---:|---:|---:|
| GET /communities | 509 | 6 | 8 | 10 | 13 | 0 | 0 |
| GET /communities/{id} | 239 | 4 | 5 | 6 | 7 | 0 | 0 |
| GET /conversations | 1506 | 7 | 11 | 13 | 23 | 0 | 0 |
| GET /conversations/unread-count | 1506 | 3 | 5 | 7 | 13 | 0 | 0 |
| GET /conversations/{id}/messages | 1510 | 9 | 14 | 18 | 34 | 0 | 0 |
| GET /events | 727 | 9 | 13 | 17 | 22 | 0 | 0 |
| GET /events/calendar | 290 | 6 | 9 | 12 | 14 | 0 | 0 |
| GET /events/{id} | 373 | 5 | 9 | 12 | 20 | 0 | 0 |
| GET /feed?scope=top (cursor) | 2261 | 7 | 9 | 12 | 25 | 0 | 0 |
| GET /feed?scope=top | 3016 | 7 | 10 | 12 | 19 | 0 | 0 |
| GET /me/summary | 1891 | 5 | 7 | 9 | 18 | 0 | 0 |
| GET /menu/today | 1892 | 2 | 3 | 4 | 8 | 0 | 0 |
| GET /news | 2495 | 4 | 6 | 8 | 10 | 0 | 0 |
| GET /notifications | 757 | 3 | 4 | 6 | 8 | 0 | 0 |
| GET /notifications/unread-count | 757 | 2 | 4 | 5 | 7 | 0 | 0 |
| GET /search | 383 | 11 | 25 | 27 | 31 | 0 | 0 |

Kaynaklar: JVM CPU ort 17% maks 37%, heap maks 521 MB, GC duraklama 75 (0.27 sn), is parcacigi maks 226, Hikari aktif maks 3/30, bekleyen maks 0, Hikari zaman asimi 0; bu_ld_app cpu ort 32% maks 47% bellek 1060 MB; bu_ld_pg cpu ort 21% maks 46% bellek 1418 MB; bu_ld_redis cpu ort 2% maks 4% bellek 15 MB

## B-read-200 (B-read-200.json)

istek(olcum)=39830, hata orani=0.00%, 429=0, beklenmeyen hata=0, 503=0, sure=254 sn
genel: p50=6 p95=13 p99=19 ms

| uc | n | p50 | p95 | p99 | max | hata | 429 |
|---|---:|---:|---:|---:|---:|---:|---:|
| GET /communities | 1021 | 6 | 10 | 14 | 24 | 0 | 0 |
| GET /communities/{id} | 505 | 4 | 6 | 8 | 18 | 0 | 0 |
| GET /conversations | 2939 | 7 | 12 | 17 | 47 | 0 | 0 |
| GET /conversations/unread-count | 2939 | 4 | 6 | 8 | 27 | 0 | 0 |
| GET /conversations/{id}/messages | 2947 | 10 | 18 | 23 | 51 | 0 | 0 |
| GET /events | 1499 | 10 | 16 | 23 | 42 | 0 | 0 |
| GET /events/calendar | 591 | 7 | 12 | 19 | 34 | 0 | 0 |
| GET /events/{id} | 757 | 6 | 11 | 15 | 28 | 0 | 0 |
| GET /feed?scope=top (cursor) | 4597 | 7 | 11 | 16 | 32 | 0 | 0 |
| GET /feed?scope=top | 6010 | 7 | 12 | 16 | 35 | 0 | 0 |
| GET /me/summary | 3721 | 5 | 8 | 11 | 28 | 0 | 0 |
| GET /menu/today | 3721 | 2 | 3 | 5 | 16 | 0 | 0 |
| GET /news | 4959 | 4 | 7 | 9 | 31 | 0 | 0 |
| GET /notifications | 1434 | 3 | 5 | 7 | 11 | 0 | 0 |
| GET /notifications/unread-count | 1434 | 3 | 4 | 7 | 30 | 0 | 0 |
| GET /search | 756 | 12 | 27 | 35 | 53 | 0 | 0 |

Kaynaklar: JVM CPU ort 36% maks 53%, heap maks 520 MB, GC duraklama 160 (0.61 sn), is parcacigi maks 226, Hikari aktif maks 4/30, bekleyen maks 0, Hikari zaman asimi 0; bu_ld_app cpu ort 72% maks 113% bellek 1063 MB; bu_ld_pg cpu ort 43% maks 74% bellek 1361 MB; bu_ld_redis cpu ort 5% maks 6% bellek 15 MB

## B-read-300 (B-read-300.json)

istek(olcum)=97782, hata orani=0.00%, 429=0, beklenmeyen hata=0, 503=0, sure=375 sn
genel: p50=7 p95=58 p99=100 ms

| uc | n | p50 | p95 | p99 | max | hata | 429 |
|---|---:|---:|---:|---:|---:|---:|---:|
| GET /communities | 2622 | 7 | 53 | 86 | 174 | 0 | 0 |
| GET /communities/{id} | 1246 | 4 | 18 | 81 | 186 | 0 | 0 |
| GET /conversations | 7204 | 9 | 60 | 99 | 280 | 0 | 0 |
| GET /conversations/unread-count | 7204 | 4 | 29 | 90 | 293 | 0 | 0 |
| GET /conversations/{id}/messages | 7213 | 14 | 78 | 163 | 407 | 0 | 0 |
| GET /events | 3610 | 12 | 74 | 132 | 390 | 0 | 0 |
| GET /events/calendar | 1468 | 8 | 72 | 95 | 260 | 0 | 0 |
| GET /events/{id} | 1843 | 8 | 74 | 100 | 196 | 0 | 0 |
| GET /feed?scope=top (cursor) | 10946 | 9 | 62 | 100 | 327 | 0 | 0 |
| GET /feed?scope=top | 14704 | 9 | 72 | 109 | 318 | 0 | 0 |
| GET /me/summary | 9243 | 6 | 57 | 102 | 279 | 0 | 0 |
| GET /menu/today | 9243 | 3 | 12 | 71 | 109 | 0 | 0 |
| GET /news | 12128 | 5 | 42 | 81 | 179 | 0 | 0 |
| GET /notifications | 3649 | 4 | 38 | 73 | 156 | 0 | 0 |
| GET /notifications/unread-count | 3649 | 3 | 18 | 85 | 188 | 0 | 0 |
| GET /search | 1810 | 17 | 91 | 172 | 336 | 0 | 0 |

Kaynaklar: JVM CPU ort 67% maks 100%, heap maks 523 MB, GC duraklama 301 (1.55 sn), is parcacigi maks 226, Hikari aktif maks 9/30, bekleyen maks 0, Hikari zaman asimi 0; bu_ld_app cpu ort 133% maks 207% bellek 1060 MB; bu_ld_pg cpu ort 86% maks 169% bellek 1419 MB; bu_ld_redis cpu ort 7% maks 10% bellek 15 MB

## B-read-400 (B-read-400.json)

istek(olcum)=70392, hata orani=0.00%, 429=0, beklenmeyen hata=0, 503=0, sure=255 sn
genel: p50=106 p95=338 p99=584 ms

| uc | n | p50 | p95 | p99 | max | hata | 429 |
|---|---:|---:|---:|---:|---:|---:|---:|
| GET /communities | 1758 | 97 | 263 | 443 | 1398 | 0 | 0 |
| GET /communities/{id} | 899 | 88 | 202 | 302 | 976 | 0 | 0 |
| GET /conversations | 5231 | 123 | 308 | 498 | 1497 | 0 | 0 |
| GET /conversations/unread-count | 5231 | 104 | 314 | 593 | 2099 | 0 | 0 |
| GET /conversations/{id}/messages | 5242 | 189 | 677 | 1442 | 3248 | 0 | 0 |
| GET /events | 2692 | 144 | 354 | 496 | 1255 | 0 | 0 |
| GET /events/calendar | 1140 | 103 | 289 | 398 | 905 | 0 | 0 |
| GET /events/{id} | 1386 | 103 | 294 | 410 | 1520 | 0 | 0 |
| GET /feed?scope=top (cursor) | 7757 | 131 | 329 | 469 | 1301 | 0 | 0 |
| GET /feed?scope=top | 10467 | 123 | 329 | 505 | 1368 | 0 | 0 |
| GET /me/summary | 6606 | 140 | 375 | 549 | 1655 | 0 | 0 |
| GET /menu/today | 6608 | 78 | 189 | 295 | 1282 | 0 | 0 |
| GET /news | 8731 | 88 | 202 | 317 | 1152 | 0 | 0 |
| GET /notifications | 2680 | 75 | 229 | 397 | 1526 | 0 | 0 |
| GET /notifications/unread-count | 2680 | 94 | 274 | 436 | 898 | 0 | 0 |
| GET /search | 1284 | 189 | 512 | 1004 | 1962 | 0 | 0 |

Kaynaklar: JVM CPU ort 81% maks 100%, heap maks 546 MB, GC duraklama 303 (2.94 sn), is parcacigi maks 226, Hikari aktif maks 29/30, bekleyen maks 85, Hikari zaman asimi 0; bu_ld_app cpu ort 163% maks 207% bellek 1098 MB; bu_ld_pg cpu ort 127% maks 196% bellek 1452 MB; bu_ld_redis cpu ort 5% maks 9% bellek 15 MB

## B-stress-400 (B-stress-400.json)

istek(olcum)=70495, hata orani=0.00%, 429=0, beklenmeyen hata=0, 503=0, sure=254 sn
genel: p50=696 p95=1997 p99=3086 ms

| uc | n | p50 | p95 | p99 | max | hata | 429 |
|---|---:|---:|---:|---:|---:|---:|---:|
| GET /communities | 1841 | 626 | 1085 | 1396 | 1901 | 0 | 0 |
| GET /communities/{id} | 875 | 581 | 1015 | 1314 | 1601 | 0 | 0 |
| GET /conversations | 5349 | 679 | 1132 | 1459 | 2205 | 0 | 0 |
| GET /conversations/unread-count | 5356 | 808 | 1492 | 1814 | 2886 | 0 | 0 |
| GET /conversations/{id}/messages | 5388 | 2240 | 3579 | 4234 | 6905 | 0 | 0 |
| GET /events | 2734 | 737 | 1184 | 1531 | 2359 | 0 | 0 |
| GET /events/calendar | 1135 | 614 | 1101 | 1363 | 2082 | 0 | 0 |
| GET /events/{id} | 1400 | 617 | 1106 | 1482 | 2398 | 0 | 0 |
| GET /feed?scope=top (cursor) | 7900 | 688 | 1125 | 1412 | 2133 | 0 | 0 |
| GET /feed?scope=top | 10388 | 700 | 1133 | 1462 | 2476 | 0 | 0 |
| GET /me/summary | 6470 | 737 | 1181 | 1518 | 2491 | 0 | 0 |
| GET /menu/today | 6496 | 516 | 992 | 1280 | 2023 | 0 | 0 |
| GET /news | 8546 | 577 | 1013 | 1299 | 2393 | 0 | 0 |
| GET /notifications | 2666 | 672 | 1260 | 1665 | 2179 | 0 | 0 |
| GET /notifications/unread-count | 2666 | 604 | 1071 | 1378 | 1924 | 0 | 0 |
| GET /search | 1285 | 1131 | 1976 | 2453 | 3109 | 0 | 0 |

Kaynaklar: JVM CPU ort 97% maks 100%, heap maks 544 MB, GC duraklama 425 (5.42 sn), is parcacigi maks 225, Hikari aktif maks 30/30, bekleyen maks 150, Hikari zaman asimi 0; bu_ld_app cpu ort 197% maks 207% bellek 1101 MB; bu_ld_pg cpu ort 158% maks 203% bellek 1761 MB; bu_ld_redis cpu ort 4% maks 9% bellek 15 MB

## C1-write (C1-write.json)

istek(olcum)=40857, hata orani=0.00%, 429=0, beklenmeyen hata=0, 503=0, sure=372 sn
genel: p50=14 p95=31 p99=71 ms

| uc | n | p50 | p95 | p99 | max | hata | 429 |
|---|---:|---:|---:|---:|---:|---:|---:|
| DELETE /posts/{id}/like | 2723 | 7 | 12 | 28 | 84 | 0 | 0 |
| DELETE /users/{id}/follow | 1693 | 6 | 11 | 23 | 77 | 0 | 0 |
| POST /conversations/{id}/messages | 14568 | 18 | 39 | 85 | 186 | 0 | 0 |
| POST /users/{id}/follow | 5476 | 13 | 28 | 66 | 120 | 0 | 0 |
| PUT /events/{id}/rsvp | 7390 | 9 | 18 | 50 | 89 | 0 | 0 |
| PUT /posts/{id}/like | 9007 | 14 | 27 | 66 | 156 | 0 | 0 |

Kaynaklar: JVM CPU ort 54% maks 95%, heap maks 552 MB, GC duraklama 311 (1.26 sn), is parcacigi maks 227, Hikari aktif maks 17/30, bekleyen maks 0, Hikari zaman asimi 0; bu_ld_app cpu ort 107% maks 177% bellek 1107 MB; bu_ld_pg cpu ort 59% maks 126% bellek 1785 MB; bu_ld_redis cpu ort 6% maks 8% bellek 15 MB

## C2-race (C2-race.json)

istek(olcum)=500, hata orani=0.00%, 429=0, beklenmeyen hata=0, 503=0, sure=21 sn
genel: p50=1354 p95=2362 p99=2486 ms

| uc | n | p50 | p95 | p99 | max | hata | 429 |
|---|---:|---:|---:|---:|---:|---:|---:|
| POST /polls/{id}/vote (cift) | 100 | 608 | 804 | 835 | 839 | 0 | 0 |
| POST /polls/{id}/vote (yaris) | 300 | 1792 | 2373 | 2514 | 2526 | 0 | 0 |
| PUT /events/{id}/rsvp (yaris) | 100 | 183 | 213 | 219 | 220 | 0 | 0 |

ek: `{"eventOk":10,"eventFull":90,"eventOther":0,"voteOk":400,"voteOther":0}`

Kaynaklar: JVM CPU ort 10% maks 48%, heap maks 540 MB, GC duraklama 4 (0.04 sn), is parcacigi maks 227, Hikari aktif maks 30/30, bekleyen maks 131, Hikari zaman asimi 0; bu_ld_app cpu ort 29% maks 63% bellek 1109 MB; bu_ld_pg cpu ort 35% maks 99% bellek 1753 MB; bu_ld_redis cpu ort 1% maks 2% bellek 16 MB

## E-admin (E-admin.json)

istek(olcum)=722, hata orani=0.00%, 429=0, beklenmeyen hata=0, 503=0, sure=252 sn
genel: p50=12 p95=461 p99=780 ms

| uc | n | p50 | p95 | p99 | max | hata | 429 |
|---|---:|---:|---:|---:|---:|---:|---:|
| GET /admin/analytics/active-users | 48 | 54 | 104 | 112 | 114 | 0 | 0 |
| GET /admin/analytics/content | 35 | 5 | 8 | 23 | 30 | 0 | 0 |
| GET /admin/analytics/engagement | 72 | 460 | 1134 | 1484 | 1513 | 0 | 0 |
| GET /admin/analytics/overview | 47 | 82 | 166 | 337 | 469 | 0 | 0 |
| GET /admin/analytics/retention | 45 | 31 | 63 | 89 | 93 | 0 | 0 |
| GET /admin/audit (derin sayfa) | 30 | 18 | 22 | 23 | 24 | 0 | 0 |
| GET /admin/audit | 113 | 12 | 25 | 66 | 79 | 0 | 0 |
| GET /admin/reports | 45 | 3 | 4 | 6 | 7 | 0 | 0 |
| GET /admin/users (derin sayfa) | 44 | 11 | 17 | 58 | 71 | 0 | 0 |
| GET /admin/users | 150 | 6 | 19 | 57 | 64 | 0 | 0 |
| GET /admin/users?q= | 93 | 10 | 18 | 31 | 54 | 0 | 0 |

CSV disa aktarma: p50=122 ms, p95=230 ms, max=285 ms, ort. 4188768 bayt, ~35002 satir, hata=null

Kaynaklar: JVM CPU ort 3% maks 14%, heap maks 677 MB, GC duraklama 8 (0.14 sn), is parcacigi maks 233, Hikari aktif maks 2/30, bekleyen maks 0, Hikari zaman asimi 0; bu_ld_app cpu ort 4% maks 27% bellek 1345 MB; bu_ld_pg cpu ort 34% maks 125% bellek 1762 MB; bu_ld_redis cpu ort 0% maks 1% bellek 16 MB

## G-endpoints (G-endpoints.json)

istek(olcum)=55928, hata orani=0.00%, 429=0, beklenmeyen hata=0, 503=0, sure=213 sn
genel: p50=95 p95=206 p99=385 ms

| uc | n | p50 | p95 | p99 | max | hata | 429 | RPS |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| EP communities | 6020 | 91 | 112 | 185 | 206 | 0 | 0 | 401.3 |
| EP conversation messages | 1526 | 194 | 295 | 360 | 397 | 0 | 0 | 101.7 |
| EP conversations | 2944 | 183 | 286 | 302 | 484 | 0 | 0 | 196.3 |
| EP conversations/unread-count | 6613 | 89 | 102 | 174 | 196 | 0 | 0 | 440.9 |
| EP events | 2860 | 185 | 292 | 312 | 404 | 0 | 0 | 190.7 |
| EP events/calendar | 3825 | 108 | 200 | 273 | 375 | 0 | 0 | 255 |
| EP feed top | 2918 | 182 | 226 | 288 | 390 | 0 | 0 | 194.5 |
| EP me/summary | 4434 | 102 | 182 | 191 | 274 | 0 | 0 | 295.6 |
| EP menu/today | 7269 | 88 | 101 | 113 | 286 | 0 | 0 | 484.6 |
| EP news list | 5316 | 95 | 177 | 189 | 300 | 0 | 0 | 354.4 |
| EP notifications | 9277 | 77 | 95 | 102 | 186 | 0 | 0 | 618.5 |
| EP search | 1400 | 299 | 692 | 802 | 1008 | 0 | 0 | 93.3 |

Kaynaklar: JVM CPU ort 80% maks 100%, heap maks 508 MB, GC duraklama 103 (1.15 sn), is parcacigi maks 132, Hikari aktif maks 30/30, bekleyen maks 5, Hikari zaman asimi 0; bu_ld_app cpu ort 158% maks 211% bellek 1034 MB; bu_ld_pg cpu ort 104% maks 203% bellek 1331 MB; bu_ld_redis cpu ort 4% maks 7% bellek 12 MB

## H-cold (H-cold.json)

istek(olcum)=24723, hata orani=0.00%, 429=0, beklenmeyen hata=0, 503=0, sure=255 sn
genel: p50=460 p95=1410 p99=2226 ms

| uc | n | p50 | p95 | p99 | max | hata | 429 |
|---|---:|---:|---:|---:|---:|---:|---:|
| GET /communities | 659 | 364 | 1030 | 1370 | 1811 | 0 | 0 |
| GET /communities/{id} | 325 | 299 | 790 | 1004 | 1098 | 0 | 0 |
| GET /conversations | 1836 | 476 | 1280 | 1874 | 2739 | 0 | 0 |
| GET /conversations/unread-count | 1836 | 487 | 1495 | 2165 | 3996 | 0 | 0 |
| GET /conversations/{id}/messages | 1836 | 733 | 2054 | 2912 | 4360 | 0 | 0 |
| GET /events | 970 | 585 | 1416 | 2037 | 2574 | 0 | 0 |
| GET /events/calendar | 400 | 396 | 910 | 1294 | 2307 | 0 | 0 |
| GET /events/{id} | 495 | 403 | 1138 | 1592 | 1706 | 0 | 0 |
| GET /feed?scope=top (cursor) | 2732 | 482 | 1373 | 1981 | 3125 | 0 | 0 |
| GET /feed?scope=top | 3688 | 537 | 1612 | 2319 | 3711 | 0 | 0 |
| GET /me/summary | 2322 | 626 | 1955 | 2885 | 4281 | 0 | 0 |
| GET /menu/today | 2322 | 211 | 702 | 1110 | 1689 | 0 | 0 |
| GET /news | 3011 | 293 | 822 | 1197 | 2400 | 0 | 0 |
| GET /notifications | 914 | 319 | 958 | 1382 | 2327 | 0 | 0 |
| GET /notifications/unread-count | 914 | 399 | 1301 | 1796 | 2300 | 0 | 0 |
| GET /search | 463 | 624 | 1660 | 2604 | 5384 | 0 | 0 |

Kaynaklar: JVM CPU ort 95% maks 100%, heap maks 556 MB, GC duraklama 55 (0.79 sn), is parcacigi maks 154, Hikari aktif maks 29/30, bekleyen maks 11, Hikari zaman asimi 0; bu_ld_app cpu ort 193% maks 209% bellek 1050 MB; bu_ld_pg cpu ort 68% maks 156% bellek 1734 MB; bu_ld_redis cpu ort 2% maks 3% bellek 25 MB

## D-ws

```json
{
 "scenario": "D-ws",
 "at": "2026-10-29T00:12:58.026Z",
 "vus": 1000,
 "holdSeconds": 90,
 "sendEverySeconds": 10,
 "connect": {
  "p50": 5,
  "p95": 10,
  "max": 257,
  "fail": 0
 },
 "deliver": {
  "p50": 13,
  "p95": 23,
  "p99": 34,
  "max": 96
 },
 "ack": {
  "p50": 13,
  "p95": 24,
  "p99": 35
 },
 "sent": 4000,
 "delivered": 4000,
 "acks": 3653,
 "errors": null,
 "closedEarly": null,
 "presence": null
}
```

## integrity.txt

```
== veri butunlugu ==
Output format is aligned.
                 kontrol                 | ihlal 
-----------------------------------------+-------
 kapasite yarisi: going_count > capacity |     0
(1 row)

                                 kontrol                                  | ihlal 
--------------------------------------------------------------------------+-------
 kapasite yarisi: GOING RSVP sayisi != going_count (tum ldx etkinlikleri) |     0
(1 row)

                      kontrol                      |  ihlal  
---------------------------------------------------+---------
 kapasite yarisi etkinligi: dolu koltuk / kapasite | 100/100
(1 row)

               kontrol               | ihlal 
-------------------------------------+-------
 anket: voter_count != ballot sayisi |     0
(1 row)

                        kontrol                         | ihlal 
--------------------------------------------------------+-------
 anket: secenek oy toplami != poll_vote satiri (SINGLE) |     0
(1 row)

                        kontrol                         | ihlal 
--------------------------------------------------------+-------
 anket: ayni kullanici ayni ankette birden fazla ballot |     0
(1 row)

                              kontrol                               | ihlal 
--------------------------------------------------------------------+-------
 anket: ayni kullanici ayni ankette (SINGLE) birden fazla oy satiri |     0
(1 row)

                kontrol                 | ihlal 
----------------------------------------+-------
 begeni: like_count != post_like satiri |     0
(1 row)

                   kontrol                   | ihlal 
---------------------------------------------+-------
 takip: follower_count != user_follow satiri |     0
(1 row)

                   kontrol                    | ihlal 
----------------------------------------------+-------
 takip: following_count != user_follow satiri |     0
(1 row)

                      kontrol                      | ihlal 
---------------------------------------------------+-------
 mesaj: ayni (konusma, gonderen, client_id) tekrar |     0
(1 row)

                           kontrol                           | ihlal 
-------------------------------------------------------------+-------
 mesaj: konusma last_message_id geride (yuk testi mesajlari) |     0
(1 row)
```

## F-chaos.log

```
uygulama baslangic/restart (once): 2026-10-28T23:26:37.131243174Z 0
== F1: lock_timeout (notification tablosu 12 sn ACCESS EXCLUSIVE)
http=503 sure=3.006954s
govde: {"message":"Sistem şu an yoğun. Lütfen birkaç saniye sonra tekrar deneyin.","code":"DB_TIMEOUT","traceId":"0a5c633e-7b95-4424-8f2d-ee2e08ddc6b9"}
(beklenen: ~3 sn sonra 503/hata; 12 sn takili kalma = lock_timeout calismiyor)
== F2: veritabani 5 sn donar (docker pause)
pg PAUSE 03:18:33
pg UNPAUSE 03:18:38
F2 prob zaman cizelgesi (saat kod sure govde):
03:18:25 200 0.007028 {"communities":1,"events":2,"bookmarks":0,"unreadNotifications":19,"unreadMessages":9}
03:18:26 200 0.004956 {"communities":1,"events":2,"bookmarks":0,"unreadNotifications":19,"unreadMessages":9}
03:18:28 200 0.007498 {"communities":1,"events":2,"bookmarks":0,"unreadNotifications":19,"unreadMessages":9}
03:18:29 200 0.005655 {"communities":1,"events":2,"bookmarks":0,"unreadNotifications":19,"unreadMessages":9}
03:18:30 200 0.009200 {"communities":1,"events":2,"bookmarks":0,"unreadNotifications":19,"unreadMessages":9}
03:18:31 200 0.006109 {"communities":1,"events":2,"bookmarks":0,"unreadNotifications":19,"unreadMessages":9}
03:18:32 200 0.006694 {"communities":1,"events":2,"bookmarks":0,"unreadNotifications":19,"unreadMessages":9}
03:18:38 200 4.846645 {"communities":1,"events":2,"bookmarks":0,"unreadNotifications":19,"unreadMessages":9}
03:18:40 200 0.006113 {"communities":1,"events":2,"bookmarks":0,"unreadNotifications":19,"unreadMessages":9}
03:18:41 200 0.005112 {"communities":1,"events":2,"bookmarks":0,"unreadNotifications":19,"unreadMessages":9}
03:18:42 200 0.005189 {"communities":1,"events":2,"bookmarks":0,"unreadNotifications":19,"unreadMessages":9}
03:18:43 200 0.004874 {"communities":1,"events":2,"bookmarks":0,"unreadNotifications":19,"unreadMessages":9}
03:18:44 200 0.006104 {"communities":1,"events":2,"bookmarks":0,"unreadNotifications":19,"unreadMessages":9}
03:18:46 200 0.004911 {"communities":1,"events":2,"bookmarks":0,"unreadNotifications":19,"unreadMessages":9}
03:18:47 200 0.006905 {"communities":1,"events":2,"bookmarks":0,"unreadNotifications":19,"unreadMessages":9}
03:18:48 200 0.004912 {"communities":1,"events":2,"bookmarks":0,"unreadNotifications":19,"unreadMessages":9}
03:18:49 200 0.005341 {"communities":1,"events":2,"bookmarks":0,"unreadNotifications":19,"unreadMessages":9}
03:18:50 200 0.007903 {"communities":1,"events":2,"bookmarks":0,"unreadNotifications":19,"unreadMessages":9}
03:18:52 200 0.008664 {"communities":1,"events":2,"bookmarks":0,"unreadNotifications":19,"unreadMessages":9}
03:18:53 200 0.007721 {"communities":1,"events":2,"bookmarks":0,"unreadNotifications":19,"unreadMessages":9}
03:18:54 200 0.005179 {"communities":1,"events":2,"bookmarks":0,"unreadNotifications":19,"unreadMessages":9}
== F2b: veritabani 36 sn donar (JDBC socketTimeout=30 sn: istek ~30 sn sonra 503 DB_TIMEOUT ile bitmeli, sonsuz beklememeli)
pg PAUSE 03:19:07
pg UNPAUSE 03:19:43
03:19:01 200 0.007093
03:19:02 200 0.006273
03:19:03 200 0.010859
03:19:05 200 0.008351
03:19:06 200 0.005370
03:19:12 500 5.014239
03:19:18 500 5.010786
03:19:24 500 5.007614
03:19:31 500 5.007747
03:19:37 500 5.006361
03:19:43 500 5.013042
03:19:44 200 0.009850
03:19:46 200 0.005078
03:19:47 200 0.008401
03:19:48 200 0.005931
03:19:49 200 0.005392
03:19:50 200 0.004538
03:19:52 200 0.004421
03:19:53 200 0.005722
03:19:54 200 0.005584
03:19:55 200 0.007074
03:19:56 200 0.010614
03:19:58 200 0.007158
03:19:59 200 0.006439
03:20:00 200 0.005134
03:20:01 200 0.005198
03:20:02 200 0.008609
03:20:04 200 0.005307
03:20:05 200 0.005654
03:20:06 200 0.004596
03:20:07 200 0.005026
03:20:09 200 0.007653
03:20:10 200 0.007570
== F3: Redis 5 sn donar
redis PAUSE 03:20:27
redis UNPAUSE 03:20:33
03:20:21 200 0.006856 {"communities":1,"events":2,"bookmarks":0,"unreadNotifications":19,"unreadMessages":9}
03:20:22 200 0.005907 {"communities":1,"events":2,"bookmarks":0,"unreadNotifications":19,"unreadMessages":9}
03:20:24 200 0.008456 {"communities":1,"events":2,"bookmarks":0,"unreadNotifications":19,"unreadMessages":9}
03:20:25 200 0.006100 {"communities":1,"events":2,"bookmarks":0,"unreadNotifications":19,"unreadMessages":9}
03:20:26 200 0.007695 {"communities":1,"events":2,"bookmarks":0,"unreadNotifications":19,"unreadMessages":9}
03:20:33 200 5.551045 {"communities":1,"events":2,"bookmarks":0,"unreadNotifications":19,"unreadMessages":9}
03:20:34 200 0.009109 {"communities":1,"events":2,"bookmarks":0,"unreadNotifications":19,"unreadMessages":9}
03:20:36 200 0.005579 {"communities":1,"events":2,"bookmarks":0,"unreadNotifications":19,"unreadMessages":9}
03:20:37 200 0.004723 {"communities":1,"events":2,"bookmarks":0,"unreadNotifications":19,"unreadMessages":9}
03:20:38 200 0.007974 {"communities":1,"events":2,"bookmarks":0,"unreadNotifications":19,"unreadMessages":9}
03:20:39 200 0.004943 {"communities":1,"events":2,"bookmarks":0,"unreadNotifications":19,"unreadMessages":9}
03:20:40 200 0.004988 {"communities":1,"events":2,"bookmarks":0,"unreadNotifications":19,"unreadMessages":9}
03:20:42 200 0.006082 {"communities":1,"events":2,"bookmarks":0,"unreadNotifications":19,"unreadMessages":9}
03:20:43 200 0.008125 {"communities":1,"events":2,"bookmarks":0,"unreadNotifications":19,"unreadMessages":9}
03:20:44 200 0.005287 {"communities":1,"events":2,"bookmarks":0,"unreadNotifications":19,"unreadMessages":9}
03:20:45 200 0.005955 {"communities":1,"events":2,"bookmarks":0,"unreadNotifications":19,"unreadMessages":9}
uygulama baslangic/restart (sonra): 2026-10-28T23:26:37.131243174Z 0
SUREC CALISMAYA DEVAM ETTI (yeniden baslama yok)
{"groups":["liveness","readiness"],"status":"UP"}
GET /notifications                     915       4    3006    5004   29999     43      0
GET /notifications/unread-count        915       3     181    5003    9848     35      0
GET /search                            463      12     857   21082   29999      2      0
time="2026-10-29T00:22:21Z" level=error msg="thresholds on metrics 'http_req_duration{phase:main,name:GET /events}, http_req_duration{phase:main,name:GET /me/summary}, http_req_duration{phase:main,name:GET /notifications}, http_req_duration{phase:main,name:GET /search}, http_req_failed{phase:main,name:GET /communities/{id}}, http_req_failed{phase:main,name:GET /communities}, http_req_failed{phase:main,name:GET /conversations/unread-count}, http_req_failed{phase:main,name:GET /conversations}, http_req_failed{phase:main,name:GET /events/calendar}, http_req_failed{phase:main,name:GET /events/{id}}, http_req_failed{phase:main,name:GET /events}, http_req_failed{phase:main,name:GET /feed?scope=top}, http_req_failed{phase:main,name:GET /me/summary}, http_req_failed{phase:main,name:GET /menu/today}, http_req_failed{phase:main,name:GET /news}, http_req_failed{phase:main,name:GET /notifications/unread-count}, http_req_failed{phase:main,name:GET /notifications}, http_req_failed{phase:main}' have been crossed"
[F-chaos-bg] k6 cikis kodu=99; kaynak ozeti: {"samples":60,"appCpuAvgPct":19.576113610738613,"appCpuMaxPct":38.54166666666667,"heapMaxMb":726.3818283081055,"threadsMax":225,"hikActiveMax":30,"hikPendingMax":89,"hikMax":30,"hikTimeoutsEnd":505,"gcPauses":24,"gcPauseSec":0.18299999999999983,"containers":{"bu_ld_app":{"cpuAvgPct":37.26383333333333,"cpuMaxPct":74.8,"memMaxMb":1350.656},"bu_ld_pg":{"cpuAvgPct":23.288333333333334,"cpuMaxPct":94.95,"memMaxMb":1617.92},"bu_ld_redis":{"cpuAvgPct":2.3551666666666673,"cpuMaxPct":4.05,"memMaxMb":24.85}}}
```

## Kaynak ozetleri (tum kosular)

| kosu | JVM CPU ort/maks % | heap maks MB | Hikari aktif/bekleyen maks | pg CPU ort % (2 CPU=200) | app CPU ort % (200) |
|---|---:|---:|---:|---:|---:|
| A-auth-with-load | 68/93 | 471 | 5/0 | 38 | 142 |
| A-auth | 67/100 | 498 | 1/0 | 13 | 129 |
| B-read-100 | 17/37 | 521 | 3/0 | 21 | 32 |
| B-read-200 | 36/53 | 520 | 4/0 | 43 | 72 |
| B-read-300 | 67/100 | 523 | 9/0 | 86 | 133 |
| B-read-400 | 81/100 | 546 | 29/85 | 127 | 163 |
| B-stress-400 | 97/100 | 544 | 30/150 | 158 | 197 |
| C1-write | 54/95 | 552 | 17/0 | 59 | 107 |
| C2-race | 10/48 | 540 | 30/131 | 35 | 29 |
| D-ws | 20/38 | 623 | 3/0 | 16 | 43 |
| E-admin | 3/14 | 677 | 2/0 | 34 | 4 |
| F-chaos-bg | 20/39 | 726 | 30/89 | 23 | 37 |
| G-endpoints | 80/100 | 508 | 30/5 | 104 | 158 |
| H-cold | 95/100 | 556 | 29/11 | 68 | 193 |
