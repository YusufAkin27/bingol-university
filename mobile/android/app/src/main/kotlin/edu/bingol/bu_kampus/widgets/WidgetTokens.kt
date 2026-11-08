package edu.bingol.bu_kampus.widgets

/**
 * Ana ekran widget'lari (Jetpack Glance) merkezi tasarim belirtecleri.
 *
 * KAYNAK: design/widget-previews/DESIGN_SYSTEM.md tablolari. Ayni degerler Dart'ta
 * mobile/lib/features/widgets/widget_tokens.dart ve iOS'ta BUWidgets/Shared/BuWidgetTokens.swift icindedir;
 * mobile/test/widgets/widget_tokens_test.dart uc dosyayi ve tabloyu karsilastirir. Degeri YALNIZ tablo + Dart ile
 * birlikte degistirin. Renkler BuTokens'tan (mobile/lib/core/theme.dart) turetilmistir.
 *
 * Birim: dp (yazi sp = dp; sistem yazi olcegi 1.0 ustune cikarsa boyut fontScale'e bolunerek SABITLENIR).
 * Agirlik HER YERDE 400 (kalin yazi yok). Renkler hem burada ARGB Long olarak hem res/values(-night)/widget_colors.xml
 * icinde tutulur (Glance ColorProvider(day, night) icin iki kaynak da kullanilabilir). Material You dinamik renk KULLANILMAZ.
 */
object WidgetTokens {

    // --- Kabuk ---
    const val PADDING_DEFAULT = 16
    const val PADDING_QUICK_SMALL = 12
    const val BORDER_WIDTH = 1
    const val CORNER_RADIUS = 28

    /** Referans olculer (tasarim PNG'leri bu olcude); 2x2 / 4x2 / 4x4. */
    const val SIZE_2X2_W = 170
    const val SIZE_2X2_H = 170
    const val SIZE_4X2_W = 350
    const val SIZE_4X2_H = 170
    const val SIZE_4X4_W = 350
    const val SIZE_4X4_H = 350

    // --- Yazi: boyut / satir yuksekligi (sp = dp), harf araligi em, BUYUK ---
    class TextRole(val size: Int, val line: Int, val tracking: Float = 0f, val caps: Boolean = false)

    const val FONT_WEIGHT = 400

    val CAPTION = TextRole(10, 12, 0.08f, true)
    val MICRO = TextRole(11, 14)
    val SMALL = TextRole(12, 16)
    val BODY = TextRole(13, 18)
    val BODY_L = TextRole(14, 18)
    val QUESTION = TextRole(15, 20, -0.01f)
    val TITLE = TextRole(17, 22, -0.01f)
    val DISPLAY = TextRole(22, 26, -0.02f)
    val NUMBER = TextRole(34, 38, -0.03f)
    val NUMBER_ROW = TextRole(28, 32, -0.03f)
    val BADGE_DAY_SMALL = TextRole(13, 13)
    val BADGE_MONTH_SMALL = TextRole(9, 10, 0.08f, true)
    val BADGE_DAY_LARGE = TextRole(18, 20)
    val BADGE_MONTH_LARGE = TextRole(10, 12, 0.08f, true)
    val EVENT_DAY_HERO = TextRole(34, 36, -0.03f)

    // --- Bosluk olcegi ---
    const val S2 = 2
    const val S4 = 4
    const val S6 = 6
    const val S8 = 8
    const val S10 = 10
    const val S12 = 12
    const val S14 = 14
    const val S16 = 16

    // --- Kose yaricaplari ---
    const val RADIUS_ROW = 12
    const val RADIUS_TILE = 14
    const val RADIUS_CHIP = 12
    const val RADIUS_BADGE_SMALL = 8
    const val RADIUS_BADGE_LARGE = 10
    const val RADIUS_BAR = 2
    // "Oy ver" hapi: tam yuvarlak (yukseklik/2 ya da 999.dp).

    // --- Ikon (Lucide cizgi, vurus 1.5, round): vektor drawable'lar ---
    const val ICON_STROKE = 1.5f
    const val ICON_HEADER = 12
    const val ICON_HEADER_EVENTS = 14
    const val ICON_META = 12
    const val ICON_META_LARGE = 14
    const val ICON_ROW_LARGE = 22
    const val ICON_TILE_MEDIUM = 18
    const val ICON_TILE_LARGE = 24
    const val ICON_EMPTY_SMALL = 20
    const val ICON_EMPTY_MEDIUM = 22
    const val ICON_EMPTY_LARGE = 28
    const val ICON_SOCIAL_MEDIUM = 18

    // --- Baslik satiri / logo ---
    const val HEADER_HEIGHT = 16
    const val HEADER_GAP = 12
    const val LOGO_HEIGHT = 12
    const val LOGO_HEIGHT_EVENTS = 14
    const val LOGO_OPACITY = 0.9f

