package edu.bingol.bu_kampus.widgets

// Uretilmis: mobile/tool/gen_android_widgets_meta.py. Her slug icin 3 saglayici (2x2 / 4x2 / 4x4);
// sozlesme adi (<Slug>WidgetReceiver) 2x2 saglayicidir. Hepsi ayni cizim koduyla calisir (BuWidgetReceiver).

class MenuWidgetReceiver : BuWidgetReceiver(WidgetSlug.MENU, SizeClass.SMALL)
class MenuWidget4x2Receiver : BuWidgetReceiver(WidgetSlug.MENU, SizeClass.MEDIUM)
class MenuWidget4x4Receiver : BuWidgetReceiver(WidgetSlug.MENU, SizeClass.LARGE)
class TimetableWidgetReceiver : BuWidgetReceiver(WidgetSlug.TIMETABLE, SizeClass.SMALL)
class TimetableWidget4x2Receiver : BuWidgetReceiver(WidgetSlug.TIMETABLE, SizeClass.MEDIUM)
class TimetableWidget4x4Receiver : BuWidgetReceiver(WidgetSlug.TIMETABLE, SizeClass.LARGE)
class EventsWidgetReceiver : BuWidgetReceiver(WidgetSlug.EVENTS, SizeClass.SMALL)
class EventsWidget4x2Receiver : BuWidgetReceiver(WidgetSlug.EVENTS, SizeClass.MEDIUM)
class EventsWidget4x4Receiver : BuWidgetReceiver(WidgetSlug.EVENTS, SizeClass.LARGE)
class AnnouncementsWidgetReceiver : BuWidgetReceiver(WidgetSlug.ANNOUNCEMENTS, SizeClass.SMALL)
class AnnouncementsWidget4x2Receiver : BuWidgetReceiver(WidgetSlug.ANNOUNCEMENTS, SizeClass.MEDIUM)
class AnnouncementsWidget4x4Receiver : BuWidgetReceiver(WidgetSlug.ANNOUNCEMENTS, SizeClass.LARGE)
class PollWidgetReceiver : BuWidgetReceiver(WidgetSlug.POLL, SizeClass.SMALL)
class PollWidget4x2Receiver : BuWidgetReceiver(WidgetSlug.POLL, SizeClass.MEDIUM)
class PollWidget4x4Receiver : BuWidgetReceiver(WidgetSlug.POLL, SizeClass.LARGE)
class QuickAccessWidgetReceiver : BuWidgetReceiver(WidgetSlug.QUICKACCESS, SizeClass.SMALL)
class QuickAccessWidget4x2Receiver : BuWidgetReceiver(WidgetSlug.QUICKACCESS, SizeClass.MEDIUM)
class QuickAccessWidget4x4Receiver : BuWidgetReceiver(WidgetSlug.QUICKACCESS, SizeClass.LARGE)
class SocialWidgetReceiver : BuWidgetReceiver(WidgetSlug.SOCIAL, SizeClass.SMALL)
class SocialWidget4x2Receiver : BuWidgetReceiver(WidgetSlug.SOCIAL, SizeClass.MEDIUM)
class SocialWidget4x4Receiver : BuWidgetReceiver(WidgetSlug.SOCIAL, SizeClass.LARGE)
class ExamsWidgetReceiver : BuWidgetReceiver(WidgetSlug.EXAMS, SizeClass.SMALL)
class ExamsWidget4x2Receiver : BuWidgetReceiver(WidgetSlug.EXAMS, SizeClass.MEDIUM)
class ExamsWidget4x4Receiver : BuWidgetReceiver(WidgetSlug.EXAMS, SizeClass.LARGE)
class AcademicWidgetReceiver : BuWidgetReceiver(WidgetSlug.ACADEMIC, SizeClass.SMALL)
class AcademicWidget4x2Receiver : BuWidgetReceiver(WidgetSlug.ACADEMIC, SizeClass.MEDIUM)
class AcademicWidget4x4Receiver : BuWidgetReceiver(WidgetSlug.ACADEMIC, SizeClass.LARGE)

/** Slug -> tum saglayici siniflari (guncelleme hepsine gider). */
object WidgetProviders {
    val bySlug: Map<WidgetSlug, List<Class<*>>> = mapOf(
        WidgetSlug.MENU to listOf(MenuWidgetReceiver::class.java, MenuWidget4x2Receiver::class.java, MenuWidget4x4Receiver::class.java),
        WidgetSlug.TIMETABLE to listOf(TimetableWidgetReceiver::class.java, TimetableWidget4x2Receiver::class.java, TimetableWidget4x4Receiver::class.java),
        WidgetSlug.EVENTS to listOf(EventsWidgetReceiver::class.java, EventsWidget4x2Receiver::class.java, EventsWidget4x4Receiver::class.java),
        WidgetSlug.ANNOUNCEMENTS to listOf(AnnouncementsWidgetReceiver::class.java, AnnouncementsWidget4x2Receiver::class.java, AnnouncementsWidget4x4Receiver::class.java),
        WidgetSlug.POLL to listOf(PollWidgetReceiver::class.java, PollWidget4x2Receiver::class.java, PollWidget4x4Receiver::class.java),
        WidgetSlug.QUICKACCESS to listOf(QuickAccessWidgetReceiver::class.java, QuickAccessWidget4x2Receiver::class.java, QuickAccessWidget4x4Receiver::class.java),
        WidgetSlug.SOCIAL to listOf(SocialWidgetReceiver::class.java, SocialWidget4x2Receiver::class.java, SocialWidget4x4Receiver::class.java),
        WidgetSlug.EXAMS to listOf(ExamsWidgetReceiver::class.java, ExamsWidget4x2Receiver::class.java, ExamsWidget4x4Receiver::class.java),
        WidgetSlug.ACADEMIC to listOf(AcademicWidgetReceiver::class.java, AcademicWidget4x2Receiver::class.java, AcademicWidget4x4Receiver::class.java),
    )
}