    // --- Satir / karo olculeri ---
    const val ROW_TIMETABLE_MEDIUM = 36
    const val ROW_TIMETABLE_LARGE = 40
    const val ROW_EVENTS = 36
    const val ROW_SOCIAL_LARGE = 64
    const val BADGE_EVENT_LARGE_WIDTH = 44
    const val BADGE_EVENT_LARGE_HEIGHT = 48
    const val BADGE_TIMETABLE_WIDTH = 52
    const val PILL_HEIGHT = 28
    const val PILL_PADDING_X = 14
    const val KCAL_CHIP_HEIGHT = 36
    const val BAR_HEIGHT = 4
    const val TILE_GAP = 8
    const val OPACITY_PAST_LESSON = 0.5f
    const val OPACITY_NON_LEADER_BAR = 0.45f
    const val MAX_FONT_SCALE = 1.0f

    // --- Boyuta gore icerik sayilari ---
    const val MENU_SMALL_MAIN_LINES = 2
    const val MENU_MEDIUM_DISHES = 3
    const val MENU_LARGE_DISHES = 4
    const val MENU_LARGE_DISHES_SINGLE_MEAL = 8
    const val TIMETABLE_SMALL_TITLE_LINES = 2
    const val TIMETABLE_MEDIUM_ROWS = 2
    const val TIMETABLE_LARGE_ROWS = 4
    const val EVENTS_SMALL = 1
    const val EVENTS_MEDIUM = 3
    const val EVENTS_LARGE = 3
    const val ANNOUNCEMENTS_SMALL = 1
    const val ANNOUNCEMENTS_MEDIUM = 3
    const val ANNOUNCEMENTS_LARGE = 4
    const val ANNOUNCEMENTS_SMALL_TITLE_LINES = 4
    const val ANNOUNCEMENTS_LARGE_TITLE_LINES = 2
    const val POLL_SMALL_QUESTION_LINES = 3
    const val POLL_MEDIUM_QUESTION_LINES = 3
    const val POLL_MEDIUM_OPTIONS = 3
    const val POLL_LARGE_QUESTION_LINES = 2
    const val POLL_LARGE_OPTIONS_MAX = 4
    const val QUICK_SMALL_TILES = 4
    const val QUICK_MEDIUM_TILES = 8
    const val QUICK_LARGE_TILES = 8
    const val SOCIAL_MEDIUM_COLUMNS = 3
    const val SOCIAL_LARGE_ROWS = 3

    // --- Veri sozlesmesi (design/widget-previews/DATA_CONTRACT.md) ---
    /** home_widget eklentisi Android'de bu SharedPreferences dosyasina yazar. */
    const val PREFS_NAME = "HomeWidgetPreferences"
    const val KEY_META = "bu_widget_meta"
    const val KEY_MENU = "bu_widget_menu"
    const val KEY_TIMETABLE = "bu_widget_timetable"
    const val KEY_EVENTS = "bu_widget_events"
    const val KEY_ANNOUNCEMENTS = "bu_widget_announcements"
    const val KEY_POLL = "bu_widget_poll"
    const val KEY_QUICK_ACCESS = "bu_widget_quickaccess"
    const val KEY_SOCIAL = "bu_widget_social"
    const val KEY_EXAMS = "bu_widget_exams"
    const val KEY_ACADEMIC = "bu_widget_academic"
    const val URL_SCHEME = "bukampus"

    /** Renk paleti: ARGB (0xAARRGGBB). Degerler BuTokens karsiliklari DESIGN_SYSTEM.md'de. */
    class Palette(
        val bg: Long, val chip: Long, val border: Long,
        val text1: Long, val text2: Long, val text3: Long,
        val inverseBg: Long, val inverseFg: Long,
        val barFill: Long, val barTrack: Long,
        val badgeFill: Long, val badgeBorder: Long, val dotPassive: Long,
        /** YALNIZ begeni kalbi. */
        val heart: Long,
        /** YALNIZ acil duyuru. */
        val danger: Long,
    )

    val LIGHT = Palette(
        bg = 0xFFFFFFFF, chip = 0xFFF4F4F5, border = 0xFFE4E4E7,
        text1 = 0xFF09090B, text2 = 0xFF52525B, text3 = 0xFF71717A,
        inverseBg = 0xFF09090B, inverseFg = 0xFFFFFFFF,
        barFill = 0xFF09090B, barTrack = 0xFFE4E4E7,
        badgeFill = 0xFFF4F4F5, badgeBorder = 0xFFE4E4E7, dotPassive = 0xFF8A8A93,
        heart = 0xFFDC2626, danger = 0xFFC81E1E,
    )

    val DARK = Palette(
        bg = 0xFF09090B, chip = 0xFF1C1C1F, border = 0xFF303034,
        text1 = 0xFFFAFAFA, text2 = 0xFFA1A1AA, text3 = 0xFF71717A,
        inverseBg = 0xFFFAFAFA, inverseFg = 0xFF09090B,
        barFill = 0xFFFAFAFA, barTrack = 0xFF303034,
        badgeFill = 0xFF1C1C1F, badgeBorder = 0xFF303034, dotPassive = 0xFF71717A,
        heart = 0xFFEF4444, danger = 0xFFF87171,
    )
}
